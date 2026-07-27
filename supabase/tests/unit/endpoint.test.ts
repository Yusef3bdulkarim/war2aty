/**
 * F06-T13 · Tests for the endpoint boundary.
 *
 * What matters here is that a handler cannot leak: no thrown value reaches the
 * client as anything but a §31 body, and no path loses the correlation id.
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { createEndpoint } from "../../functions/_shared/http/endpoint.ts";
import { jsonResponse } from "../../functions/_shared/http/response.ts";

const CLIENT_REQUEST_ID = "aaaaaaaa-0000-0000-0000-000000000001";

function endpoint(
  handle: Parameters<typeof createEndpoint>[0]["handle"],
  method: "GET" | "POST" = "GET",
) {
  return createEndpoint({ name: "test", method, handle });
}

function request(
  method = "GET",
  headers: Record<string, string> = {},
): Request {
  return new Request("https://example.test/functions/v1/test", { method, headers });
}

const okHandler = () => Promise.resolve(jsonResponse({ ok: true }));

Deno.test("a preflight is answered without running the handler", async () => {
  let ran = false;
  const response = await endpoint(() => {
    ran = true;
    return okHandler();
  })(request("OPTIONS"));

  assertEquals(response.status, 204);
  assertEquals(ran, false);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("the wrong method is refused before the handler runs", async () => {
  let ran = false;
  const response = await endpoint(() => {
    ran = true;
    return okHandler();
  }, "POST")(request("GET"));

  assertEquals(response.status, 400);
  assertEquals(ran, false);
  assertEquals((await response.json()).error.code, "INVALID_REQUEST");
});

Deno.test("an ApiError becomes its §31 body and status", async () => {
  const response = await endpoint(() =>
    Promise.reject(ApiError.dailyLimitReached("2026-07-27T00:00:00+03:00"))
  )(
    request(),
  );

  assertEquals(response.status, 429);
  const body = await response.json();
  assertEquals(body.error.code, "DAILY_LIMIT_REACHED");
  assertEquals(body.error.details.reset_at, "2026-07-27T00:00:00+03:00");
});

Deno.test("an unexpected throw becomes INTERNAL_ERROR and its message is discarded", async () => {
  // The message of a driver or parser exception can quote the document (§51).
  const response = await endpoint(() => {
    throw new TypeError("failed to parse: رقم الحساب 12345678");
  })(request());

  assertEquals(response.status, 500);
  const raw = await response.text();
  assertEquals(JSON.parse(raw).error.code, "INTERNAL_ERROR");
  assert(!raw.includes("12345678"), "the response must not echo the caught message");
});

Deno.test("the client's request id is echoed on success and on failure", async () => {
  const headers = { "x-request-id": CLIENT_REQUEST_ID };

  const success = await endpoint(okHandler)(request("GET", headers));
  assertEquals(success.headers.get("x-request-id"), CLIENT_REQUEST_ID);

  const failure = await endpoint(() => Promise.reject(ApiError.timeout()))(
    request("GET", headers),
  );
  assertEquals(failure.headers.get("x-request-id"), CLIENT_REQUEST_ID);
});

Deno.test("a handler that forgets the request id still gets one", async () => {
  // The id is the only way to tie a client report to a server log line.
  const response = await endpoint(() => Promise.resolve(new Response("{}", { status: 200 })))(
    request("GET", { "x-request-id": CLIENT_REQUEST_ID }),
  );

  assertEquals(response.headers.get("x-request-id"), CLIENT_REQUEST_ID);
  assertEquals(await response.json(), {});
});

Deno.test("a missing request id is generated rather than refused", async () => {
  const response = await endpoint(okHandler)(request());

  const generated = response.headers.get("x-request-id");
  assert(generated !== null && /^[0-9a-f-]{36}$/.test(generated));
});

Deno.test("responses are never cached", async () => {
  // An analysis body describes someone's bill; it must not sit in a proxy.
  const response = await endpoint(okHandler)(request());
  assertEquals(response.headers.get("Cache-Control"), "no-store");
  assertEquals(response.headers.get("X-Content-Type-Options"), "nosniff");
});
