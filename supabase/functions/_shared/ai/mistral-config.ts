/**
 * F20-T06 · Mistral credentials and endpoint.
 *
 * Mistral is the analysis primary (F20 §1, layer 2), with Groq as its
 * fallback. Read here, not inline in the transport, so a deploy fault is a
 * loud startup error in one place: the same contract as `groqOptionsFromEnv`
 * (`./groq-config.ts`).
 *
 * Mistral's chat API speaks the OpenAI shape (Bearer auth, `messages[]`,
 * `response_format: json_schema` with `strict`, `temperature`, `max_tokens`),
 * so `openai-compatible-client.ts` serves it unchanged. The analysis provider
 * sends it NO `reasoning_effort`: that setting belongs to Groq's reasoning
 * models, and nothing about it applies here.
 *
 * The model is Mistral Small (`mistral-small-latest`, decision D2). Mistral
 * Saba, the original choice for its Arabic, was retired on 2025-09-30, and
 * Mistral's own docs point new integrations to Small.
 *
 * PRIVACY: the app runs on Mistral's free tier. Training on API input is
 * switched off in the Mistral console (D2), but the input is still the user's
 * OCR text leaving our infrastructure, so nothing here may be named in
 * user-facing copy (§7).
 */

import type { ChatClientOptions } from "./openai-compatible-client.ts";

/** Mistral's API root. `/chat/completions` is appended by the client. */
export const MISTRAL_BASE_URL = "https://api.mistral.ai/v1";

/**
 * Reads credentials from the environment the Edge Runtime injects.
 *
 * @throws if `MISTRAL_API_KEY` or `MISTRAL_MODEL` is missing or blank. Both
 * are deploy faults (matrix row A8), fatal before a slot is reserved rather
 * than a 500 on every analysis.
 */
export function mistralOptionsFromEnv(
  environment: { get(key: string): string | undefined } = Deno.env,
): ChatClientOptions {
  // Trimmed, as Groq's is: a key set to whitespace is a truthy string and
  // would reach the wire as `Bearer    `, answering 401 on every analysis.
  const apiKey = environment.get("MISTRAL_API_KEY")?.trim();

  if (!apiKey) {
    throw new Error("MISTRAL_API_KEY is not set.");
  }

  // Deliberately NOT defaulted, for the same reason `GROQ_MODEL` is not. A
  // wrong model fails EVERY analysis as `bad_request`, which never falls
  // back; a silent default would hide exactly the mistake worth shouting
  // about. It is env-configured so that it can change without a redeploy.
  const model = environment.get("MISTRAL_MODEL")?.trim();

  if (!model) {
    throw new Error(
      "MISTRAL_MODEL is not set. It must name a model that supports " +
        "`response_format: json_schema`, e.g. mistral-small-latest.",
    );
  }

  return { baseUrl: MISTRAL_BASE_URL, apiKey, model };
}
