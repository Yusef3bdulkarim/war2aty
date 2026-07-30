/**
 * F06-T05 · Tests for the error contract.
 *
 * These pin the wire format the Flutter client already parses
 * (`analysis_error_mapper.dart`), so a rename here fails loudly instead of
 * silently degrading every error to AnalysisServiceFailure on the device.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  ApiError,
  apiErrorForAuthFailure,
  toApiError,
} from "../../functions/_shared/errors/api-error.ts";
import {
  ERROR_CODES,
  type ErrorCode,
  httpStatusForErrorCode,
  isErrorCode,
} from "../../functions/_shared/errors/error-codes.ts";

// ── codes ─────────────────────────────────────────────────────────────────

Deno.test("the code vocabulary matches API_CONTRACT §31 exactly", () => {
  // Any addition or rename must be a deliberate contract change: the client
  // switches on these strings and treats unknowns as a generic server failure.
  assertEquals([...ERROR_CODES].sort(), [
    "AI_RATE_LIMITED",
    "ANALYSIS_DISABLED",
    "ANALYSIS_FAILED",
    "DAILY_LIMIT_REACHED",
    "INTERNAL_ERROR",
    "INVALID_REQUEST",
    "TIMEOUT",
    "UNAUTHORIZED",
    "UNSUPPORTED_APP_VERSION",
    "UNSUPPORTED_SCHEMA",
  ]);
});

Deno.test("every code maps to the status in the §31 table", () => {
  const expected: Record<ErrorCode, number> = {
    INVALID_REQUEST: 400,
    UNSUPPORTED_SCHEMA: 400,
    UNSUPPORTED_APP_VERSION: 400,
    UNAUTHORIZED: 401,
    TIMEOUT: 408,
    DAILY_LIMIT_REACHED: 429,
    AI_RATE_LIMITED: 429,
    ANALYSIS_FAILED: 500,
    INTERNAL_ERROR: 500,
    ANALYSIS_DISABLED: 503,
  };

  for (const code of ERROR_CODES) {
    assertEquals(httpStatusForErrorCode(code), expected[code], code);
  }
});

Deno.test("isErrorCode accepts known codes and rejects §48 spellings", () => {
  assertEquals(isErrorCode("DAILY_LIMIT_REACHED"), true);
  // Master-plan §48 names that were deliberately NOT adopted.
  assertEquals(isErrorCode("AI_TIMEOUT"), false);
  assertEquals(isErrorCode("INTERNAL_SERVER_ERROR"), false);
  assertEquals(isErrorCode("UNSUPPORTED_SCHEMA_VERSION"), false);
  assertEquals(isErrorCode(""), false);
  assertEquals(isErrorCode(null), false);
});

// ── body shape ────────────────────────────────────────────────────────────

Deno.test("toBody produces the §31 envelope", () => {
  assertEquals(ApiError.unauthorized().toBody(), {
    error: {
      code: "UNAUTHORIZED",
      message: "Missing or invalid credentials.",
    },
  });
});

Deno.test("toBody omits details entirely when there are none", async () => {
  // §31 sets additionalProperties:false, and `details: null` is not schema
  // valid — the key must be absent from the JSON that goes on the wire.
  const serialised = await ApiError.timeout().toResponse().json();

  assertEquals(Object.keys(serialised.error), ["code", "message"]);
  assertEquals("details" in serialised.error, false);
});

Deno.test("dailyLimitReached carries reset_at so the client can say when", () => {
  const resetAt = "2026-07-27T00:00:00+03:00";
  const error = ApiError.dailyLimitReached(resetAt).toBody().error;

  assertEquals(error.code, "DAILY_LIMIT_REACHED");
  assertEquals(error.details?.reset_at, resetAt);
});

Deno.test("the serialised body has no §48 fields", async () => {
  const body = await ApiError.internalError().toResponse().json();

  // success / requestId / retryable would violate additionalProperties:false.
  assertEquals(Object.keys(body), ["error"]);
  for (const key of ["success", "requestId", "retryable"]) {
    assertEquals(key in body, false, `${key} must not be serialised`);
  }
});

// ── responses ─────────────────────────────────────────────────────────────

Deno.test("toResponse uses the code's status", () => {
  assertEquals(ApiError.dailyLimitReached("2026-07-27T00:00:00+03:00").toResponse().status, 429);
  assertEquals(ApiError.analysisDisabled().toResponse().status, 503);
  assertEquals(ApiError.unauthorized().toResponse().status, 401);
});

Deno.test("toResponse echoes the request id and stays uncacheable", () => {
  const response = ApiError.internalError().toResponse(
    "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c",
  );

  assertEquals(
    response.headers.get("x-request-id"),
    "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c",
  );
  assertEquals(response.headers.get("Cache-Control"), "no-store");
});

// ── normalisation ─────────────────────────────────────────────────────────

Deno.test("toApiError passes an ApiError through unchanged", () => {
  const original = ApiError.aiRateLimited();

  assertEquals(toApiError(original), original);
});

Deno.test("toApiError discards a thrown error's message", () => {
  // The message could quote the payload that caused it — i.e. the document.
  const leaky = new Error("failed parsing: مبلغ 850 جنيه, account 12345678");
  const converted = toApiError(leaky);

  assertEquals(converted.code, "INTERNAL_ERROR");
  assertEquals(converted.message, "Unexpected server error.");
  assert(!converted.message.includes("850"));
  assert(!converted.message.includes("12345678"));
});

Deno.test("toApiError handles non-Error throws", () => {
  assertEquals(toApiError("a string").code, "INTERNAL_ERROR");
  assertEquals(toApiError(undefined).code, "INTERNAL_ERROR");
  assertEquals(toApiError({ secret: "value" }).code, "INTERNAL_ERROR");
});

Deno.test("an ApiError is catchable as an Error", () => {
  // It must survive a generic `catch (e)` without losing its identity.
  try {
    throw ApiError.unsupportedSchema();
  } catch (thrown) {
    assert(thrown instanceof Error);
    assert(thrown instanceof ApiError);
    assertEquals((thrown as ApiError).code, "UNSUPPORTED_SCHEMA");
  }
});

// ── auth mapping (F06-T03 seam) ───────────────────────────────────────────

Deno.test("caller-side auth failures become 401", () => {
  assertEquals(apiErrorForAuthFailure("missing_token").status, 401);
  assertEquals(apiErrorForAuthFailure("invalid_token").status, 401);
  assertEquals(apiErrorForAuthFailure("missing_token").code, "UNAUTHORIZED");
});

Deno.test("an unreachable auth service becomes 500, not 401", () => {
  // Reporting an outage as "not signed in" would send the user looking for a
  // login screen this app does not have.
  const error = apiErrorForAuthFailure("verification_failed");

  assertEquals(error.status, 500);
  assertEquals(error.code, "INTERNAL_ERROR");
});
