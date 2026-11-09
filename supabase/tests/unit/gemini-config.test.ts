/**
 * F20-T07 · Tests for Gemini env-var reading (the OCR provider).
 *
 * A fake environment is passed in, so these never touch the real one and never
 * need a key.
 */

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  GEMINI_BASE_URL,
  geminiOptionsFromEnv,
  geminiReadingOptionsFromEnv,
  MAX_READING_MODELS,
} from "../../functions/_shared/ai/gemini-config.ts";

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

// ── the reading chain's ids (F36-T08) ─────────────────────────────────────

const READING = {
  GEMINI_API_KEY: "test-key",
  GEMINI_OCR_MODELS: "gemini-3.5-flash-lite,gemini-3.1-flash-lite,gemini-3.5-flash",
};

Deno.test("three ids are read in the order written, with the shared credentials", () => {
  assertEquals(geminiReadingOptionsFromEnv(env(READING)), {
    gemini: { baseUrl: GEMINI_BASE_URL, apiKey: "test-key" },
    models: ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite", "gemini-3.5-flash"],
  });
});

Deno.test("the credentials carry no model: the ids are the chain's, not the key's", () => {
  const { gemini } = geminiReadingOptionsFromEnv(env(READING));

  assert(!("model" in gemini));
});

Deno.test("one id is a legal chain", () => {
  const { models } = geminiReadingOptionsFromEnv(
    env({ ...READING, GEMINI_OCR_MODELS: "gemini-3.5-flash-lite" }),
  );

  assertEquals(models, ["gemini-3.5-flash-lite"]);
});

Deno.test("a missing list is fatal rather than defaulted (D1)", () => {
  // A hardcoded id would answer 404 on every photo once Google retires it,
  // which never fails over: a config slip would become a total outage.
  assertThrows(
    () => geminiReadingOptionsFromEnv(env({ GEMINI_API_KEY: "test-key" })),
    Error,
    "GEMINI_OCR_MODELS",
  );
});

Deno.test("a blank list, or one of only separators, names no id and is fatal", () => {
  for (const blank of ["", "   ", ",", " , ,, "]) {
    assertThrows(
      () => geminiReadingOptionsFromEnv(env({ ...READING, GEMINI_OCR_MODELS: blank })),
      Error,
      "GEMINI_OCR_MODELS",
    );
  }
});

Deno.test("GEMINI_MODEL is not consulted: the single-model variable is ocr-document's", () => {
  // Setting it must neither satisfy a missing list nor change a present one.
  assertThrows(
    () => geminiReadingOptionsFromEnv(env({ ...CONFIGURED })),
    Error,
    "GEMINI_OCR_MODELS",
  );
  assertEquals(
    geminiReadingOptionsFromEnv(env({ ...READING, GEMINI_MODEL: "gemini-other" })).models.length,
    3,
  );
});

Deno.test("whitespace around ids, a trailing newline and a trailing comma are cleaned", () => {
  const { models } = geminiReadingOptionsFromEnv(
    env({
      ...READING,
      GEMINI_OCR_MODELS: " gemini-3.5-flash-lite ,\tgemini-3.1-flash-lite,\n",
    }),
  );

  assertEquals(models, ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite"]);
});

Deno.test("a repeated id keeps its first position and is not a second leg", () => {
  // Two legs on one id share a bucket: the second would only repeat the 429
  // the first just earned.
  const { models } = geminiReadingOptionsFromEnv(
    env({
      ...READING,
      GEMINI_OCR_MODELS: "gemini-3.5-flash-lite,gemini-3.1-flash-lite,gemini-3.5-flash-lite",
    }),
  );

  assertEquals(models, ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite"]);
});

Deno.test("duplicates are counted after de-duplication, not before", () => {
  // Four entries, three distinct: within the chain's limit.
  const { models } = geminiReadingOptionsFromEnv(
    env({
      ...READING,
      GEMINI_OCR_MODELS: "a,b,a,c",
    }),
  );

  assertEquals(models, ["a", "b", "c"]);
});

Deno.test("a fourth distinct id is refused, not truncated", () => {
  // Dropping the tail would run a different chain from the one written.
  assertEquals(MAX_READING_MODELS, 3);
  assertThrows(
    () => geminiReadingOptionsFromEnv(env({ ...READING, GEMINI_OCR_MODELS: "a,b,c,d" })),
    Error,
    "GEMINI_OCR_MODELS",
  );
});

Deno.test("the reading reader needs the key too, and fails on it first", () => {
  assertThrows(() => geminiReadingOptionsFromEnv(env()), Error, "GEMINI_API_KEY");
  assertThrows(
    () => geminiReadingOptionsFromEnv(env({ ...READING, GEMINI_API_KEY: "  " })),
    Error,
    "GEMINI_API_KEY",
  );
});

Deno.test("the reading reader's errors name the variable, never a value", () => {
  const error = assertThrows(
    () =>
      geminiReadingOptionsFromEnv(
        env({ GEMINI_API_KEY: "AIza_secret_value", GEMINI_OCR_MODELS: "a,b,c,d" }),
      ),
    Error,
  );

  assert(!error.message.includes("AIza_secret_value"));
  assert(!error.message.includes("a,b,c,d"));
});
