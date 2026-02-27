import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  FATSECRET_API_BASE_URL,
  FATSECRET_BARCODE_OAUTH_SCOPE,
  FATSECRET_OAUTH_URL,
  FATSECRET_SEARCH_OAUTH_SCOPE,
  FATSECRET_TOKEN_REFRESH_BUFFER_MS,
  FATSECRET_VPC_CONNECTOR,
  RATE_LIMITS,
  fatSecretClientId,
  fatSecretClientSecret,
} from "./config";
import { enforceAppCheckIfRequired, enforcePerUserRateLimit } from "./infra";
import { sanitizeTextInput, toNullableNumber } from "./utils";

interface FoodServingOptionPayload {
  id: string;
  description: string;
  grams: number;
  caloriesPerGram: number;
  proteinPerGram: number;
  carbsPerGram: number;
  fatPerGram: number;
  isDefault: boolean;
}

interface FatSecretFoodResultPayload {
  id: string;
  name: string;
  caloriesPerGram: number;
  proteinPerGram: number;
  carbsPerGram: number;
  fatPerGram: number;
  servingGrams: number;
  source: "fatsecret";
  servingOptions: FoodServingOptionPayload[];
  barcode?: string;
  brand?: string;
  imageUrl?: string;
}

let fatSecretTokenCache: Record<string, { token: string; expiresAtMs: number }> = {};

function ensureArray<T>(value: T | T[] | null | undefined): T[] {
  if (Array.isArray(value)) {
    return value;
  }
  if (value === null || value === undefined) {
    return [];
  }
  return [value];
}

function normalizeBarcode(value: string): string {
  return value.replace(/\D/g, "");
}

function canonicalBarcode(value: string): string {
  const normalized = normalizeBarcode(value);
  if (normalized.length === 13 && normalized.startsWith("0")) {
    return normalized.substring(1);
  }
  return normalized;
}

function toGtin13Barcode(value: string): string | null {
  const normalized = normalizeBarcode(value);
  if (normalized.length < 8 || normalized.length > 13) {
    return null;
  }
  return normalized.padStart(13, "0");
}

function buildBarcodeCandidates(value: string): string[] {
  const normalized = normalizeBarcode(value);
  if (normalized.length < 8 || normalized.length > 13) {
    return [];
  }

  const candidates: string[] = [];
  const seen = new Set<string>();
  const add = (candidate: string) => {
    const trimmed = candidate.trim();
    if (!trimmed || seen.has(trimmed)) {
      return;
    }
    seen.add(trimmed);
    candidates.push(trimmed);
  };

  add(normalized);

  const gtin13 = toGtin13Barcode(normalized);
  if (gtin13) {
    add(gtin13);
  }

  if (normalized.length === 13 && normalized.startsWith("0")) {
    add(normalized.substring(1));
  }

  return candidates;
}

function toHttpUrl(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return null;
  }

  if (trimmed.startsWith("//")) {
    return `https:${trimmed}`;
  }

  try {
    const parsed = new URL(trimmed);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return null;
    }
    return trimmed;
  } catch (_) {
    return null;
  }
}

function resolveFatSecretImageUrl(food: any): string | null {
  const imageRoots = [
    food?.food_images?.food_image,
    food?.food_images,
    food?.food_image,
    food?.images?.image,
    food?.images,
  ];

  for (const root of imageRoots) {
    const imageNodes = ensureArray<any>(root);
    for (const node of imageNodes) {
      const candidateValues = [
        node?.image_url,
        node?.url,
        node?.image_url_large,
        node?.image_url_medium,
        node?.image_url_small,
        node,
      ];
      for (const candidate of candidateValues) {
        const resolved = toHttpUrl(candidate);
        if (resolved) {
          return resolved;
        }
      }
    }
  }

  const directCandidates = [
    food?.food_image_url,
    food?.food_image_thumbnail,
    food?.food_image,
    food?.image_url,
    food?.photo_url,
  ];
  for (const candidate of directCandidates) {
    const resolved = toHttpUrl(candidate);
    if (resolved) {
      return resolved;
    }
  }

  return null;
}

function convertServingAmountToGrams(amount: number, unitRaw: string): number | null {
  if (!Number.isFinite(amount) || amount <= 0) {
    return null;
  }

  const unit = unitRaw.trim().toLowerCase();
  if (!unit || unit === "g" || unit === "gram" || unit === "grams") {
    return amount;
  }
  if (unit === "ml" || unit === "milliliter" || unit === "milliliters") {
    return amount;
  }
  if (unit === "oz" || unit === "ounce" || unit === "ounces") {
    return amount * 28.3495;
  }
  return null;
}

function resolveFatSecretServingGrams(serving: any): number | null {
  const metricAmount = toNullableNumber(serving?.metric_serving_amount);
  const metricUnit = (serving?.metric_serving_unit || "").toString();
  if (metricAmount !== null) {
    const metricGrams = convertServingAmountToGrams(metricAmount, metricUnit);
    if (metricGrams !== null) {
      return metricGrams;
    }
  }

  const numberOfUnits = toNullableNumber(serving?.number_of_units);
  const measurementDescription = (serving?.measurement_description || "").toString();
  if (numberOfUnits !== null) {
    const measuredGrams = convertServingAmountToGrams(
      numberOfUnits,
      measurementDescription
    );
    if (measuredGrams !== null) {
      return measuredGrams;
    }
  }

  const servingDescription = (serving?.serving_description || "")
    .toString()
    .toLowerCase();
  const regexMatch = servingDescription.match(
    /([\d.]+)\s*(g|gram|grams|ml|milliliter|milliliters|oz|ounce|ounces)\b/
  );
  if (!regexMatch) {
    return null;
  }

  const parsedAmount = Number(regexMatch[1]);
  return convertServingAmountToGrams(parsedAmount, regexMatch[2]);
}

function parseFatSecretServingOptions(servingsRoot: any): FoodServingOptionPayload[] {
  const servings = ensureArray<any>(servingsRoot?.serving).filter(
    (serving) => serving && typeof serving === "object"
  );

  const options = servings
    .map((serving, index) => {
      const servingId = (serving?.serving_id ?? `${index}`).toString().trim() || `${index}`;
      const grams = resolveFatSecretServingGrams(serving);
      if (grams === null || grams <= 0) {
        return null;
      }

      const calories = toNullableNumber(serving?.calories);
      if (calories === null || calories < 0) {
        return null;
      }

      const carbs = toNullableNumber(serving?.carbohydrate) ?? 0;
      const protein = toNullableNumber(serving?.protein) ?? 0;
      const fat = toNullableNumber(serving?.fat) ?? 0;
      const servingDescription =
        (serving?.serving_description || "").toString().trim();
      const measurementDescription =
        (serving?.measurement_description || "").toString().trim();
      const description = servingDescription || measurementDescription || `Serving ${index + 1}`;
      const isDefault =
        servingId === "0" ||
        (serving?.is_default || "").toString().trim() === "1";

      return {
        id: servingId,
        description,
        grams,
        caloriesPerGram: Math.max(0, calories / grams),
        proteinPerGram: Math.max(0, protein / grams),
        carbsPerGram: Math.max(0, carbs / grams),
        fatPerGram: Math.max(0, fat / grams),
        isDefault,
      };
    })
    .filter((option): option is FoodServingOptionPayload => option !== null);

  if (options.length === 0) {
    return [];
  }

  if (!options.some((option) => option.isDefault)) {
    options[0] = { ...options[0], isDefault: true };
  }
  return options;
}

function parseFatSecretFoodResult(
  food: any,
  options?: { idPrefix?: string; barcode?: string }
): FatSecretFoodResultPayload | null {
  const name = (food?.food_name || "").toString().trim();
  if (!name) {
    return null;
  }

  const servingOptions = parseFatSecretServingOptions(food?.servings);
  if (servingOptions.length === 0) {
    return null;
  }
  const defaultServing =
    servingOptions.find((option) => option.isDefault) ?? servingOptions[0];

  const imageUrl = resolveFatSecretImageUrl(food);
  const foodId = (food?.food_id || "").toString().trim();
  const idPrefix = options?.idPrefix || "fatsecret_";
  const barcode = canonicalBarcode(options?.barcode || "");

  return {
    id: `${idPrefix}${foodId || name.toLowerCase().replace(/\s+/g, "_")}`,
    barcode: barcode || undefined,
    name,
    caloriesPerGram: defaultServing.caloriesPerGram,
    proteinPerGram: defaultServing.proteinPerGram,
    carbsPerGram: defaultServing.carbsPerGram,
    fatPerGram: defaultServing.fatPerGram,
    servingGrams: defaultServing.grams,
    source: "fatsecret",
    servingOptions,
    brand: (food?.brand_name || "").toString().trim() || undefined,
    imageUrl: imageUrl || undefined,
  };
}

function parseFatSecretSuggestions(payload: any): string[] {
  const rawSuggestions = payload?.suggestions?.suggestion;
  return ensureArray(rawSuggestions)
    .map((value) => value.toString().trim())
    .filter((value) => value.length > 0);
}

function parseFatSecretSearchSuggestions(payload: any, maxResults: number): string[] {
  const foods = ensureArray<any>(payload?.foods_search?.results?.food);
  const seen = new Set<string>();
  const suggestions: string[] = [];

  for (const food of foods) {
    const foodName = (food?.food_name || "").toString().trim();
    if (!foodName) {
      continue;
    }
    const key = foodName.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    suggestions.push(foodName);
    if (suggestions.length >= maxResults) {
      break;
    }
  }

  return suggestions;
}

function extractFatSecretErrorCode(payload: any): number | null {
  if (!payload || !payload.error) {
    return null;
  }
  if (typeof payload.error === "number") {
    return payload.error;
  }
  return toNullableNumber(payload.error.code);
}

function extractFatSecretErrorMessage(payload: any): string {
  if (!payload || !payload.error) {
    return "";
  }
  if (typeof payload.error === "string") {
    return payload.error.trim();
  }
  if (typeof payload.error.message === "string") {
    return payload.error.message.trim();
  }
  return "";
}

function throwFatSecretApiError(
  responseStatus: number,
  payload: any,
  context: string
): never {
  const fatSecretCode = extractFatSecretErrorCode(payload);
  const fatSecretMessage = extractFatSecretErrorMessage(payload);
  const lowerMessage = fatSecretMessage.toLowerCase();

  if (fatSecretCode === 211) {
    throw new HttpsError(
      "not-found",
      fatSecretMessage || "No matching food found"
    );
  }

  if (fatSecretCode === 101 || fatSecretCode === 107) {
    throw new HttpsError(
      "invalid-argument",
      fatSecretMessage || `Invalid FatSecret request for ${context}`
    );
  }

  if (lowerMessage.includes("scope")) {
    throw new HttpsError(
      "permission-denied",
      fatSecretMessage ||
        `FatSecret scope is missing for ${context}. Upgrade API scope or use fallback.`
    );
  }

  if (
    fatSecretCode === 13 ||
    fatSecretCode === 14 ||
    fatSecretCode === 21 ||
    responseStatus === 401 ||
    responseStatus === 403
  ) {
    throw new HttpsError(
      "permission-denied",
      fatSecretMessage ||
        `FatSecret authentication or allowlist failed for ${context}`
    );
  }

  const detailSuffix = fatSecretMessage ? `: ${fatSecretMessage}` : "";
  throw new HttpsError(
    "unavailable",
    `FatSecret API error during ${context} (HTTP ${responseStatus})${detailSuffix}`
  );
}

function isFatSecretScopeError(error: unknown): boolean {
  if (!(error instanceof HttpsError)) {
    return false;
  }
  const message = (error.message || "").toLowerCase();
  return message.includes("scope");
}

async function requestFatSecretToken(
  scope?: string
): Promise<{ status: number; payload: any }> {
  const clientId = fatSecretClientId.value().trim();
  const clientSecret = fatSecretClientSecret.value().trim();
  if (!clientId || !clientSecret) {
    throw new HttpsError(
      "failed-precondition",
      "FatSecret OAuth secrets are missing"
    );
  }

  const tokenBody = new URLSearchParams();
  tokenBody.set("grant_type", "client_credentials");
  if (scope && scope.trim().length > 0) {
    tokenBody.set("scope", scope.trim());
  }

  const basicAuth = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const tokenResponse = await fetch(FATSECRET_OAUTH_URL, {
    method: "POST",
    headers: {
      Authorization: `Basic ${basicAuth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: tokenBody.toString(),
  });

  const rawTokenResponse = await tokenResponse.text();
  let tokenPayload: any = null;
  if (rawTokenResponse) {
    try {
      tokenPayload = JSON.parse(rawTokenResponse);
    } catch (_) {
      tokenPayload = null;
    }
  }

  return {
    status: tokenResponse.status,
    payload: tokenPayload,
  };
}

function fatSecretTokenCacheKey(scope?: string): string {
  const normalized = (scope || "").toString().trim().toLowerCase();
  return normalized || "__default__";
}

async function getFatSecretAccessToken(options?: {
  scope?: string;
  fallbackScope?: string;
  allowScopeFallback?: boolean;
}): Promise<string> {
  const requestedScope = (options?.scope || "").toString().trim() || undefined;
  const fallbackScope =
    (options?.fallbackScope || "").toString().trim() || undefined;
  const allowScopeFallback = options?.allowScopeFallback !== false;
  const now = Date.now();

  const requestedScopeKey = fatSecretTokenCacheKey(requestedScope);
  const cachedToken = fatSecretTokenCache[requestedScopeKey];
  if (
    cachedToken &&
    now < cachedToken.expiresAtMs - FATSECRET_TOKEN_REFRESH_BUFFER_MS
  ) {
    return cachedToken.token;
  }

  let attemptedScope = requestedScope;
  let cacheScopeKey = requestedScopeKey;
  let tokenAttempt = await requestFatSecretToken(requestedScope);
  const tokenAttemptError = extractFatSecretErrorMessage(
    tokenAttempt.payload
  ).toLowerCase();
  const invalidScope =
    tokenAttemptError === "invalid_scope" ||
    tokenAttempt.payload?.error === "invalid_scope";

  if (tokenAttempt.status >= 400 && requestedScope && invalidScope && allowScopeFallback) {
    const fallbackTarget = fallbackScope || undefined;
    if (fallbackTarget && fallbackTarget !== requestedScope) {
      console.warn(
        `FatSecret OAuth scope "${requestedScope}" was rejected. Retrying token request with fallback scope "${fallbackTarget}".`
      );
      attemptedScope = fallbackTarget;
      cacheScopeKey = fatSecretTokenCacheKey(fallbackTarget);
      tokenAttempt = await requestFatSecretToken(fallbackTarget);
    } else {
      console.warn(
        `FatSecret OAuth scope "${requestedScope}" was rejected. Retrying token request without explicit scope.`
      );
      attemptedScope = undefined;
      cacheScopeKey = fatSecretTokenCacheKey(undefined);
      tokenAttempt = await requestFatSecretToken(undefined);
    }
  } else if (
    tokenAttempt.status >= 400 &&
    requestedScope &&
    invalidScope &&
    !allowScopeFallback
  ) {
    console.warn(
      `FatSecret OAuth scope "${requestedScope}" was rejected and fallback is disabled.`
    );
  }

  if (tokenAttempt.status >= 400) {
    throwFatSecretApiError(
      tokenAttempt.status,
      tokenAttempt.payload,
      attemptedScope
        ? `oauth token request (${attemptedScope})`
        : "oauth token request"
    );
  }

  const accessToken = (tokenAttempt.payload?.access_token || "")
    .toString()
    .trim();
  const expiresInSeconds = toNullableNumber(tokenAttempt.payload?.expires_in) ?? 3600;
  if (!accessToken) {
    throw new HttpsError(
      "internal",
      "FatSecret OAuth token response did not include an access token"
    );
  }

  fatSecretTokenCache[cacheScopeKey] = {
    token: accessToken,
    expiresAtMs: now + Math.max(60, Math.floor(expiresInSeconds)) * 1000,
  };
  return accessToken;
}

async function callFatSecretJson(
  endpointPath: string,
  params: Record<string, string | number | boolean | null | undefined>,
  options?: {
    oauthScope?: string;
    fallbackScope?: string;
    allowScopeFallback?: boolean;
  }
): Promise<any> {
  const token = await getFatSecretAccessToken({
    scope: options?.oauthScope,
    fallbackScope: options?.fallbackScope,
    allowScopeFallback: options?.allowScopeFallback,
  });

  const url = new URL(`${FATSECRET_API_BASE_URL}${endpointPath}`);
  for (const [key, value] of Object.entries(params)) {
    if (value === null || value === undefined) {
      continue;
    }
    const normalized = value.toString().trim();
    if (!normalized) {
      continue;
    }
    url.searchParams.set(key, normalized);
  }
  if (!url.searchParams.has("format")) {
    url.searchParams.set("format", "json");
  }

  const response = await fetch(url.toString(), {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });

  const rawBody = await response.text();
  let payload: any = null;
  if (rawBody) {
    try {
      payload = JSON.parse(rawBody);
    } catch (_) {
      payload = null;
    }
  }

  if (!response.ok || payload?.error) {
    throwFatSecretApiError(response.status, payload, endpointPath);
  }
  return payload;
}

/**
 * Lookup a packaged food by barcode via FatSecret.
 * Requires authentication (including anonymous auth)
 */
export const lookupFoodByBarcode = onCall(
  {
    cors: true,
    invoker: "public",
    secrets: [fatSecretClientId, fatSecretClientSecret],
    vpcConnector: FATSECRET_VPC_CONNECTOR,
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to look up barcodes"
      );
    }

    enforceAppCheckIfRequired(request, "lookupFoodByBarcode");
    await enforcePerUserRateLimit({
      uid: request.auth.uid,
      endpointName: "lookupFoodByBarcode",
      maxRequests: RATE_LIMITS.lookupFoodByBarcode.maxRequests,
      windowMs: RATE_LIMITS.lookupFoodByBarcode.windowMs,
    });

    const rawBarcode = (request.data?.barcode || "").toString().trim();
    const normalizedBarcode = normalizeBarcode(rawBarcode);
    const barcodeCandidates = buildBarcodeCandidates(normalizedBarcode);
    if (barcodeCandidates.length === 0) {
      throw new HttpsError("invalid-argument", "A valid barcode is required");
    }

    try {
      let resolvedResult: FatSecretFoodResultPayload | null = null;

      for (const candidate of barcodeCandidates) {
        try {
          const payload = await callFatSecretJson(
            "/food/barcode/find-by-id/v2",
            {
              barcode: candidate,
              format: "json",
              flag_default_serving: "true",
              include_food_images: "true",
            },
            {
              oauthScope: FATSECRET_BARCODE_OAUTH_SCOPE,
              fallbackScope: FATSECRET_SEARCH_OAUTH_SCOPE,
              allowScopeFallback: true,
            }
          );

          const food = payload?.food;
          if (!food || typeof food !== "object") {
            continue;
          }

          resolvedResult = parseFatSecretFoodResult(food, {
            idPrefix: "fatsecret_barcode_",
            barcode: normalizedBarcode,
          });
          if (resolvedResult) {
            break;
          }
        } catch (candidateError) {
          if (candidateError instanceof HttpsError) {
            if (
              candidateError.code === "not-found" ||
              candidateError.code === "invalid-argument"
            ) {
              continue;
            }
            throw candidateError;
          }
          throw candidateError;
        }
      }

      if (!resolvedResult) {
        throw new HttpsError(
          "not-found",
          `No nutrition facts found for barcode ${normalizedBarcode}`
        );
      }

      return { result: resolvedResult };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("FatSecret barcode lookup failed:", error);
      throw new HttpsError("internal", "Barcode lookup failed");
    }
  }
);

/**
 * Search foods via FatSecret only.
 * Requires authentication (including anonymous auth)
 */
export const searchFoods = onCall(
  {
    cors: true,
    invoker: "public",
    secrets: [fatSecretClientId, fatSecretClientSecret],
    vpcConnector: FATSECRET_VPC_CONNECTOR,
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to search foods"
      );
    }

    enforceAppCheckIfRequired(request, "searchFoods");
    await enforcePerUserRateLimit({
      uid: request.auth.uid,
      endpointName: "searchFoods",
      maxRequests: RATE_LIMITS.searchFoods.maxRequests,
      windowMs: RATE_LIMITS.searchFoods.windowMs,
    });

    const query = sanitizeTextInput(request.data?.query, 120);
    if (!query) {
      throw new HttpsError("invalid-argument", "Query is required");
    }

    const maxResultsInput = toNullableNumber(request.data?.maxResults);
    const maxResults = Math.max(1, Math.min(50, Math.floor(maxResultsInput ?? 10)));

    try {
      const payload = await callFatSecretJson(
        "/foods/search/v4",
        {
          search_expression: query,
          page_number: 0,
          max_results: maxResults,
          format: "json",
          flag_default_serving: "true",
          include_food_images: "true",
        },
        {
          oauthScope: FATSECRET_SEARCH_OAUTH_SCOPE,
          allowScopeFallback: true,
        }
      );

      const foods = ensureArray<any>(payload?.foods_search?.results?.food);
      const results = foods
        .map((food) => parseFatSecretFoodResult(food))
        .filter((item): item is FatSecretFoodResultPayload => item !== null);

      console.log(`FatSecret returned ${results.length} search results`);
      return { results };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("FatSecret search failed:", error);
      throw new HttpsError("internal", "Food search failed");
    }
  }
);

/**
 * Autocomplete food terms via FatSecret foods.autocomplete.v2.
 * Requires authentication (including anonymous auth)
 */
export const autocompleteFoods = onCall(
  {
    cors: true,
    invoker: "public",
    secrets: [fatSecretClientId, fatSecretClientSecret],
    vpcConnector: FATSECRET_VPC_CONNECTOR,
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to use autocomplete"
      );
    }

    enforceAppCheckIfRequired(request, "autocompleteFoods");
    await enforcePerUserRateLimit({
      uid: request.auth.uid,
      endpointName: "autocompleteFoods",
      maxRequests: RATE_LIMITS.autocompleteFoods.maxRequests,
      windowMs: RATE_LIMITS.autocompleteFoods.windowMs,
    });

    const expression = sanitizeTextInput(request.data?.expression, 120);
    if (expression.length < 2) {
      return { suggestions: [] as string[] };
    }

    const maxResultsInput = toNullableNumber(request.data?.maxResults);
    const maxResults = Math.max(1, Math.min(10, Math.floor(maxResultsInput ?? 6)));

    try {
      const payload = await callFatSecretJson(
        "/food/autocomplete/v2",
        {
          expression,
          max_results: maxResults,
          format: "json",
        },
        {
          oauthScope: FATSECRET_SEARCH_OAUTH_SCOPE,
          allowScopeFallback: true,
        }
      );
      const suggestions = parseFatSecretSuggestions(payload).slice(0, maxResults);
      return { suggestions };
    } catch (error) {
      if (isFatSecretScopeError(error)) {
        try {
          const fallbackPayload = await callFatSecretJson(
            "/foods/search/v4",
            {
              search_expression: expression,
              page_number: 0,
              max_results: maxResults,
              format: "json",
              flag_default_serving: "false",
            },
            {
              oauthScope: FATSECRET_SEARCH_OAUTH_SCOPE,
              allowScopeFallback: true,
            }
          );
          const suggestions = parseFatSecretSearchSuggestions(
            fallbackPayload,
            maxResults
          );
          return { suggestions };
        } catch (fallbackError) {
          if (fallbackError instanceof HttpsError) {
            throw fallbackError;
          }
          console.error("FatSecret autocomplete fallback failed:", fallbackError);
          throw new HttpsError("internal", "Autocomplete fallback failed");
        }
      }

      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("FatSecret autocomplete failed:", error);
      throw new HttpsError("internal", "Autocomplete failed");
    }
  }
);
