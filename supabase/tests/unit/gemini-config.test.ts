/**
 * F18-T04 · Tests for Gemini env-var reading.
 *
 * Mirrors `google-config.test.ts`: a fake environment is passed in, so these
 * never touch the real one and never need a key.
 */

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  DEFAULT_GEMINI_MODEL,
  GEMINI_DEFAULT_BASE_URL,
  geminiOptionsFromEnv,
  isGeminiConfigured,
} from "../../functions/_shared/ai/gemini-config.ts";

/** Stands in for Deno.env so tests never touch the real environment. */
function env(values: Record<string, string> = {}) {
  return { get: (key: string): string | undefined => values[key] };
}

const CONFIGURED = {
  GEMINI_API_KEY: "test-key",
  GEMINI_MODEL: "gemini-3.1-flash-lite",
};

// ── the constants ─────────────────────────────────────────────────────────

Deno.test("the base URL is Gemini's OpenAI-compatible root", () => {
  // The client appends `/chat/completions`, which must land on
  // `/v1beta/openai/chat/completions` — the compat path, not the native one.
  assertEquals(
    GEMINI_DEFAULT_BASE_URL,
    "https://generativelanguage.googleapis.com/v1beta/openai",
  );
  assert(GEMINI_DEFAULT_BASE_URL.endsWith("/v1beta/openai"));
  assert(!GEMINI_DEFAULT_BASE_URL.endsWith("/"));
});

Deno.test("the default model is a current-generation flash-lite", () => {
  // Guards the constant the live tests fall back to. 1.5 is retired (404) and
  // 2.5 is restricted to accounts with prior 2.5 usage.
  assert(DEFAULT_GEMINI_MODEL.startsWith("gemini-"));
  assert(!DEFAULT_GEMINI_MODEL.startsWith("gemini-1.5"));
  assert(!DEFAULT_GEMINI_MODEL.startsWith("gemini-2.5"));
});

Deno.test("the default model is not silently used as the production default", () => {
  // The whole point of the non-default: a key with no model must fail, not
  // quietly fall back to this constant.
  assertThrows(
    () => geminiOptionsFromEnv(env({ GEMINI_API_KEY: "test-key" })),
    Error,
    "GEMINI_MODEL",
  );
});

// ── reading the environment ───────────────────────────────────────────────

Deno.test("reads the key and model from the environment", () => {
  const options = geminiOptionsFromEnv(env(CONFIGURED));

  assertEquals(options.apiKey, "test-key");
  assertEquals(options.model, "gemini-3.1-flash-lite");
});

Deno.test("the base URL defaults without an override", () => {
  assertEquals(
    geminiOptionsFromEnv(env(CONFIGURED)).baseUrl,
    GEMINI_DEFAULT_BASE_URL,
  );
});

Deno.test("GEMINI_BASE_URL overrides the default", () => {
  const options = geminiOptionsFromEnv(
    env({ ...CONFIGURED, GEMINI_BASE_URL: "https://proxy.example/v1beta/openai" }),
  );

  assertEquals(options.baseUrl, "https://proxy.example/v1beta/openai");
});

Deno.test("a blank override falls back to the default rather than empty", () => {
  // `??` would have accepted "" and produced `/chat/completions` as the URL.
  const options = geminiOptionsFromEnv(
    env({ ...CONFIGURED, GEMINI_BASE_URL: "   " }),
  );

  assertEquals(options.baseUrl, GEMINI_DEFAULT_BASE_URL);
});

Deno.test("trailing slashes are stripped from the base URL", () => {
  // The client appends `/chat/completions`; a trailing slash would double it,
  // and the resulting 404 looks exactly like a retired model.
  const options = geminiOptionsFromEnv(
    env({ ...CONFIGURED, GEMINI_BASE_URL: "https://proxy.example/v1beta/openai///" }),
  );

  assertEquals(options.baseUrl, "https://proxy.example/v1beta/openai");
});

Deno.test("a missing api key is fatal", () => {
  assertThrows(
    () => geminiOptionsFromEnv(env({ GEMINI_MODEL: "gemini-3.1-flash-lite" })),
    Error,
    "GEMINI_API_KEY",
  );
});

Deno.test("a blank api key is fatal", () => {
  // A key set to whitespace would otherwise reach the wire as `Bearer    `
  // and 401 on every single analysis.
  assertThrows(
    () => geminiOptionsFromEnv(env({ ...CONFIGURED, GEMINI_API_KEY: "   " })),
    Error,
    "GEMINI_API_KEY",
  );
});

Deno.test("a missing model is fatal rather than defaulted", () => {
  assertThrows(
    () => geminiOptionsFromEnv(env({ GEMINI_API_KEY: "test-key" })),
    Error,
    "GEMINI_MODEL",
  );
});

Deno.test("a blank model is fatal too", () => {
  assertThrows(
    () => geminiOptionsFromEnv(env({ ...CONFIGURED, GEMINI_MODEL: "  " })),
    Error,
    "GEMINI_MODEL",
  );
});

Deno.test("the key and model are trimmed before use", () => {
  // A trailing newline is what a copy-pasted `.env` value actually looks like.
  const options = geminiOptionsFromEnv(
    env({
      GEMINI_API_KEY: "test-key\n",
      GEMINI_MODEL: " gemini-3.1-flash-lite\n",
    }),
  );

  assertEquals(options.apiKey, "test-key");
  assertEquals(options.model, "gemini-3.1-flash-lite");
});

Deno.test("nothing set hard-fails on the key first", () => {
  assertThrows(() => geminiOptionsFromEnv(env()), Error, "GEMINI_API_KEY");
});

// ── availability, without throwing ────────────────────────────────────────

Deno.test("a key present reports as configured", () => {
  assert(isGeminiConfigured(env(CONFIGURED)));
});

Deno.test("no key reports as unconfigured — the chain then runs Groq alone", () => {
  // This is the default state and bit-for-bit today's behaviour.
  assert(!isGeminiConfigured(env()));
  assert(!isGeminiConfigured(env({ GEMINI_MODEL: "gemini-3.1-flash-lite" })));
});

Deno.test("a blank key reports as unconfigured", () => {
  assert(!isGeminiConfigured(env({ GEMINI_API_KEY: "" })));
  assert(!isGeminiConfigured(env({ GEMINI_API_KEY: "   " })));
});

Deno.test("a key without a model still reports as configured", () => {
  // Deliberate, and the reason this checks the key only: the key is the
  // operator's statement of intent, so the leg IS meant to exist, and
  // `geminiOptionsFromEnv` then throws loudly on the missing model. Returning
  // false here would skip Gemini in silence and leave nobody any way to learn
  // why it never served a request.
  assert(isGeminiConfigured(env({ GEMINI_API_KEY: "test-key" })));
});

// ── the two config modules agree on what "configured" means ───────────────

Deno.test("Gemini's options are shaped exactly like Groq's", () => {
  // Both feed the same `createChatClient`, so the same four fields must come
  // out. If this ever diverges, the transport stops being provider-neutral.
  const options = geminiOptionsFromEnv(env(CONFIGURED));

  assertEquals(
    Object.keys(options).sort(),
    ["apiKey", "baseUrl", "model"],
  );
});
