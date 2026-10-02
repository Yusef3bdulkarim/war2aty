/**
 * F20-T07 · Tests for Gemini env-var reading (the OCR provider).
 *
 * A fake environment is passed in, so these never touch the real one and never
 * need a key.
 */

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import { GEMINI_BASE_URL, geminiOptionsFromEnv } from "../../functions/_shared/ai/gemini-config.ts";

/** Stands in for Deno.env so tests never touch the real environment. */
function env(values: Record<string, string> = {}) {
  return { get: (key: string): string | undefined => values[key] };
}

const CONFIGURED = {
  GEMINI_API_KEY: "test-key",
  GEMINI_MODEL: "gemini-3.1-flash-lite",
};

// ── the constant ──────────────────────────────────────────────────────────

Deno.test("the base URL is Gemini's native v1beta root, not the OpenAI-compatible one", () => {
  // The OCR client appends `/models/{model}:generateContent`, which exists
  // only on the native API.
  assertEquals(GEMINI_BASE_URL, "https://generativelanguage.googleapis.com/v1beta");
  assert(!GEMINI_BASE_URL.endsWith("/"));
  assert(!GEMINI_BASE_URL.includes("openai"));
});

// ── reading the environment ───────────────────────────────────────────────

Deno.test("options are read from the environment, with the base URL", () => {
  assertEquals(geminiOptionsFromEnv(env(CONFIGURED)), {
    baseUrl: GEMINI_BASE_URL,
    apiKey: "test-key",
    model: "gemini-3.1-flash-lite",
  });
});

Deno.test("a missing api key is fatal", () => {
  assertThrows(
    () => geminiOptionsFromEnv(env({ GEMINI_MODEL: "gemini-3.1-flash-lite" })),
    Error,
    "GEMINI_API_KEY",
  );
});

Deno.test("a blank api key is fatal", () => {
  assertThrows(
    () => geminiOptionsFromEnv(env({ ...CONFIGURED, GEMINI_API_KEY: "   " })),
    Error,
    "GEMINI_API_KEY",
  );
});

Deno.test("a missing model is fatal rather than defaulted (D1)", () => {
  assertThrows(
    () => geminiOptionsFromEnv(env({ GEMINI_API_KEY: "test-key" })),
    Error,
    "GEMINI_MODEL",
  );
});

Deno.test("a blank model is fatal too", () => {
  // `??` would have accepted "" and put an empty model name in the URL.
  assertThrows(
    () => geminiOptionsFromEnv(env({ ...CONFIGURED, GEMINI_MODEL: "  " })),
    Error,
    "GEMINI_MODEL",
  );
});

Deno.test("the key and model are trimmed before use", () => {
  // A trailing newline is what a copy-pasted `.env` value actually looks like.
  const options = geminiOptionsFromEnv(
    env({ GEMINI_API_KEY: "test-key\n", GEMINI_MODEL: " gemini-3.1-flash-lite\n" }),
  );

  assertEquals(options.apiKey, "test-key");
  assertEquals(options.model, "gemini-3.1-flash-lite");
});

Deno.test("nothing set hard-fails on the key first", () => {
  assertThrows(() => geminiOptionsFromEnv(env()), Error, "GEMINI_API_KEY");
});

Deno.test("the error names the variable, never its value", () => {
  const error = assertThrows(
    () => geminiOptionsFromEnv(env({ GEMINI_API_KEY: "AIza_secret_value" })),
    Error,
  );

  assert(!error.message.includes("AIza_secret_value"));
});
