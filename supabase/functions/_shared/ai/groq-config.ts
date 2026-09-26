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
 * Reads credentials from the environment the Edge Runtime injects.
 *
 * @throws if `GROQ_API_KEY` or `GROQ_MODEL` is missing. Both are deploy faults,
 * and both are fatal at startup rather than per request — see below for why the
 * model is not defaulted.
 */
export function groqOptionsFromEnv(
  timeoutSeconds: number,
  environment: { get(key: string): string | undefined } = Deno.env,
): ChatClientOptions {
  const apiKey = environment.get("GROQ_API_KEY");

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

  return { baseUrl: GROQ_BASE_URL, apiKey, model, timeoutSeconds };
}

/**
 * Returns `true` when both Groq env vars are present and non-blank.
 *
 * This does NOT soften the deploy-fault contract above: calling
 * {@link groqOptionsFromEnv} on an unconfigured deployment still throws, and
 * still should. It exists so the F18-T05 chain can ask whether a Groq leg is
 * available at all before it tries to build one — the same question
 * `isGoogleDocumentAiConfigured` answers for the optional OCR second opinion.
 */
export function isGroqConfigured(
  environment: { get(key: string): string | undefined } = Deno.env,
): boolean {
  return ["GROQ_API_KEY", "GROQ_MODEL"].every((key) => {
    const value = environment.get(key)?.trim();
    return value !== undefined && value.length > 0;
  });
}
