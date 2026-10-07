/**
 * F27-T12 · Tests for the `report-error` request parser.
 *
 * The parser is the whole security story of this endpoint: it is the only
 * thing standing between a public, authenticated write path and a table in
 * our database. So these tests are mostly about what it REFUSES — an unknown
 * field, an unlisted code, a free-form string where a closed value belongs.
 */

import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { REPORTABLE_ERROR_CODES } from "../../functions/_shared/reports/error-report-codes.ts";
import { parseErrorReportRequest } from "../../functions/_shared/reports/error-report-request.ts";

const REQUEST_ID = "11111111-1111-4111-8111-111111111111";
const SESSION_ID = "22222222-2222-4222-8222-222222222222";

function fullBody(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    error_code: "OCR",
    stage: "ocr",
    result_status: "failure",
    request_id: REQUEST_ID,
    analysis_session_id: SESSION_ID,
    http_status: 502,
    duration_ms: 1200,
    app_version: "1.0.0",
    schema_version: "2.0",
    ...overrides,
  };
}

function assertRejects(body: unknown, because: string): void {
  const error = assertThrows(
    () => parseErrorReportRequest(body),
    ApiError,
    undefined,
    because,
  ) as ApiError;

  assertEquals(error.code, "INVALID_REQUEST", because);
}

Deno.test("parses a full report", () => {
  const parsed = parseErrorReportRequest(fullBody());

  assertEquals(parsed, {
    errorCode: "OCR",
    stage: "ocr",
    resultStatus: "failure",
    requestId: REQUEST_ID,
    analysisSessionId: SESSION_ID,
    httpStatus: 502,
    durationMs: 1200,
    appVersion: "1.0.0",
    schemaVersion: "2.0",
  });
});

Deno.test("accepts a report that is nothing but a code", () => {
  // What a crash sends: no stage, no request, no timings.
  const parsed = parseErrorReportRequest({ error_code: "UNCAUGHT_FLUTTER_ERROR" });

  assertEquals(parsed.errorCode, "UNCAUGHT_FLUTTER_ERROR");
  assertEquals(parsed.stage, null);
  assertEquals(parsed.requestId, null);
  assertEquals(parsed.httpStatus, null);
});

Deno.test("treats an explicit null like an absent field", () => {
  // The client omits nulls, but a future one may not, and a report is not
  // worth a 400 over the difference.
  const parsed = parseErrorReportRequest({
    error_code: "TTS",
    stage: null,
    http_status: null,
  });

  assertEquals(parsed.stage, null);
  assertEquals(parsed.httpStatus, null);
});

Deno.test("every allowlisted code is accepted", () => {
  // Guards the list against a typo that would make a code unreachable: the
  // sink swallows the 400, so a bad entry here is invisible in production.
  for (const code of REPORTABLE_ERROR_CODES) {
    assertEquals(parseErrorReportRequest({ error_code: code }).errorCode, code);
  }
});

Deno.test("refuses a code that is not on the allowlist", () => {
  for (const code of [
    "SOMETHING_ELSE",
    "ocr",
    "OCR ",
    "",
    "INTERNAL_ERROR", // a §31 server code, not an app code
  ]) {
    assertRejects({ error_code: code }, `code: ${JSON.stringify(code)}`);
  }
});

Deno.test("refuses a missing or non-string code", () => {
  assertRejects({}, "no code at all");
  assertRejects({ error_code: 7 }, "a number");
  assertRejects({ error_code: ["OCR"] }, "an array");
  assertRejects({ error_code: { code: "OCR" } }, "an object");
});

Deno.test("refuses an unknown field", () => {
  // The privacy tripwire. A client that tries to attach anything — a message,
  // a stack, the OCR text — is refused outright rather than having the extra
  // field ignored.
  assertRejects(fullBody({ message: "null pointer" }), "a message");
  assertRejects(fullBody({ stack_trace: "#0 main" }), "a stack trace");
  assertRejects(fullBody({ ocr_text: "فاتورة كهرباء" }), "document content");
  assertRejects({ error_code: "OCR", installation_id: "abc" }, "an installation id");
});

Deno.test("refuses a body that is not a JSON object", () => {
  for (const body of ["OCR", 7, true, null, [], ["OCR"]]) {
    assertRejects(body, `body: ${JSON.stringify(body)}`);
  }
});

Deno.test("refuses a stage or status outside its closed set", () => {
  assertRejects(fullBody({ stage: "upload" }), "unknown stage");
  assertRejects(fullBody({ stage: "OCR" }), "wrong case");
  assertRejects(fullBody({ stage: 1 }), "non-string stage");
  assertRejects(fullBody({ result_status: "failed" }), "near-miss status");
});

Deno.test("refuses an id that is not a uuid", () => {
  assertRejects(fullBody({ request_id: "req-123" }), "opaque request id");
  assertRejects(fullBody({ analysis_session_id: "sess-1" }), "opaque session id");
  assertRejects(fullBody({ request_id: 7 }), "numeric id");
});

Deno.test("refuses an out-of-range integer", () => {
  assertRejects(fullBody({ http_status: 99 }), "status below 100");
  assertRejects(fullBody({ http_status: 600 }), "status above 599");
  assertRejects(fullBody({ http_status: 200.5 }), "fractional status");
  assertRejects(fullBody({ http_status: "200" }), "status as a string");
  assertRejects(fullBody({ duration_ms: -1 }), "negative duration");
  assertRejects(fullBody({ duration_ms: 600_001 }), "duration past the bound");
});

Deno.test("refuses a malformed version", () => {
  assertRejects(fullBody({ app_version: "1.0" }), "two-part version");
  assertRejects(fullBody({ app_version: "1.0.0-dev" }), "suffixed version");
  assertRejects(fullBody({ app_version: "v1.0.0" }), "prefixed version");
  assertRejects(fullBody({ schema_version: "two" }), "word schema version");
});

Deno.test("accepts a major-only schema version", () => {
  assertEquals(
    parseErrorReportRequest(fullBody({ schema_version: "3" })).schemaVersion,
    "3",
  );
});

Deno.test("refuses a version that is shaped right but absurdly long", () => {
  // The pattern alone matches a thousand-digit version. Not content, but not a
  // version either — and the column's own `length()` check would refuse it, so
  // accepting it here would mean a 500 instead of a 400.
  assertRejects(
    fullBody({ app_version: `1.0.${"9".repeat(40)}` }),
    "over-long app version",
  );
  assertRejects(
    fullBody({ schema_version: "9".repeat(20) }),
    "over-long schema version",
  );
});

Deno.test("accepts a version at the bound", () => {
  const atBound = "100.100.1000000000";
  assertEquals(atBound.length, 18);
  assertEquals(
    parseErrorReportRequest(fullBody({ app_version: atBound })).appVersion,
    atBound,
  );
});
