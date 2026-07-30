/**
 * F06-T04 · Tests for the HTTP scaffolding.
 */

import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";

import {
  CORS_HEADERS,
  isPreflightRequest,
  preflightResponse,
} from "../../functions/_shared/http/cors.ts";
import {
  isUuid,
  REQUEST_ID_HEADER,
  resolveRequestId,
} from "../../functions/_shared/http/request-id.ts";
import { emptyResponse, jsonResponse } from "../../functions/_shared/http/response.ts";

function request(
  method: string,
  headers: Record<string, string> = {},
): Request {
  return new Request("https://example.test/functions/v1/analyze-document", {
    method,
    headers,
  });
}

// ── cors ──────────────────────────────────────────────────────────────────

Deno.test("isPreflightRequest recognises OPTIONS", () => {
  assertEquals(isPreflightRequest(request("OPTIONS")), true);
});

Deno.test("isPreflightRequest ignores real calls", () => {
  assertEquals(isPreflightRequest(request("POST")), false);
  assertEquals(isPreflightRequest(request("GET")), false);
});

Deno.test("preflightResponse answers 204 with no body", async () => {
  const response = preflightResponse();

  assertEquals(response.status, 204);
  assertEquals(await response.text(), "");
});

Deno.test("preflightResponse advertises the headers the app sends", () => {
  const allowed = preflightResponse().headers.get("Access-Control-Allow-Headers") ?? "";

  // Without these the browser blocks the call before it is even made.
  for (const header of ["authorization", "content-type", "x-request-id"]) {
    assert(allowed.includes(header), `${header} must be allowed`);
  }
});

Deno.test("preflightResponse allows only the methods the endpoints serve", () => {
  const allowed = preflightResponse().headers.get("Access-Control-Allow-Methods") ?? "";

  assert(allowed.includes("POST"));
  assert(allowed.includes("GET"));
  assert(!allowed.includes("DELETE"), "no endpoint serves DELETE");
  assert(!allowed.includes("PUT"), "no endpoint serves PUT");
});

Deno.test("CORS_HEADERS cannot be mutated by a caller", () => {
  // Frozen so one handler cannot poison the headers for every other request.
  const mutate = () => {
    (CORS_HEADERS as Record<string, string>)["Access-Control-Allow-Origin"] = "https://evil.test";
  };

  try {
    mutate();
  } catch {
    // Strict mode throws; non-strict silently ignores. Either is acceptable.
  }

  assertEquals(CORS_HEADERS["Access-Control-Allow-Origin"], "*");
});

// ── request id ────────────────────────────────────────────────────────────

Deno.test("isUuid accepts a canonical uuid", () => {
  assertEquals(isUuid("bd8aefbb-59bf-4fbc-9d56-47ec6105a22c"), true);
});

Deno.test("isUuid rejects malformed values", () => {
  assertEquals(isUuid(""), false);
  assertEquals(isUuid("not-a-uuid"), false);
  assertEquals(isUuid("bd8aefbb59bf4fbc9d5647ec6105a22c"), false);
  assertEquals(isUuid("bd8aefbb-59bf-4fbc-9d56-47ec6105a22"), false);
  assertEquals(isUuid("zd8aefbb-59bf-4fbc-9d56-47ec6105a22c"), false);
});

Deno.test("resolveRequestId keeps a valid client id so retries stay idempotent", () => {
  const resolved = resolveRequestId(
    request("POST", { [REQUEST_ID_HEADER]: "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c" }),
  );

  assertEquals(resolved.requestId, "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c");
  assertEquals(resolved.source, "client");
});

Deno.test("resolveRequestId normalises case and whitespace", () => {
  // A retry that differs only in casing must resolve to the same key.
  const resolved = resolveRequestId(
    request("POST", { [REQUEST_ID_HEADER]: "  BD8AEFBB-59BF-4FBC-9D56-47EC6105A22C  " }),
  );

  assertEquals(resolved.requestId, "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c");
  assertEquals(resolved.source, "client");
});

Deno.test("resolveRequestId mints an id when the header is absent", () => {
  const resolved = resolveRequestId(request("POST"));

  assertEquals(resolved.source, "generated");
  assertEquals(isUuid(resolved.requestId), true);
});

Deno.test("resolveRequestId treats a malformed id as absent rather than failing", () => {
  const resolved = resolveRequestId(
    request("POST", { [REQUEST_ID_HEADER]: "../../etc/passwd" }),
  );

  assertEquals(resolved.source, "generated");
  assertEquals(isUuid(resolved.requestId), true);
});

Deno.test("resolveRequestId mints a different id each time", () => {
  const first = resolveRequestId(request("POST")).requestId;
  const second = resolveRequestId(request("POST")).requestId;

  assertNotEquals(first, second);
});

// ── response ──────────────────────────────────────────────────────────────

Deno.test("jsonResponse serialises the body and defaults to 200", async () => {
  const response = jsonResponse({ status: "ok", schemaVersion: "1.0" });

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { status: "ok", schemaVersion: "1.0" });
});

Deno.test("jsonResponse honours an explicit status", () => {
  assertEquals(jsonResponse({}, { status: 429 }).status, 429);
});

Deno.test("jsonResponse marks every body no-store", () => {
  // An analysis describes someone's bill or medical report — it must never be
  // cached by a proxy, CDN, or browser.
  const response = jsonResponse({ summary: "..." });

  assertEquals(response.headers.get("Cache-Control"), "no-store");
  assertEquals(response.headers.get("X-Content-Type-Options"), "nosniff");
});

Deno.test("jsonResponse sends JSON content type with utf-8", () => {
  // Arabic bodies are the norm here, so the charset must be explicit.
  const contentType = jsonResponse({}).headers.get("Content-Type") ?? "";

  assert(contentType.includes("application/json"));
  assert(contentType.includes("utf-8"));
});

Deno.test("jsonResponse round-trips Arabic content intact", async () => {
  const summary = "فاتورة كهرباء لشهر مارس بمبلغ ٨٥٠ جنيه.";
  const response = jsonResponse({ summary });

  assertEquals((await response.json()).summary, summary);
});

Deno.test("jsonResponse echoes the request id when given one", () => {
  const response = jsonResponse({}, {
    requestId: "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c",
  });

  assertEquals(
    response.headers.get(REQUEST_ID_HEADER),
    "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c",
  );
});

Deno.test("jsonResponse omits the request id header when none is given", () => {
  assertEquals(jsonResponse({}).headers.get(REQUEST_ID_HEADER), null);
});

Deno.test("jsonResponse carries CORS headers", () => {
  assertEquals(
    jsonResponse({}).headers.get("Access-Control-Allow-Origin"),
    "*",
  );
});

Deno.test("jsonResponse lets a caller override a default header", () => {
  const response = jsonResponse({}, {
    headers: { "Cache-Control": "public, max-age=60" },
  });

  assertEquals(response.headers.get("Cache-Control"), "public, max-age=60");
});

Deno.test("emptyResponse sends no body but keeps correlation and CORS", async () => {
  const response = emptyResponse(204, "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c");

  assertEquals(response.status, 204);
  assertEquals(await response.text(), "");
  assertEquals(
    response.headers.get(REQUEST_ID_HEADER),
    "bd8aefbb-59bf-4fbc-9d56-47ec6105a22c",
  );
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
});
