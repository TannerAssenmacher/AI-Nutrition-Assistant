import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { Pool } from "pg";

import {
  DEFAULT_RATE_LIMIT_WINDOW_MS,
  ENFORCE_APP_CHECK,
  INSTANCE_CONNECTION_NAME,
  RATE_LIMIT_COLLECTION,
  RATE_LIMIT_DOC_TTL_MS,
  pgPassword,
} from "./config";

if (!getApps().length) {
  initializeApp();
}

export const db = getFirestore();

let pool: Pool | null = null;

export function getPool(): Pool {
  if (!pool) {
    const isProduction = process.env.K_SERVICE !== undefined;

    if (isProduction) {
      pool = new Pool({
        host: `/cloudsql/${INSTANCE_CONNECTION_NAME}`,
        user: "postgres",
        password: pgPassword.value(),
        database: "recipes_db",
      });
    } else {
      pool = new Pool({
        host: process.env.PG_HOST || "127.0.0.1",
        port: parseInt(process.env.PG_PORT || "5433", 10),
        user: process.env.PG_USER || "postgres",
        password: process.env.PG_PASSWORD,
        database: process.env.PG_DATABASE || "recipes_db",
      });
    }
  }
  return pool;
}

export function enforceAppCheckIfRequired(request: any, endpointName: string): void {
  if (!ENFORCE_APP_CHECK) {
    return;
  }
  if (request?.app) {
    return;
  }
  throw new HttpsError(
    "failed-precondition",
    `App Check is required for ${endpointName}`
  );
}

export async function enforcePerUserRateLimit(options: {
  uid: string;
  endpointName: string;
  maxRequests: number;
  windowMs?: number;
}): Promise<void> {
  const windowMs = options.windowMs ?? DEFAULT_RATE_LIMIT_WINDOW_MS;
  const nowMs = Date.now();
  const windowStartMs = Math.floor(nowMs / windowMs) * windowMs;
  const docId = `${options.endpointName}:${options.uid}:${windowStartMs}`;
  const docRef = db.collection(RATE_LIMIT_COLLECTION).doc(docId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(docRef);
    const currentCount = snapshot.exists
      ? Number(snapshot.data()?.count || 0)
      : 0;

    if (currentCount >= options.maxRequests) {
      throw new HttpsError(
        "resource-exhausted",
        `Rate limit exceeded for ${options.endpointName}`
      );
    }

    transaction.set(
      docRef,
      {
        endpoint: options.endpointName,
        uid: options.uid,
        count: currentCount + 1,
        windowStartMs,
        expiresAt: new Date(windowStartMs + RATE_LIMIT_DOC_TTL_MS),
      },
      { merge: true }
    );
  });
}
