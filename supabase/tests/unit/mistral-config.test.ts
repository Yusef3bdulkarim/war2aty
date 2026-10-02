/**
 * F20-T06 · Tests for the Mistral config and the Mistral analysis leg.
 *
 * The config cases mirror `groq-config.test.ts`: a fake environment, never the
 * real `Deno.env`, so the order the runner picks cannot matter.
 *
 * The leg cases build the leg exactly as the endpoint will (F20-T11): the
 * shared analysis provider over the shared client, configured from
 * {@link mistralOptionsFromEnv} and nothing else. A fake `fetch` records what
 * would reach Mistral, so no test touches the network.
 */

import { assert, assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";

import {
  MISTRAL_BASE_URL,
  mistralOptionsFromEnv,
} from "../../functions/_shared/ai/mistral-config.ts";
import { createChatClient } from "../../functions/_shared/ai/openai-compatible-client.ts";
import { createAnalysisProvider } from "../../functions/_shared/ai/analysis-provider.ts";
import {
  isFallbackEligible,
  ProviderFailure,
} from "../../functions/_shared/ai/provider-failure.ts";
import { ANALYSIS_RESPONSE_FORMAT } from "../../functions/_shared/schemas/analysis-output.schema.ts";
import type { AnalysisPromptInput } from "../../functions/_shared/prompts/analysis-prompt.ts";
import { modelAnalysis, OCR_TEXT } from "../fixtures/analyze-fixtures.ts";

/** A stand-in for `Deno.env` holding exactly the values given. */
function env(values: Record<string, string>) {
  return { get: (key: string): string | undefined => values[key] };
}

const CONFIGURED = {
  MISTRAL_API_KEY: "test-key",
  MISTRAL_MODEL: "mistral-small-latest",
};

// ── the constants ─────────────────────────────────────────────────────────

Deno.test("the base URL is Mistral's API root, with no trailing slash", () => {
  // The client appends `/chat/completions`; a trailing slash would double it.
  assertEquals(MISTRAL_BASE_URL, "https://api.mistral.ai/v1");
  assert(!MISTRAL_BASE_URL.endsWith("/"));
});

// ── reading the environment ───────────────────────────────────────────────

Deno.test("options are read from the environment, with the base URL", () => {
  assertEquals(mistralOptionsFromEnv(env(CONFIGURED)), {
    baseUrl: MISTRAL_BASE_URL,
    apiKey: "test-key",
    model: "mistral-small-latest",
  });
});

Deno.test("a missing api key is fatal", () => {
  assertThrows(
    () => mistralOptionsFromEnv(env({ MISTRAL_MODEL: "mistral-small-latest" })),
    Error,
    "MISTRAL_API_KEY",
  );
});

Deno.test("a blank api key is fatal", () => {
  // Untrimmed, it would reach the wire as `Bearer    ` and 401 every analysis.
  assertThrows(
    () => mistralOptionsFromEnv(env({ ...CONFIGURED, MISTRAL_API_KEY: "  \n" })),
    Error,
    "MISTRAL_API_KEY",
  );
});

Deno.test("an api key is trimmed before use", () => {
  const options = mistralOptionsFromEnv(env({ ...CONFIGURED, MISTRAL_API_KEY: "mk_test\n" }));

  assertEquals(options.apiKey, "mk_test");
});

Deno.test("a missing model is fatal rather than defaulted", () => {
  assertThrows(
    () => mistralOptionsFromEnv(env({ MISTRAL_API_KEY: "test-key" })),
    Error,
    "MISTRAL_MODEL",
  );
});

Deno.test("a blank model is fatal too", () => {
  // `??` would have accepted "" as a set value and sent an empty model name.
  assertThrows(
    () => mistralOptionsFromEnv(env({ ...CONFIGURED, MISTRAL_MODEL: "   " })),
    Error,
    "MISTRAL_MODEL",
  );
});

Deno.test("a model is trimmed before use", () => {
  const options = mistralOptionsFromEnv(
    env({ ...CONFIGURED, MISTRAL_MODEL: "mistral-small-latest\n" }),
  );

  assertEquals(options.model, "mistral-small-latest");
});

Deno.test("the error names the variable, never its value", () => {
  // A deploy log may be read by more people than the secret store.
  const error = assertThrows(
    () => mistralOptionsFromEnv(env({ MISTRAL_API_KEY: "mk_secret_value" })),
    Error,
  );

  assert(!error.message.includes("mk_secret_value"));
});

// ── the Mistral leg ───────────────────────────────────────────────────────

const INPUT: AnalysisPromptInput = {
  ocrText: OCR_TEXT,
  detectedLanguages: ["ar"],
  candidates: { dates: [], times: [], amounts: [], phones: [], references: [] },
};

const OPEN_SIGNAL = new AbortController().signal;

interface Recorded {
  url: string;
  headers: Headers;
  body: Record<string, unknown>;
}

/** The leg as the endpoint will build it, over a fake `fetch` answering `content`. */
function mistralLeg(content: unknown) {
  const calls: Recorded[] = [];
  const fetchImpl: typeof fetch = (input, init) => {
    calls.push({
      url: String(input),
      headers: new Headers(init?.headers),
      body: JSON.parse(String(init?.body)),
    });
    return Promise.resolve(
      new Response(
        JSON.stringify({
          model: "mistral-small-2506",
          choices: [{ message: { content: JSON.stringify(content) }, finish_reason: "stop" }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
  };

  const leg = createAnalysisProvider({
    client: createChatClient({ ...mistralOptionsFromEnv(env(CONFIGURED)), fetchImpl }),
  });
  return { leg, calls };
}

Deno.test("the leg calls Mistral's chat completions with the configured key", async () => {
  const { leg, calls } = mistralLeg(modelAnalysis());

  await leg(INPUT, OPEN_SIGNAL);

  assertEquals(calls.length, 1);
  assertEquals(calls[0].url, "https://api.mistral.ai/v1/chat/completions");
  assertEquals(calls[0].headers.get("Authorization"), "Bearer test-key");
  assertEquals(calls[0].body.model, "mistral-small-latest");
});

Deno.test("the leg sends a strict json_schema, temperature 0 and max_tokens 2000", async () => {
  const { leg, calls } = mistralLeg(modelAnalysis());

  await leg(INPUT, OPEN_SIGNAL);

  const body = calls[0].body;
  assertEquals(body.response_format, JSON.parse(JSON.stringify(ANALYSIS_RESPONSE_FORMAT)));
  assertEquals((body.response_format as typeof ANALYSIS_RESPONSE_FORMAT).json_schema.strict, true);
  assertEquals(body.temperature, 0);
  assertEquals(body.max_tokens, 2000);
});

Deno.test("the leg sends no reasoning_effort", async () => {
  // Groq's setting; Mistral is not a reasoning model and is never sent it.
  const { leg, calls } = mistralLeg(modelAnalysis());

  await leg(INPUT, OPEN_SIGNAL);

  assert(!("reasoning_effort" in calls[0].body));
});

Deno.test("a valid answer comes back from the leg", async () => {
  const { leg } = mistralLeg(modelAnalysis());

  const result = await leg(INPUT, OPEN_SIGNAL);

  assertEquals(result, modelAnalysis());
});

Deno.test("a wrong-shaped answer is invalid_output (assertModelAnalysis)", async () => {
  const { leg } = mistralLeg({ status: "success" });

  const thrown = await assertRejects(() => leg(INPUT, OPEN_SIGNAL), ProviderFailure);

  assertEquals((thrown as ProviderFailure).kind, "invalid_output");
});

Deno.test("a semantically invalid answer is invalid_output and may fall back to Groq", async () => {
  // Well-shaped, so it passes `assertModelAnalysis`; blank summary, so S1 fails.
  const base = modelAnalysis();
  const { leg } = mistralLeg({ ...base, summary: { ...base.summary, detailed: " " } });

  const thrown = await assertRejects(() => leg(INPUT, OPEN_SIGNAL), ProviderFailure);

  assertEquals((thrown as ProviderFailure).kind, "invalid_output");
  assert(isFallbackEligible((thrown as ProviderFailure).kind));
});
