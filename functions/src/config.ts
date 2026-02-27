import { defineSecret } from "firebase-functions/params";

// Secret params
export const pgPassword = defineSecret("pg-password");
export const geminiApiKey = defineSecret("gemini-api-key");
export const fatSecretClientId = defineSecret("FATSECRET_CLIENT_ID");
export const fatSecretClientSecret = defineSecret("FATSECRET_CLIENT_SECRET");
export const openAiApiKey = defineSecret("OPENAI_API_KEY");

// Runtime/config constants
export const INSTANCE_CONNECTION_NAME =
  "ai-nutrition-assistant-e2346:us-central1:recipe-vectors";

export const FATSECRET_VPC_CONNECTOR =
  "projects/ai-nutrition-assistant-e2346/locations/us-central1/connectors/fatsecret-egress-conn";
export const FATSECRET_OAUTH_URL = "https://oauth.fatsecret.com/connect/token";
export const FATSECRET_API_BASE_URL = "https://platform.fatsecret.com/rest";
export const FATSECRET_SEARCH_OAUTH_SCOPE = "premier";
export const FATSECRET_BARCODE_OAUTH_SCOPE = "barcode";
export const FATSECRET_TOKEN_REFRESH_BUFFER_MS = 60_000;

export const MAX_IMAGE_PAYLOAD_BYTES = 5 * 1024 * 1024;
export const MAX_IMAGE_BASE64_CHARS =
  Math.ceil((MAX_IMAGE_PAYLOAD_BYTES * 4) / 3) + 4;
export const MAX_GEMINI_PROMPT_CHARS = 4_000;
export const MAX_GEMINI_SYSTEM_INSTRUCTION_CHARS = 4_000;
export const MAX_HISTORY_ITEMS = 20;
export const MAX_HISTORY_TEXT_CHARS = 1_000;

export const MAX_SEARCH_QUERY_CHARS = 500;
export const MAX_FILTER_ITEMS = 40;
export const MAX_FILTER_TEXT_CHARS = 80;
export const MAX_EXCLUDE_IDS = 200;
export const MAX_SEARCH_LIMIT = 20;

export const MAX_ANALYZED_FOOD_ITEMS = 25;
export const PROXY_IMAGE_TIMEOUT_MS = 8_000;
export const PROXY_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
export const PROXY_IMAGE_HOST = "img.spoonacular.com";
export const OPENAI_TIMEOUT_MS = 30_000;

export const ALLOWED_IMAGE_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);

export const ALLOWED_GEMINI_MODELS = new Set([
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-1.5-flash",
  "gemini-1.5-pro",
]);

export const ALLOWED_PROXY_ORIGINS = [
  /^https:\/\/ai-nutrition-assistant-e2346\.web\.app$/,
  /^https:\/\/ai-nutrition-assistant-e2346\.firebaseapp\.com$/,
  /^http:\/\/localhost(?::\d+)?$/,
];

export const ENFORCE_APP_CHECK =
  (process.env.ENFORCE_APP_CHECK || "").toLowerCase() === "true";

export const RATE_LIMIT_COLLECTION = "__rate_limits";
export const DEFAULT_RATE_LIMIT_WINDOW_MS = 60_000;
export const RATE_LIMIT_DOC_TTL_MS = 10 * 60_000;

export const RECIPE_DOC_CACHE_TTL_MS = 5 * 60_000;

export const RATE_LIMITS = {
  callGemini: { maxRequests: 20, windowMs: 60_000 },
  analyzeMealImage: { maxRequests: 8, windowMs: 60_000 },
  searchRecipes: { maxRequests: 30, windowMs: 60_000 },
  searchFoods: { maxRequests: 60, windowMs: 60_000 },
  autocompleteFoods: { maxRequests: 120, windowMs: 60_000 },
  lookupFoodByBarcode: { maxRequests: 60, windowMs: 60_000 },
} as const;
