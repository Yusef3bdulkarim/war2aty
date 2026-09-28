/**
 * F18-T03 · Groq credentials and endpoint.
 *
 * Read here, not inline in the transport, so a deploy fault is a loud startup
 * error in one place — same contract as `azureOptionsFromEnv`
 * (`../azure/azure-config.ts`) and `googleDocumentAiOptionsFromEnv`
 * (`../google/google-config.ts`).
 *
 * This module holds everything that is true of GROQ specifically. Its
 * counterpart `openai-compatible-client.ts` holds what is true of every
 * provider that speaks the OpenAI chat shape, and must never import from here
 * — the whole point of the F18 seam is that the transport does not know which
 * provider it is talking to.
 */

import type { ChatClientOptions } from "./openai-compatible-client.ts";

/** Groq's OpenAI-compatible root. `/chat/completions` is appended by the client. */
export const GROQ_BASE_URL = "https://api.groq.com/openai/v1";

/**
 * The model this service is built around, and the one `.env.example` sets.
 *
 * It MUST support `response_format: json_schema`: F06-T11 sends one on every
 * call, and a model without it answers 400. This is what the live integration
 * tests fall back to — never a fallback on the production path, which refuses
 * to guess (see {@link groqOptionsFromEnv}).
 */
export const DEFAULT_GROQ_MODEL = "openai/gpt-oss-120b";

/**
 * The `reasoning_effort` every Groq analysis call sends. It lives here rather
 * than in the provider (moved in F20-T06) because it is true of Groq's
 * reasoning models only: Mistral gets no such parameter at all.
 *
 * `openai/gpt-oss-120b` is a reasoning model: Groq counts its internal
 * chain-of-thought against `max_tokens` before it ever writes the JSON
 * answer. Measured on 2026-08-11 at the default effort, that trace alone ran
 * 1,100–1,300 tokens on an ordinary bill, leaving the actual answer only
 * 700–900 of the 2000-token budget and occasionally none at all — the
 * completion hit `finish_reason: "length"` mid-object, or the model
 * fell back to wrapping the answer in a bare array, which Groq's own strict
 * schema check then rejects with an HTTP 400. Both surfaced identically as
 * ANALYSIS_FAILED with no way to tell them apart from a real outage.
 *
 * "low" cut the trace to ~220 tokens with no loss of extraction quality in
 * the same test — this is a document-extraction task, not one that benefits
 * from deep reasoning — and left the answer a comfortable margin under the
 * cap.
 */
export const GROQ_REASONING_EFFORT = "low";

/**
 * Reads credentials from the environment the Edge Runtime injects.
 *
 * @throws if `GROQ_API_KEY` or `GROQ_MODEL` is missing. Both are deploy faults,
 * and both are fatal at startup rather than per request — see below for why the
 * model is not defaulted.
 */
export function groqOptionsFromEnv(
  environment: { get(key: string): string | undefined } = Deno.env,
): ChatClientOptions {
  // Trimmed for the same reason the model is: a var set to whitespace is a
  // truthy string, and an untrimmed key reaches the wire as `Bearer    `,
  // which 401s on every single analysis. A copy-pasted `.env` value carrying a
  // trailing newline is the ordinary way that happens.
  const apiKey = environment.get("GROQ_API_KEY")?.trim();

  if (!apiKey) {
    // A deploy fault, not a user error. Surfaced loudly here rather than as a
    // baffling 500 on every analysis.
    throw new Error("GROQ_API_KEY is not set.");
  }

  // Deliberately NOT defaulted. A model that cannot serve `json_schema` fails
  // EVERY analysis with a 400 the user only ever sees as ANALYSIS_FAILED — a
  // total outage wearing the costume of a flaky provider. Falling back would
  // hide exactly the mistake worth shouting about, so an unset model is a
  // startup error like the key above.
  //
  // Read with `.trim()` rather than `??`: an env var set to "" is a string, so
  // `??` would wave it through and send an empty model name to Groq.
  const model = environment.get("GROQ_MODEL")?.trim();

  if (!model) {
    throw new Error(
      "GROQ_MODEL is not set. It must name a model that supports " +
        "`response_format: json_schema` — see supabase/.env.example.",
    );
  }

  return { baseUrl: GROQ_BASE_URL, apiKey, model };
}

/**
 * Returns `true` when `GROQ_API_KEY` is present and non-blank.
 *
 * Checks the KEY ONLY, matching `isGeminiConfigured`. The key is how an
 * operator expresses the intent "use this provider"; the model is a
 * completeness requirement enforced loudly by {@link groqOptionsFromEnv} once
 * that intent is on record. Were this to require the model too, a deployment
 * that set the key and forgot the model would report as unconfigured and be
 * skipped in silence — which is the very failure the non-default of
 * `GROQ_MODEL` above exists to prevent.
 *
 * It does NOT soften the deploy-fault contract above: calling
 * {@link groqOptionsFromEnv} on an unconfigured deployment still throws, and
 * still should. This exists so the F18-T05 chain can ask whether a Groq leg is
 * meant to be available before it tries to build one — the same question
 * `isGoogleDocumentAiConfigured` answers for the optional OCR second opinion.
 */
export function isGroqConfigured(
  environment: { get(key: string): string | undefined } = Deno.env,
): boolean {
  const apiKey = environment.get("GROQ_API_KEY")?.trim();
  return apiKey !== undefined && apiKey.length > 0;
}
