import { HttpsError } from "firebase-functions/v2/https";

import { ALLOWED_IMAGE_MIME_TYPES, MAX_IMAGE_PAYLOAD_BYTES } from "./config";

export function toNullableNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

export function clampNumber(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) {
    return min;
  }
  return Math.min(max, Math.max(min, value));
}

export function toRequestData(value: unknown): Record<string, any> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, any>;
  }
  return {};
}

export function sanitizeTextInput(value: unknown, maxLength: number): string {
  const normalized = (value ?? "").toString().trim();
  if (!normalized) {
    return "";
  }
  return normalized.substring(0, maxLength);
}

export function sanitizeStringArray(
  value: unknown,
  maxItems: number,
  maxItemLength: number
): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  const sanitized: string[] = [];
  const seen = new Set<string>();
  for (const entry of value) {
    const item = sanitizeTextInput(entry, maxItemLength);
    if (!item) {
      continue;
    }
    const key = item.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    sanitized.push(item);
    if (sanitized.length >= maxItems) {
      break;
    }
  }

  return sanitized;
}

export function estimateBase64DecodedBytes(base64: string): number {
  const normalized = base64.replace(/\s+/g, "");
  if (!normalized) {
    return 0;
  }

  let padding = 0;
  if (normalized.endsWith("==")) {
    padding = 2;
  } else if (normalized.endsWith("=")) {
    padding = 1;
  }

  return Math.max(0, Math.floor((normalized.length * 3) / 4) - padding);
}

export function validateImagePayload(base64: string, mimeType: string): void {
  if (!ALLOWED_IMAGE_MIME_TYPES.has(mimeType)) {
    throw new HttpsError("invalid-argument", "Unsupported image mimeType");
  }

  const decodedSize = estimateBase64DecodedBytes(base64);
  if (decodedSize <= 0 || decodedSize > MAX_IMAGE_PAYLOAD_BYTES) {
    throw new HttpsError(
      "invalid-argument",
      "Image payload exceeds the maximum allowed size"
    );
  }
}

export function normalizeBase64Payload(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }

  const commaIndex = trimmed.indexOf(",");
  if (trimmed.startsWith("data:") && commaIndex > 0) {
    return trimmed.substring(commaIndex + 1);
  }

  return trimmed;
}

export function toNonNegativeNumber(value: unknown): number {
  const parsed = toNullableNumber(value) ?? 0;
  if (!Number.isFinite(parsed)) {
    return 0;
  }
  return parsed < 0 ? 0 : parsed;
}

export function roundTo(value: number, decimals: number): number {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}
