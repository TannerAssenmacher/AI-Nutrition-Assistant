# Security Best Practices Review Report

Date: 2026-02-24  
Project: AI Nutrition Assistant

## Executive Summary

This review found **10 security findings**:
- **2 Critical**
- **4 High**
- **3 Medium**
- **1 Low**

Highest-risk issues:
1. Firestore is globally readable/writable.
2. Third-party API keys are hardcoded in tracked scripts.

These two findings should be remediated first before additional feature work.

## Scope

Reviewed:
- `functions/src/index.ts`
- `firestore.rules`
- `firebase.json`
- `scripts/recipe_ingestion/*.js`
- Key Flutter/Firebase integration files (`lib/main.dart`, `pubspec.yaml`, service clients)

Guidance baseline:
- `javascript-express-web-server-security.md` from the `$security-best-practices` skill (applied to Firebase HTTP/callable backend patterns).

## Critical Findings

### SBP-001: Firestore rules allow unrestricted global read/write
- Severity: **Critical**
- Evidence: `allow read, write: if true;` in `firestore.rules:4`
- Impact (one sentence): Any internet client can read, modify, or delete all Firestore data, including user profile and nutrition history.
- Secure-by-default remediation:
  1. Replace with default-deny rules and explicit allow rules per collection.
  2. Require `request.auth != null` for user data.
  3. Restrict user-owned paths to `request.auth.uid == userId`.
  4. Keep recipe catalog reads public only if truly intended, and lock writes to admin/service accounts.
  5. Add schema validation in rules (`request.resource.data.keys().hasOnly(...)`, type checks, bounds).

### SBP-002: Hardcoded Spoonacular API keys committed in repository scripts
- Severity: **Critical**
- Evidence:
  - `scripts/recipe_ingestion/daily_fetch.js:35`
  - `scripts/recipe_ingestion/test_fetch.js:15`
- Impact (one sentence): Exposed keys can be harvested and abused to exhaust quotas or incur costs, and must be treated as compromised.
- Secure-by-default remediation:
  1. **Rotate all exposed Spoonacular keys immediately**.
  2. Remove hardcoded keys; load from env or secret manager at runtime.
  3. Add secret scanning in CI (e.g., gitleaks/trufflehog + GitHub secret scanning).
  4. Clean secret history if required by policy (BFG/git-filter-repo).

## High Findings

### SBP-003: `searchRecipes` callable lacks server-side authentication enforcement
- Severity: **High**
- Evidence: handler begins without `request.auth` validation in `functions/src/index.ts:1796`
- Impact: Unauthenticated callers can trigger expensive embedding + database search workloads.
- Secure-by-default remediation:
  1. Require auth at function entry (`if (!request.auth) throw ...`).
  2. Consider rejecting anonymous users for cost-intensive endpoints.
  3. Pair with App Check enforcement (SBP-006).

### SBP-004: Gemini API key is sent in URL and logged on failure
- Severity: **High**
- Evidence:
  - API key in query string: `functions/src/index.ts:78`
  - Full URL logged: `functions/src/index.ts:95`
- Impact: Secrets can leak into logs/telemetry/error tooling.
- Secure-by-default remediation:
  1. Send API key in header (`x-goog-api-key`) instead of URL query.
  2. Remove URL logging and redact upstream errors before logging.
  3. Use structured logging with explicit redaction rules.

### SBP-005: Missing request-size and abuse controls on expensive AI endpoints
- Severity: **High**
- Evidence:
  - Unbounded prompt/history/image input handling: `functions/src/index.ts:623`, `functions/src/index.ts:640`, `functions/src/index.ts:727`
  - Unbounded result `limit` accepted from caller: `functions/src/index.ts:1811`
- Impact: Attackers can force large memory/CPU/token consumption and drive operational costs.
- Secure-by-default remediation:
  1. Add strict schema validation at function boundary.
  2. Clamp numeric parameters (`limit`, `maxResults`) to safe ranges.
  3. Enforce maximum payload sizes (image bytes, text length, history length).
  4. Add per-user/IP rate limiting and daily quotas.

### SBP-006: App Check not implemented/enforced for callable endpoints
- Severity: **High**
- Evidence:
  - No `firebase_app_check` dependency in `pubspec.yaml:11`
  - No App Check activation in `lib/main.dart:62`
  - Callable configs omit `enforceAppCheck` in `functions/src/index.ts:607`, `functions/src/index.ts:713`, `functions/src/index.ts:1432`, `functions/src/index.ts:1524`, `functions/src/index.ts:1584`, `functions/src/index.ts:1796`
- Impact: Non-official clients and automated abuse traffic can call backend endpoints more easily.
- Secure-by-default remediation:
  1. Add Firebase App Check to client apps.
  2. Set `enforceAppCheck: true` on all callable/onRequest endpoints that should be app-only.
  3. Monitor rejected App Check traffic to tune rollout.

## Medium Findings

### SBP-007: Sensitive user context is logged in backend
- Severity: **Medium**
- Evidence:
  - Query/profile logging: `functions/src/index.ts:1901`, `functions/src/index.ts:1902`
  - Param logging: `functions/src/index.ts:1988`
  - Consumption/profile detail logging: `functions/src/index.ts:2121`, `functions/src/index.ts:2144`
- Impact: Health and preference data persists in logs, increasing privacy and incident exposure risk.
- Secure-by-default remediation:
  1. Remove or minimize user-content logs in production.
  2. Log aggregate metrics only (counts, latencies, status).
  3. Add retention and access controls for Cloud Logging.

### SBP-008: Detailed upstream/provider errors are returned to clients
- Severity: **Medium**
- Evidence:
  - Raw Gemini message surfaced: `functions/src/index.ts:704`
  - Full OpenAI body included in error: `functions/src/index.ts:799`
- Impact: Internal behavior and provider response details can be leaked to attackers.
- Secure-by-default remediation:
  1. Return generic client-safe errors.
  2. Log detailed internals server-side with redaction.
  3. Attach correlation IDs for support/debug instead of raw provider payloads.

### SBP-009: `proxyImage` hardening is incomplete (validation/timeouts/size limits)
- Severity: **Medium**
- Evidence:
  - Prefix-based URL check: `functions/src/index.ts:575`
  - No fetch timeout/body limit: `functions/src/index.ts:582`
  - Wildcard CORS set: `functions/src/index.ts:590`
- Impact: Endpoint can be abused for bandwidth/compute consumption and malformed URL edge cases.
- Secure-by-default remediation:
  1. Parse URL and enforce exact hostname allowlist.
  2. Add fetch timeout and max response size.
  3. Restrict content type to expected image media types.
  4. Apply rate limiting for this public endpoint.

## Low Findings

### SBP-010: Dependency vulnerability state is unverified in this run
- Severity: **Low**
- Evidence: `npm audit` failed due offline registry access in both `functions` and `scripts/recipe_ingestion`.
- Impact: Known vulnerable dependency versions could remain undetected.
- Secure-by-default remediation:
  1. Run `npm audit` in CI with network access.
  2. Enable Dependabot/Renovate for automated updates.
  3. Gate merges on high/critical vulnerability thresholds.

## Priority Remediation Order

1. Fix Firestore rules (SBP-001).
2. Rotate/remove committed keys (SBP-002).
3. Lock down callable access (`request.auth`, App Check, input caps) (SBP-003/005/006).
4. Remove secret/PII leakage paths in logs and error responses (SBP-004/007/008).
5. Harden public image proxy and add dependency audit automation (SBP-009/010).
