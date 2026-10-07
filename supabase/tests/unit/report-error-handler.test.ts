/**
 * F27-T12 · Tests for the report-error endpoint, end to end with fakes.
 *
 * Same discipline as the other handler tests: every dependency injected, the
 * real `createEndpoint` wrapper around it, no Docker and no network. What
 * matters here is that the endpoint cannot be used for anything other than
 * what it is for — it writes under the caller's own verified identity, it
 * stores nothing it did not recognise, and it never answers in a way that
 * invites the client to retry.
 */

import { assertEquals, assertObjectMatch } from "jsr:@std/assert@1";

import type { AuthenticatedUser } from "../../functions/_shared/auth/require-user.ts";
import { createEndpoint } from "../../functions/_shared/http/endpoint.ts";
import {
  createReportErrorHandler,
  type ErrorReportInput,
  type RecordOutcome,
} from "../../functions/_shared/reports/report-error-handler.ts";

const VALID_TOKEN = "valid-token";
const USER_ID = "33333333-3333-4333-8333-333333333333";
const REQUEST_ID = "11111111-1111-4111-8111-111111111111";

interface Harness {
  readonly call: (
    body?: unknown,
    headers?: Record<string, string>,
  ) => Promise<Response>;
  readonly recorded: ErrorReportInput[];
}

function harness(
  options: { outcome?: RecordOutcome; record?: () => Promise<RecordOutcome> } = {},
): Harness {
  const recorded: ErrorReportInput[] = [];

  const handler = createEndpoint({
    name: "report-error",
    method: "POST",
    handle: createReportErrorHandler({
      verifyToken: (token: string): Promise<AuthenticatedUser | null> =>
        Promise.resolve(
          token === VALID_TOKEN ? { id: USER_ID, isAnonymous: true } : null,
        ),
      record: options.record ?? ((input) => {
        recorded.push(input);
        return Promise.resolve(options.outcome ?? "recorded");
      }),
    }),
  });

  return {
    call: (body: unknown = { error_code: "OCR" }, headers = {}) =>
      handler(
        new Request("https://example.test/functions/v1/report-error", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${VALID_TOKEN}`,
            "Content-Type": "application/json",
            "x-request-id": REQUEST_ID,
            ...headers,
          },
          body: typeof body === "string" ? body : JSON.stringify(body),
        }),
      ),
    recorded,
  };
}

async function errorCode(response: Response): Promise<string> {
  return (await response.json()).error.code;
}

/** Runs `fn` with `console.log` captured, returning every structured line. */
async function capturingLogs(
  fn: () => Promise<unknown>,
): Promise<Record<string, unknown>[]> {
  const original = console.log;
  const lines: string[] = [];
  console.log = (line: unknown) => lines.push(String(line));
  try {
    await fn();
  } finally {
    console.log = original;
  }
  return lines.map((line) => JSON.parse(line) as Record<string, unknown>);
}

Deno.test("records a report and answers 202", async () => {
  const { call, recorded } = harness();

  const response = await call({
    error_code: "OCR",
    stage: "ocr",
    app_version: "1.0.0",
  });

  assertEquals(response.status, 202);
  assertEquals(await response.text(), "", "202 carries no body");
  assertEquals(recorded.length, 1);
  assertObjectMatch(recorded[0], {
    userId: USER_ID,
    errorCode: "OCR",
    stage: "ocr",
    appVersion: "1.0.0",
  });
});

Deno.test("attributes the report to the verified token, not the body", async () => {
  // There is no `user_id` field to spoof — it would be refused as an unknown
  // field — but the test states the rule the handler is written to keep.
  const { call, recorded } = harness();

  await call({ error_code: "OCR" });

  assertEquals(recorded[0].userId, USER_ID);
});

Deno.test("rejects an unauthenticated caller", async () => {
  const { call, recorded } = harness();

  const missing = await call({ error_code: "OCR" }, { Authorization: "" });
  assertEquals(missing.status, 401);
  assertEquals(await errorCode(missing), "UNAUTHORIZED");

  const bad = await call({ error_code: "OCR" }, { Authorization: "Bearer nope" });
  assertEquals(bad.status, 401);

  assertEquals(recorded, [], "nothing was written for either call");
});

Deno.test("rejects a GET", async () => {
  const handler = createEndpoint({
    name: "report-error",
    method: "POST",
    handle: createReportErrorHandler({
      verifyToken: () => Promise.resolve({ id: USER_ID, isAnonymous: true }),
      record: () => Promise.resolve("recorded"),
    }),
  });

  const response = await handler(
    new Request("https://example.test/functions/v1/report-error", {
      method: "GET",
    }),
  );

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
});

Deno.test("rejects an unparseable body without storing anything", async () => {
  const { call, recorded } = harness();

  const response = await call("{not json");

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
  assertEquals(recorded, []);
});

Deno.test("rejects an unlisted code without storing anything", async () => {
  const { call, recorded } = harness();

  const response = await call({ error_code: "WHATEVER_I_LIKE" });

  assertEquals(response.status, 400);
  assertEquals(await errorCode(response), "INVALID_REQUEST");
  assertEquals(recorded, [], "an unrecognised code never reaches the table");
});

Deno.test("still answers 202 when the store drops the report", async () => {
  // Past the per-user ceiling. The client is not misbehaving and has nothing
  // to do differently; a 429 would only teach the sink to retry.
  const { call } = harness({ outcome: "rate_limited" });

  const response = await call({ error_code: "OCR" });

  assertEquals(response.status, 202);
});

Deno.test("a store failure surfaces as INTERNAL_ERROR", async () => {
  const { call } = harness({
    record: () => Promise.reject(new Error("db exploded: user 42 row …")),
  });

  const response = await call({ error_code: "OCR" });

  assertEquals(response.status, 500);
  assertEquals(await errorCode(response), "INTERNAL_ERROR");

  const body = await harness({
    record: () => Promise.reject(new Error("db exploded: user 42 row …")),
  }).call({ error_code: "OCR" }).then((r) => r.json());

  assertEquals(
    String(body.error.message).includes("db exploded"),
    false,
    "the driver message is discarded, never forwarded",
  );
});

Deno.test("logs the outcome and the code, and no content", async () => {
  const { call } = harness({ outcome: "rate_limited" });

  const lines = await capturingLogs(() =>
    call({ error_code: "LOCAL_DATABASE", stage: "save", app_version: "1.2.3" })
  );

  const report = lines.find((line) => line.event === "error_report");
  assertObjectMatch(report!, {
    event: "error_report",
    request_id: REQUEST_ID,
    outcome: "rate_limited",
    client_error_code: "LOCAL_DATABASE",
    stage: "save",
    app_version: "1.2.3",
  });

  // Only the envelope — the fields are ours, closed, and content-free (§51).
  assertEquals(
    Object.keys(report!).sort(),
    [
      "app_version",
      "client_error_code",
      "event",
      "outcome",
      "request_id",
      "stage",
    ],
  );
});

Deno.test("echoes the correlation id", async () => {
  const { call } = harness();

  const response = await call({ error_code: "OCR" });

  assertEquals(response.headers.get("x-request-id"), REQUEST_ID);
});
