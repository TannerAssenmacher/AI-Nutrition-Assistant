import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";

import {
  ALLOWED_IMAGE_MIME_TYPES,
  ALLOWED_GEMINI_MODELS,
  ALLOWED_PROXY_ORIGINS,
  MAX_ANALYZED_FOOD_ITEMS,
  MAX_GEMINI_PROMPT_CHARS,
  MAX_GEMINI_SYSTEM_INSTRUCTION_CHARS,
  MAX_HISTORY_ITEMS,
  MAX_HISTORY_TEXT_CHARS,
  MAX_IMAGE_BASE64_CHARS,
  OPENAI_TIMEOUT_MS,
  PROXY_IMAGE_HOST,
  PROXY_IMAGE_MAX_BYTES,
  PROXY_IMAGE_TIMEOUT_MS,
  RATE_LIMITS,
  geminiApiKey,
  openAiApiKey,
} from "./config";
import { enforceAppCheckIfRequired, enforcePerUserRateLimit } from "./infra";
import {
  normalizeBase64Payload,
  roundTo,
  sanitizeTextInput,
  toNonNegativeNumber,
  toRequestData,
  validateImagePayload,
} from "./utils";

/**
 * Image Proxy for CORS workaround
 * Proxies Spoonacular images so they can be loaded on Flutter Web
 */
export const proxyImage = onRequest(
  { cors: ALLOWED_PROXY_ORIGINS },
  async (request, response) => {
    const imageUrlRaw = (request.query.url || "").toString().trim();

    if (!imageUrlRaw) {
      response.status(400).send("Missing image URL");
      return;
    }

    let imageUrl: URL;
    try {
      imageUrl = new URL(imageUrlRaw);
    } catch (_) {
      response.status(400).send("Invalid image URL");
      return;
    }

    if (
      imageUrl.protocol !== "https:" ||
      imageUrl.hostname.toLowerCase() !== PROXY_IMAGE_HOST
    ) {
      response.status(400).send("Invalid image URL");
      return;
    }

    try {
      const abortController = new AbortController();
      const timeoutHandle = setTimeout(
        () => abortController.abort(),
        PROXY_IMAGE_TIMEOUT_MS
      );

      let imageResponse: Response;
      try {
        imageResponse = await fetch(imageUrl.toString(), {
          signal: abortController.signal,
        });
      } finally {
        clearTimeout(timeoutHandle);
      }

      if (!imageResponse.ok) {
        response.status(404).send("Image not found");
        return;
      }

      const contentTypeRaw = (imageResponse.headers.get("content-type") || "")
        .split(";")[0]
        .trim()
        .toLowerCase();

      if (!ALLOWED_IMAGE_MIME_TYPES.has(contentTypeRaw)) {
        response.status(415).send("Unsupported image format");
        return;
      }

      const contentLengthHeader = imageResponse.headers.get("content-length");
      const contentLength =
        contentLengthHeader === null ? null : Number(contentLengthHeader);
      if (
        contentLength !== null &&
        Number.isFinite(contentLength) &&
        contentLength > PROXY_IMAGE_MAX_BYTES
      ) {
        response.status(413).send("Image too large");
        return;
      }

      const arrayBuffer = await imageResponse.arrayBuffer();
      if (arrayBuffer.byteLength > PROXY_IMAGE_MAX_BYTES) {
        response.status(413).send("Image too large");
        return;
      }

      response.set("Cache-Control", "public, max-age=86400");
      response.set("Content-Type", contentTypeRaw || "image/jpeg");
      response.send(Buffer.from(arrayBuffer));
    } catch (error) {
      if (error instanceof Error && error.name === "AbortError") {
        response.status(504).send("Image fetch timed out");
        return;
      }
      console.error("Error proxying image:", error);
      response.status(502).send("Error loading image");
    }
  }
);

/**
 * Secure Gemini proxy callable.
 * Keeps Gemini API key in Cloud Functions secrets instead of client.
 */
export const callGemini = onCall(
  {
    cors: true,
    invoker: "public",
    secrets: [geminiApiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to call Gemini"
      );
    }

    enforceAppCheckIfRequired(request, "callGemini");
    await enforcePerUserRateLimit({
      uid: request.auth.uid,
      endpointName: "callGemini",
      maxRequests: RATE_LIMITS.callGemini.maxRequests,
      windowMs: RATE_LIMITS.callGemini.windowMs,
    });

    const data = toRequestData(request.data);
    const prompt = sanitizeTextInput(data.prompt, MAX_GEMINI_PROMPT_CHARS);
    const systemInstruction = sanitizeTextInput(
      data.systemInstruction,
      MAX_GEMINI_SYSTEM_INSTRUCTION_CHARS
    );
    const requestedModel = sanitizeTextInput(
      data.model || "gemini-2.5-flash",
      64
    ).toLowerCase();
    const modelName = ALLOWED_GEMINI_MODELS.has(requestedModel)
      ? requestedModel
      : "gemini-2.5-flash";
    const imageBase64 = normalizeBase64Payload(
      (data.imageBase64 || "").toString()
    );
    const mimeType = sanitizeTextInput(data.mimeType || "image/jpeg", 64).toLowerCase();

    if (!prompt.trim() && !imageBase64) {
      throw new HttpsError("invalid-argument", "Prompt or imageBase64 is required");
    }

    if (imageBase64.length > MAX_IMAGE_BASE64_CHARS) {
      throw new HttpsError("invalid-argument", "imageBase64 exceeds size limits");
    }

    if (imageBase64) {
      validateImagePayload(imageBase64, mimeType);
    }

    const rawHistory = Array.isArray(data.history)
      ? data.history.slice(-MAX_HISTORY_ITEMS)
      : [];
    const history = rawHistory
      .map((entry: any) => {
        const text = sanitizeTextInput(entry?.text, MAX_HISTORY_TEXT_CHARS);
        if (!text) {
          return null;
        }
        const roleRaw = (entry?.role || "").toString().toLowerCase();
        const role: "model" | "user" = roleRaw === "model" ? "model" : "user";
        return {
          role,
          parts: [{ text }],
        };
      })
      .filter(
        (
          entry
        ): entry is { role: "model" | "user"; parts: Array<{ text: string }> } =>
          entry !== null
      )
      .slice(-MAX_HISTORY_ITEMS);

    try {
      const { GoogleGenerativeAI } = await import("@google/generative-ai");
      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      const model = genAI.getGenerativeModel({
        model: modelName,
        ...(systemInstruction ? { systemInstruction } : {}),
      });

      let text = "";
      if (imageBase64) {
        const parts: any[] = [];
        if (prompt.trim()) {
          parts.push({ text: prompt.trim() });
        }
        parts.push({
          inlineData: {
            mimeType,
            data: imageBase64,
          },
        });

        const response = await model.generateContent({
          contents: [{ role: "user", parts }],
        });
        text = response.response.text();
      } else if (history.length > 0) {
        const chat = model.startChat({ history });
        const response = await chat.sendMessage(prompt);
        text = response.response.text();
      } else {
        const response = await model.generateContent(prompt);
        text = response.response.text();
      }

      if (!text || !text.trim()) {
        throw new HttpsError("internal", "Gemini returned an empty response");
      }

      return { text };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      console.error("Gemini callable failed:", error);
      throw new HttpsError("internal", "Gemini request failed");
    }
  }
);

/**
 * Analyze meal image via OpenAI Responses API.
 * Keeps OpenAI API key in Cloud Functions secrets instead of client.
 */
export const analyzeMealImage = onCall(
  {
    cors: true,
    invoker: "public",
    secrets: [openAiApiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated to analyze meal images"
      );
    }

    enforceAppCheckIfRequired(request, "analyzeMealImage");
    await enforcePerUserRateLimit({
      uid: request.auth.uid,
      endpointName: "analyzeMealImage",
      maxRequests: RATE_LIMITS.analyzeMealImage.maxRequests,
      windowMs: RATE_LIMITS.analyzeMealImage.windowMs,
    });

    const data = toRequestData(request.data);
    const imageBase64Raw = (data.imageBase64 || "").toString();
    const imageBase64 = normalizeBase64Payload(imageBase64Raw);
    const mimeType = sanitizeTextInput(data.mimeType || "image/jpeg", 64).toLowerCase();
    const userContext = sanitizeTextInput(data.userContext, 500);

    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "imageBase64 is required");
    }
    if (imageBase64.length > MAX_IMAGE_BASE64_CHARS) {
      throw new HttpsError("invalid-argument", "imageBase64 exceeds size limits");
    }
    validateImagePayload(imageBase64, mimeType);

    const imageUrl = `data:${mimeType};base64,${imageBase64}`;

    try {
      const abortController = new AbortController();
      const timeoutHandle = setTimeout(
        () => abortController.abort(),
        OPENAI_TIMEOUT_MS
      );

      let response: Response;
      try {
        response = await fetch("https://api.openai.com/v1/responses", {
          method: "POST",
          signal: abortController.signal,
          headers: {
            Authorization: `Bearer ${openAiApiKey.value()}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            model: "gpt-5.2",
            reasoning: { effort: "low" },
            max_output_tokens: 3000,
            input: [
              {
                role: "system",
                content: [
                  {
                    type: "input_text",
                    text:
                      "You are a nutrition expert. Analyze meal images and return ONLY valid JSON. " +
                      "THINK STEP-BY-STEP (internally) BEFORE ANSWERING: identify foods → determine mass → derive per-gram macros → scale to mass → compute calories with 4/4/9 → sanity-check totals. " +
                      "DO NOT return your reasoning, only the final JSON. " +
                      "OUTPUT FORMAT: {\"f\":[{\"n\":\"food name\",\"m\":grams,\"k\":calories,\"p\":protein_g,\"c\":carbs_g,\"a\":fat_g}]} " +
                      "RULES: " +
                      "- All numeric values must be numbers, not strings. " +
                      "- Use at least 1 decimal place for grams/calories when appropriate. " +
                      "- k MUST equal (p×4)+(c×4)+(a×9) exactly. " +
                      "- If a scale shows weight, that is the authoritative mass; for multiple items on one scale, estimate proportional weight per item. " +
                      "- Prefer slightly conservative estimates over overestimates when uncertain. " +
                      "Example: 150g chicken breast → ~46.5g protein, ~0g carbs, ~4.5g fat → (46.5×4)+(0×4)+(4.5×9) = 226.5 calories",
                  },
                ],
              },
              {
                role: "user",
                content: [
                  {
                    type: "input_text",
                    text: "Analyze this meal and break down each food item.",
                  },
                  ...(userContext
                    ? [
                        {
                          type: "input_text",
                          text: `User context (optional): ${userContext}`,
                        },
                      ]
                    : []),
                  {
                    type: "input_image",
                    image_url: imageUrl,
                  },
                ],
              },
            ],
          }),
        });
      } finally {
        clearTimeout(timeoutHandle);
      }

      if (!response.ok) {
        console.error(`OpenAI image analysis failed with status ${response.status}`);
        throw new HttpsError(
          "unavailable",
          "Meal analysis provider request failed"
        );
      }

      const responseData = (await response.json()) as any;
      const rawText = extractOpenAiTextResponse(responseData);
      const parsed = JSON.parse(extractFirstJsonObject(rawText)) as any;
      const analysis = normalizeMealAnalysisPayload(parsed);

      return { analysis };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }
      if (error instanceof Error && error.name === "AbortError") {
        throw new HttpsError("deadline-exceeded", "Meal analysis request timed out");
      }
      console.error("analyzeMealImage failed:", error);
      throw new HttpsError("internal", "Meal analysis failed");
    }
  }
);

function extractTextFromResponseNode(node: any): string | null {
  if (node === null || node === undefined) {
    return null;
  }

  if (typeof node === "string" && node.trim().length > 0) {
    return node;
  }

  if (Array.isArray(node)) {
    for (const item of node.slice().reverse()) {
      const found = extractTextFromResponseNode(item);
      if (found) {
        return found;
      }
    }
    return null;
  }

  if (typeof node === "object") {
    const text = typeof node.text === "string" ? node.text : null;
    if (text && text.trim().length > 0) {
      return text;
    }

    const outputText =
      typeof node.output_text === "string" ? node.output_text : null;
    if (outputText && outputText.trim().length > 0) {
      return outputText;
    }

    const foundInContent = extractTextFromResponseNode(node.content);
    if (foundInContent) {
      return foundInContent;
    }
  }

  return null;
}

function extractOpenAiTextResponse(responseData: any): string {
  const directOutputText =
    typeof responseData?.output_text === "string" ? responseData.output_text : "";
  if (directOutputText.trim().length > 0) {
    return directOutputText;
  }

  const output = responseData?.output;
  const fromOutput = extractTextFromResponseNode(output);
  if (fromOutput) {
    return fromOutput;
  }

  const choices = responseData?.choices;
  const fromChoices = extractTextFromResponseNode(choices);
  if (fromChoices) {
    return fromChoices;
  }

  throw new Error("OpenAI response missing text output");
}

function extractFirstJsonObject(text: string): string {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) {
    throw new Error("No JSON object found in model response");
  }
  return text.substring(start, end + 1);
}

function normalizeMealAnalysisPayload(payload: any): {
  f: Array<{ n: string; m: number; k: number; p: number; c: number; a: number }>;
} {
  const foodsRaw = (
    Array.isArray(payload?.f)
      ? payload.f
      : Array.isArray(payload?.foods)
      ? payload.foods
      : []
  ).slice(0, MAX_ANALYZED_FOOD_ITEMS);

  const foods = foodsRaw.map((item: any, index: number) => {
    const nameRaw =
      (item?.n ?? item?.name ?? `Food ${index + 1}`).toString().trim();
    const name = nameRaw.length > 0 ? nameRaw : `Food ${index + 1}`;

    const mass = roundTo(toNonNegativeNumber(item?.m ?? item?.mass), 1);
    const protein = roundTo(toNonNegativeNumber(item?.p ?? item?.protein), 1);
    const carbs = roundTo(toNonNegativeNumber(item?.c ?? item?.carbs), 1);
    const fat = roundTo(toNonNegativeNumber(item?.a ?? item?.fat), 1);
    const calories = roundTo(protein * 4 + carbs * 4 + fat * 9, 1);

    return {
      n: name,
      m: mass,
      k: calories,
      p: protein,
      c: carbs,
      a: fat,
    };
  });

  return { f: foods };
}
