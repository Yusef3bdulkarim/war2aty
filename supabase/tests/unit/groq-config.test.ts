/**
 * F18-T03 · Tests for the Groq config module.
 *
 * The cases in the first group moved here from `openai-compatible-client.test.ts`
 * when `groqOptionsFromEnv` moved out of the transport (F18-T03). They pass a
 * fake environment rather than mutating `Deno.env`, matching
 * `google-config.test.ts` — the old version set and restored real process env
 * vars, which is order-dependent under a parallel test runner.
 *
 * The model is the one setting that cannot be guessed: F06-T11 sends
 * `response_format: json_schema` on every call, and a model without support
 * answers 400 — which reaches the user as ANALYSIS_FAILED, indistinguishable
 * from a provider outage. These pin the "fail at startup, never fall back"
 * contract that keeps a config slip from becoming a silent total outage.
 */

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  DEFAULT_GROQ_MODEL,
  GROQ_BASE_URL,
  groqOptionsFromEnv,
  isGroqConfigured,
} from "../../functions/_shared/ai/groq-config.ts";

/** A stand-in for `Deno.env` holding exactly the values given. */
function env(values: Record<string, string>) {
  return { get: (key: string): string | undefined => values[key] };
}

const CONFIGURED = {
  GROQ_API_KEY: "test-key",
  GROQ_MODEL: "openai/gpt-oss-120b",
};

// ── the constants ─────────────────────────────────────────────────────────

Deno.test("the default model supports json_schema", () => {
  // Guards the constant itself: it is what the live integration tests fall
  // back to, so it must never drift to a model that cannot be
  // schema-constrained.
  assert(DEFAULT_GROQ_MODEL.startsWith("openai/gpt-oss-"));
});

Deno.test("the base URL is Groq's OpenAI-compatible root, with no trailing slash", () => {
  // The client appends `/chat/completions`; a trailing slash here would double
  // it and every analysis would 404.
  assertEquals(GROQ_BASE_URL, "https://api.groq.com/openai/v1");
  assert(!GROQ_BASE_URL.endsWith("/"));
});

// ── reading the environment ───────────────────────────────────────────────

Deno.test("options are read from the environment", () => {
  const options = groqOptionsFromEnv(
    25,
    env({ GROQ_API_KEY: "test-key", GROQ_MODEL: "openai/gpt-oss-20b" }),
  );

  assertEquals(options.apiKey, "test-key");
  assertEquals(options.model, "openai/gpt-oss-20b");
  assertEquals(options.timeoutSeconds, 25);
});

Deno.test("the options carry the base URL, so no caller has to know it", () => {
  // Before F18-T03 the transport hardcoded the URL and this function did not
  // return one. Now it does, which is what lets `analyze-document/index.ts`
  // hand the whole object straight to `createChatClient`.
  assertEquals(groqOptionsFromEnv(25, env(CONFIGURED)).baseUrl, GROQ_BASE_URL);
});

Deno.test("a missing api key is fatal", () => {
  assertThrows(
    () => groqOptionsFromEnv(25, env({ GROQ_MODEL: "openai/gpt-oss-120b" })),
    Error,
    "GROQ_API_KEY",
  );
});

Deno.test("a missing model is fatal rather than defaulted", () => {
  assertThrows(
    () => groqOptionsFromEnv(25, env({ GROQ_API_KEY: "test-key" })),
    Error,
    "GROQ_MODEL",
  );
});

Deno.test("a blank model is fatal too", () => {
  // `??` would have accepted "" as a set value and sent an empty model name.
  assertThrows(
    () =>
      groqOptionsFromEnv(
        25,
        env({ GROQ_API_KEY: "test-key", GROQ_MODEL: "   " }),
      ),
    Error,
    "GROQ_MODEL",
  );
});

Deno.test("a model is trimmed before use", () => {
  // A trailing newline is what a copy-pasted `.env` value actually looks like.
  const options = groqOptionsFromEnv(
    25,
    env({ GROQ_API_KEY: "test-key", GROQ_MODEL: "openai/gpt-oss-120b\n" }),
  );

  assertEquals(options.model, "openai/gpt-oss-120b");
});

// ── availability, without throwing ────────────────────────────────────────

Deno.test("a fully configured environment reports as configured", () => {
  assert(isGroqConfigured(env(CONFIGURED)));
});

Deno.test("a missing key reports as unconfigured", () => {
  assert(!isGroqConfigured(env({})));
  assert(!isGroqConfigured(env({ GROQ_MODEL: "openai/gpt-oss-120b" })));
});

Deno.test("a blank key reports as unconfigured", () => {
  // Same trap `groqOptionsFromEnv` guards: a var set to "" is still a string.
  assert(!isGroqConfigured(env({ ...CONFIGURED, GROQ_API_KEY: "" })));
  assert(!isGroqConfigured(env({ ...CONFIGURED, GROQ_API_KEY: "   " })));
});

Deno.test("a key without a model still reports as configured", () => {
  // Deliberate: the key is the operator's statement of intent, so this is
  // "Groq was meant to be used" — and `groqOptionsFromEnv` then throws on the
  // missing model. Returning false here would skip the leg in silence and hide
  // a config slip that deserves shouting about.
  assert(isGroqConfigured(env({ GROQ_API_KEY: "test-key" })));
  assertThrows(
    () => groqOptionsFromEnv(25, env({ GROQ_API_KEY: "test-key" })),
    Error,
    "GROQ_MODEL",
  );
});

Deno.test("reporting unconfigured does not soften the deploy fault", () => {
  // The two answer different questions: `isGroqConfigured` asks whether a leg
  // is available (F18-T05), `groqOptionsFromEnv` insists on being usable. An
  // unconfigured deployment must still throw rather than degrade quietly.
  const blank = env({});

  assert(!isGroqConfigured(blank));
  assertThrows(() => groqOptionsFromEnv(25, blank), Error, "GROQ_API_KEY");
});
