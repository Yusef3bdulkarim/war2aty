/**
 * F27-T12 · Parsing and validating the `report-error` request.
 *
 * The same discipline as `analyze-request.ts`, for a smaller body: a closed
 * key allowlist, a closed value set for every field that has one, and a shape
 * check for the rest. Nothing downstream re-validates, and nothing reaches the
 * table that was not proven here.
 *
 * ── Why this is strict to the point of pedantry ──────────────────────────
 *
 * It is a write endpoint that exists to be called *when the app is broken*,
 * which is the worst moment to find out a field was permissive. Two risks it
 * closes:
 *
 * 1. **Content.** Every accepted value is either from a closed set, a uuid, a
 *    bounded integer, or a dotted version. There is no field a free-form
 *    string fits in, so the OCR text of a bill cannot arrive here even if a
 *    future client tried to attach it (§7, §51).
 * 2. **Junk.** An unknown key is rejected rather than ignored, so a client and
 *    a server that disagree fail loudly on the first call instead of writing
 *    half-populated rows nobody notices for a month.
 *
 * PRIVACY: no rejection message quotes any part of the body. Every one is a
 * fixed string from an `ApiError` factory.
 */

import { ApiError } from "../errors/api-error.ts";
import { isUuid } from "../http/request-id.ts";
import {
  isReportableErrorCode,
  REPORTABLE_RESULT_STATUSES,
  REPORTABLE_STAGES,
  type ReportableErrorCode,
} from "./error-report-codes.ts";

export interface ErrorReportRequest {
  readonly errorCode: ReportableErrorCode;
  readonly stage: string | null;
  readonly resultStatus: string | null;
  readonly requestId: string | null;
  readonly analysisSessionId: string | null;
  readonly httpStatus: number | null;
  readonly durationMs: number | null;
  readonly appVersion: string | null;
  readonly schemaVersion: string | null;
}

const TOP_LEVEL_KEYS: ReadonlySet<string> = new Set([
  "error_code",
  "stage",
  "result_status",
  "request_id",
  "analysis_session_id",
  "http_status",
  "duration_ms",
  "app_version",
  "schema_version",
]);

const APP_VERSION_PATTERN = /^\d+\.\d+\.\d+$/;

/** `"2.0"` today; a major-only `"3"` stays acceptable. */
const SCHEMA_VERSION_PATTERN = /^\d+(\.\d+)?$/;

/** Every HTTP status, and nothing that is not one. */
const MIN_HTTP_STATUS = 100;
const MAX_HTTP_STATUS = 599;

/**
 * Ten minutes. The client's own receive timeout is 40s, so anything near this
 * is already nonsense — the bound exists to keep the column an honest integer,
 * not to measure anything.
 */
const MAX_DURATION_MS = 600_000;

/** Matches the column's own `length()` bounds, deliberately. */
const MAX_APP_VERSION_LENGTH = 20;
const MAX_SCHEMA_VERSION_LENGTH = 10;

function asRecord(body: unknown): Record<string, unknown> {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    throw ApiError.invalidRequest("The request body must be a JSON object.");
  }
  return body as Record<string, unknown>;
}

/** A field that is absent or explicitly null is simply not reported. */
function isAbsent(value: unknown): boolean {
  return value === undefined || value === null;
}

function optionalMember(
  value: unknown,
  allowed: readonly string[],
  field: string,
): string | null {
  if (isAbsent(value)) return null;
  if (typeof value !== "string" || !allowed.includes(value)) {
    throw ApiError.invalidRequest(`\`${field}\` is not one of the allowed values.`);
  }
  return value;
}

function optionalUuid(value: unknown, field: string): string | null {
  if (isAbsent(value)) return null;
  if (typeof value !== "string" || !isUuid(value)) {
    throw ApiError.invalidRequest(`\`${field}\` must be a uuid.`);
  }
  return value;
}

function optionalInteger(
  value: unknown,
  min: number,
  max: number,
  field: string,
): number | null {
  if (isAbsent(value)) return null;
  if (typeof value !== "number" || !Number.isInteger(value) || value < min || value > max) {
    throw ApiError.invalidRequest(`\`${field}\` is out of range.`);
  }
  return value;
}

/**
 * A bounded, shaped string. The length limit matters as much as the pattern:
 * `^\d+\.\d+\.\d+$` happily matches a version with a thousand digits in it,
 * which is not content but is not a version either. The matching bound is on
 * the column (`length(app_version) <= 20`), so neither side can drift into
 * accepting what the other refuses.
 */
function optionalPattern(
  value: unknown,
  pattern: RegExp,
  maxLength: number,
  field: string,
): string | null {
  if (isAbsent(value)) return null;
  if (
    typeof value !== "string" || value.length > maxLength ||
    !pattern.test(value)
  ) {
    throw ApiError.invalidRequest(`\`${field}\` is malformed.`);
  }
  return value;
}

/**
 * Decodes one report. Throws an {@link ApiError} for anything that is not
 * exactly the agreed shape.
 */
export function parseErrorReportRequest(body: unknown): ErrorReportRequest {
  const record = asRecord(body);

  for (const key of Object.keys(record)) {
    if (!TOP_LEVEL_KEYS.has(key)) {
      // The key name is ours, not the caller's data — safe to omit anyway.
      throw ApiError.invalidRequest("The request contains an unknown field.");
    }
  }

  const errorCode = record.error_code;
  if (!isReportableErrorCode(errorCode)) {
    // The single most important line in this file: an unrecognised code is
    // refused, never stored (Q13).
    throw ApiError.invalidRequest("`error_code` is not a reportable code.");
  }

  return {
    errorCode,
    stage: optionalMember(record.stage, REPORTABLE_STAGES, "stage"),
    resultStatus: optionalMember(
      record.result_status,
      REPORTABLE_RESULT_STATUSES,
      "result_status",
    ),
    requestId: optionalUuid(record.request_id, "request_id"),
    analysisSessionId: optionalUuid(
      record.analysis_session_id,
      "analysis_session_id",
    ),
    httpStatus: optionalInteger(
      record.http_status,
      MIN_HTTP_STATUS,
      MAX_HTTP_STATUS,
      "http_status",
    ),
    durationMs: optionalInteger(
      record.duration_ms,
      0,
      MAX_DURATION_MS,
      "duration_ms",
    ),
    appVersion: optionalPattern(
      record.app_version,
      APP_VERSION_PATTERN,
      MAX_APP_VERSION_LENGTH,
      "app_version",
    ),
    schemaVersion: optionalPattern(
      record.schema_version,
      SCHEMA_VERSION_PATTERN,
      MAX_SCHEMA_VERSION_LENGTH,
      "schema_version",
    ),
  };
}
