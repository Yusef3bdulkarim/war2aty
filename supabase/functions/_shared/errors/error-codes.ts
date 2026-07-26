/**
 * F06-T05 · The error-code vocabulary.
 *
 * ── Which spec is authoritative ──────────────────────────────────────────
 * Master plan §48 and API_CONTRACT §31 disagree, so this follows **§31**:
 *
 *   - §31 is the later, precise artifact — it ships a draft-07 JSON Schema.
 *   - The Flutter client is already built against it (F05:
 *     `analysis_error_mapper.dart` switches on exactly these strings), so
 *     §48's names would break a shipped app.
 *   - §31's schema sets `additionalProperties: false`, which forbids §48's
 *     `success`, top-level `requestId` and `retryable` fields outright.
 *
 * No §48 concept is lost — each maps onto a §31 code:
 *
 * | §48 | §31 | why |
 * |---|---|---|
 * | `TEXT_TOO_LONG`, `EMPTY_OCR_TEXT` | `INVALID_REQUEST` | §31 rule 3 folds both into it |
 * | `UNSUPPORTED_SCHEMA_VERSION` | `UNSUPPORTED_SCHEMA` | rename only |
 * | `AI_TIMEOUT` | `TIMEOUT` | rename only |
 * | `INVALID_AI_RESPONSE` | `ANALYSIS_FAILED` | "AI returned unusable output" |
 * | `INTERNAL_SERVER_ERROR` | `INTERNAL_ERROR` | rename only |
 * | `UNSUPPORTED_DOCUMENT` | — | not an error: a 200 with `status: "unsupported"` (§31 rule 6) |
 *
 * The client maps codes to Arabic copy itself and never shows `message`, so
 * these strings are a machine contract — renaming one is a breaking change.
 */

export const ERROR_CODES = [
  "INVALID_REQUEST",
  "UNSUPPORTED_SCHEMA",
  "UNSUPPORTED_APP_VERSION",
  "UNAUTHORIZED",
  "TIMEOUT",
  "DAILY_LIMIT_REACHED",
  "AI_RATE_LIMITED",
  "ANALYSIS_FAILED",
  "INTERNAL_ERROR",
  "ANALYSIS_DISABLED",
] as const;

export type ErrorCode = typeof ERROR_CODES[number];

/**
 * HTTP status per code (§31 table).
 *
 * Written as a total `Record`, so adding a code without deciding its status is
 * a compile error rather than an `undefined` status at runtime.
 */
const HTTP_STATUS: Record<ErrorCode, number> = {
  INVALID_REQUEST: 400,
  UNSUPPORTED_SCHEMA: 400,
  UNSUPPORTED_APP_VERSION: 400,
  UNAUTHORIZED: 401,
  // 408 rather than 504: the contract models this as the analysis exceeding
  // `analysisTimeout`, which the client maps to RequestTimeoutFailure.
  TIMEOUT: 408,
  DAILY_LIMIT_REACHED: 429,
  AI_RATE_LIMITED: 429,
  ANALYSIS_FAILED: 500,
  INTERNAL_ERROR: 500,
  ANALYSIS_DISABLED: 503,
};

export function httpStatusForErrorCode(code: ErrorCode): number {
  return HTTP_STATUS[code];
}

export function isErrorCode(value: unknown): value is ErrorCode {
  return typeof value === "string" &&
    (ERROR_CODES as readonly string[]).includes(value);
}
