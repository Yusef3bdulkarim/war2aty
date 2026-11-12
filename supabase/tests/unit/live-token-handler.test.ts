/**
 * F37-T10 · Tests for the live-token endpoint.
 *
 * Every test injects a fake token minter rather than calling Google, so the
 * suite stays fast, free, and deterministic. The minter is the one seam — it
 * either succeeds with a canned token or fails with a classified reason.
 */

import { assertEquals } from "jsr:@std/assert@1";

import type { AuthenticatedUser } from "../../functions/_shared/auth/require-user.ts";
import type { RuntimeConfig } from "../../functions/_shared/config/runtime-config.ts";
import { createEndpoint } from "../../functions/_shared/http/endpoint.ts";
import type { MintResult } from "../../functions/_shared/live/gemini-token-client.ts";
import { createLiveTokenHandler } from "../../functions/_shared/live/live-token-handler.ts";
import { testConfig, USER_ID } from "../fixtures/analyze-fixtures.ts";

const VALID_TOKEN = "valid-token";
const MODEL = "gemini-2.5-flash-native-audio-latest";
const API_VERSION = "v1beta";
const API_KEY = "test-api-key";

const MINTED: MintResult = {
  ok: true,
  token: {
    wsUrl:
      "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?access_token=ephemeral-123",
    model: `models/${MODEL}`,
    expiresAt: "2026-11-13T10:30:00.000Z",
  },
};

interface HarnessOptions {
  readonly config?: Partial<RuntimeConfig>;
  readonly mintResult?: MintResult;
}

function harness(options: HarnessOptions = {}) {
  const mintCalls: { apiKey: string; model: string; apiVersion?: string }[] = [];

  const handler = createEndpoint({
    name: "live-token",
    method: "POST",
    handle: createLiveTokenHandler({
      verifyToken: (token: string): Promise<AuthenticatedUser | null> =>
        Promise.resolve(
          token === VALID_TOKEN ? { id: USER_ID, isAnonymous: true } : null,
        ),
      loadConfig: () =>
        Promise.resolve(
          testConfig({ explainEnabled: true, ...options.config }),
        ),
      mintToken: ({ apiKey, model, apiVersion }) => {
        mintCalls.push({ apiKey, model, apiVersion });
        return Promise.resolve(options.mintResult ?? MINTED);
      },
      geminiApiKey: API_KEY,
      geminiModel: MODEL,
      geminiApiVersion: API_VERSION,
    }),
  });

  return {
    mintCalls,
    call: (headers: Record<string, string> = {}) =>
      handler(
        new Request("https://example.test/functions/v1/live-token", {
          method: "POST",
          headers: { Authorization: `Bearer ${VALID_TOKEN}`, ...headers },
        }),
      ),
  };
}

// ── success ─────────────────────────────────────────────────────────────────

Deno.test("a successful mint returns the WebSocket URL and model", async () => {
  const response = await harness().call();

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.ws_url, (MINTED as { ok: true; token: { wsUrl: string } }).token.wsUrl);
  assertEquals(body.model, `models/${MODEL}`);
  assertEquals(body.expires_at, "2026-11-13T10:30:00.000Z");
});

Deno.test("the response shape has exactly three fields", async () => {
  const body = await (await harness().call()).json();
  assertEquals(Object.keys(body).sort(), ["expires_at", "model", "ws_url"]);
});

Deno.test("the minter receives the configured credentials", async () => {
  const test = harness();
  await test.call();

  assertEquals(test.mintCalls, [{
    apiKey: API_KEY,
    model: MODEL,
    apiVersion: API_VERSION,
  }]);
});

// ── auth gate ───────────────────────────────────────────────────────────────

Deno.test("an unauthenticated caller gets 401 and no mint is attempted", async () => {
  const test = harness();
  const response = await test.call({ Authorization: "" });

  assertEquals(response.status, 401);
  assertEquals((await response.json()).error.code, "UNAUTHORIZED");
  assertEquals(test.mintCalls.length, 0);
});

Deno.test("an invalid token gets 401", async () => {
  const test = harness();
  const response = await test.call({ Authorization: "Bearer bad-token" });

  assertEquals(response.status, 401);
  assertEquals((await response.json()).error.code, "UNAUTHORIZED");
  assertEquals(test.mintCalls.length, 0);
});

// ── service gates ───────────────────────────────────────────────────────────

Deno.test("the kill switch refuses with 503 and no mint is attempted", async () => {
  const test = harness({ config: { analysisEnabled: false } });
  const response = await test.call();

  assertEquals(response.status, 503);
  assertEquals((await response.json()).error.code, "ANALYSIS_DISABLED");
  assertEquals(test.mintCalls.length, 0);
});

Deno.test("explainEnabled=false refuses with 503 and no mint is attempted", async () => {
  const test = harness({ config: { explainEnabled: false } });
  const response = await test.call();

  assertEquals(response.status, 503);
  assertEquals((await response.json()).error.code, "ANALYSIS_DISABLED");
  assertEquals(test.mintCalls.length, 0);
});

Deno.test(
  "both gates must be on — analysisEnabled alone is not enough",
  async () => {
    const response = await harness({
      config: { analysisEnabled: true, explainEnabled: false },
    }).call();

    assertEquals(response.status, 503);
  },
);

// ── mint failures ───────────────────────────────────────────────────────────

Deno.test("a rate-limited mint returns 429 AI_RATE_LIMITED", async () => {
  const response = await harness({
    mintResult: { ok: false, reason: "rate_limited" },
  }).call();

  assertEquals(response.status, 429);
  assertEquals((await response.json()).error.code, "AI_RATE_LIMITED");
});

Deno.test("an unavailable token service returns 500 INTERNAL_ERROR", async () => {
  const response = await harness({
    mintResult: { ok: false, reason: "not_available" },
  }).call();

  assertEquals(response.status, 500);
  assertEquals((await response.json()).error.code, "INTERNAL_ERROR");
});

Deno.test("an internal mint failure returns 500 INTERNAL_ERROR", async () => {
  const response = await harness({
    mintResult: { ok: false, reason: "internal" },
  }).call();

  assertEquals(response.status, 500);
  assertEquals((await response.json()).error.code, "INTERNAL_ERROR");
});

// ── method check ────────────────────────────────────────────────────────────

Deno.test("GET is refused — live-token is POST only", async () => {
  const handler = createEndpoint({
    name: "live-token",
    method: "POST",
    handle: createLiveTokenHandler({
      verifyToken: () => Promise.resolve({ id: USER_ID, isAnonymous: true }),
      loadConfig: () => Promise.resolve(testConfig({ explainEnabled: true })),
      mintToken: () => Promise.resolve(MINTED),
      geminiApiKey: API_KEY,
      geminiModel: MODEL,
      geminiApiVersion: API_VERSION,
    }),
  });

  const response = await handler(
    new Request("https://example.test/functions/v1/live-token", {
      method: "GET",
      headers: { Authorization: `Bearer ${VALID_TOKEN}` },
    }),
  );

  assertEquals(response.status, 400);
});

// ── ordering ────────────────────────────────────────────────────────────────

Deno.test("auth is checked before the config is loaded", async () => {
  let configLoaded = false;
  const handler = createEndpoint({
    name: "live-token",
    method: "POST",
    handle: createLiveTokenHandler({
      verifyToken: () => Promise.resolve(null),
      loadConfig: () => {
        configLoaded = true;
        return Promise.resolve(testConfig({ explainEnabled: true }));
      },
      mintToken: () => Promise.resolve(MINTED),
      geminiApiKey: API_KEY,
      geminiModel: MODEL,
      geminiApiVersion: API_VERSION,
    }),
  });

  await handler(
    new Request("https://example.test/functions/v1/live-token", {
      method: "POST",
      headers: { Authorization: "Bearer bad" },
    }),
  );

  assertEquals(configLoaded, false);
});

Deno.test("the gates are checked before the mint is attempted", async () => {
  const test = harness({ config: { analysisEnabled: false } });
  await test.call();
  assertEquals(test.mintCalls.length, 0);
});
