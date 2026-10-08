/**
 * F27-T12 · The error codes `report-error` accepts, and nothing else.
 *
 * Q13 chose our own table behind an Edge Function **that only accepts
 * allowlisted error codes**. This file is that allowlist, and it is the whole
 * reason this endpoint can be trusted: a client cannot smuggle anything
 * through a field whose every permitted value is enumerated here.
 *
 * ── Why these names, and not §31's ───────────────────────────────────────
 *
 * These are the APP's codes — `errorCodeOf` in
 * `lib/core/logging/error_code.dart`, one per `AppFailure` leaf — plus the two
 * crash kinds from `LogCrashKind`. They are not the §31 wire codes the server
 * returns, which are a smaller, server-side vocabulary. A report says "the app
 * hit this condition", which is a superset: `CAMERA_PERMISSION` and
 * `LOCAL_DATABASE` never cross the network as §31 codes but are exactly the
 * kind of thing production monitoring exists to count.
 *
 * ── Keeping the two sides in step ────────────────────────────────────────
 *
 * `test/core/logging/error_report_codes_test.dart` reads **this file** and
 * compares it with the Dart source, so a new `AppFailure` added without a code
 * here fails the Flutter suite rather than being silently rejected at runtime
 * by a 400 nobody is watching.
 *
 * Adding a code is a deliberate act in two places. That is the point.
 */

export const REPORTABLE_ERROR_CODES = [
  // Local failures (device, storage, permissions, on-device OCR)
  "CAMERA_PERMISSION",
  "GALLERY_ACCESS",
  "IMAGE_QUALITY",
  "IMAGE_PROCESSING",
  "OCR_INIT",
  "OCR",
  "NO_TEXT_DETECTED",
  "LOCAL_DATABASE",
  "LAUNCH",
  "FILE_ENCRYPTION",
  "FILE_STORAGE",
  "NOTIFICATION_PERMISSION",
  "NOTIFICATION_SCHEDULING",
  "TTS",
  // F27-T20. The app can produce it (`errorCodeOf` is exhaustive), so the
  // server has to accept it, even though nothing reports it today: it is a
  // settings-screen link that would not open.
  "EXTERNAL_LINK",
  "ANALYSIS_CONSENT_DECLINED",
  // Network and backend
  "NO_INTERNET",
  "REQUEST_TIMEOUT",
  "UNAUTHORIZED",
  "DAILY_LIMIT_REACHED",
  "GLOBAL_CAPACITY_REACHED",
  "ANALYSIS_DISABLED",
  "UNSUPPORTED_APP_VERSION",
  "INVALID_REQUEST",
  "ANALYSIS_SERVICE",
  "INVALID_ANALYSIS_RESPONSE",
  "AI_PROVIDER_RATE_LIMIT",
  "ONLINE_OCR_UNAVAILABLE",
  // Business outcomes
  "UNSUPPORTED_DOCUMENT",
  "PARTIAL_ANALYSIS",
  "AMBIGUOUS_DATE",
  "MISSING_REMINDER_TIME",
  // Uncaught errors (LogCrashKind) — the two H1 was really about
  "UNCAUGHT_FLUTTER_ERROR",
  "UNCAUGHT_PLATFORM_ERROR",
] as const;

export type ReportableErrorCode = typeof REPORTABLE_ERROR_CODES[number];

/** The analysis stages a report may be attributed to (`LogStage`). */
export const REPORTABLE_STAGES = [
  "capture",
  "ocr",
  "analyze",
  "save",
] as const;

/** Outcome of the attempt the report belongs to (`LogResultStatus`). */
export const REPORTABLE_RESULT_STATUSES = [
  "success",
  "partial",
  "failure",
] as const;

export function isReportableErrorCode(
  value: unknown,
): value is ReportableErrorCode {
  return typeof value === "string" &&
    (REPORTABLE_ERROR_CODES as readonly string[]).includes(value);
}
