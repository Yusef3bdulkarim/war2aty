/**
 * F18-T04 · Gemini credentials and endpoint.
 *
 * Read here, not inline in the transport, so a deploy fault is a loud startup
 * error in one place — same contract as `groqOptionsFromEnv`
 * (`./groq-config.ts`) and `googleDocumentAiOptionsFromEnv`
 * (`../google/google-config.ts`).
 *
 * Gemini is reached over its OpenAI-COMPATIBLE endpoint, not its native one,
 * which is what lets `openai-compatible-client.ts` serve both legs unchanged:
 * the same Bearer auth, `messages[]`, `response_format`, `temperature` and
 * `max_tokens` Groq already takes. Google documents that layer as beta and
 * says unsupported parameters are *silently ignored* rather than rejected, so
 * F18-T08 must prove `response_format: json_schema` is actually honoured
 * before the flag is flipped — `assertModelAnalysis` is the runtime backstop
 * if it ever regresses.
 *
 * PRIVACY: the app runs this leg on the FREE tier, whose terms let Google use
 * and human-review API input — and the API input is the OCR text. That is why
 * F18-T02 removed the claim that nobody sees the text. Nothing here may be
 * named in user-facing copy (§7).
 */

import type { ChatClientOptions } from "./openai-compatible-client.ts";

/**
 * Gemini's OpenAI-compatible root. `/chat/completions` is appended by the
 * client, giving `/v1beta/openai/chat/completions`.
 *
 * Unlike the model, this one IS defaulted: it is a fixed property of the API
 * rather than a per-deployment choice, and getting it wrong fails loudly and
 * immediately (404) rather than quietly producing bad analyses.
 */
export const GEMINI_DEFAULT_BASE_URL =
  "https://generativelanguage.googleapis.com/v1beta/openai";

/**
 * The model this leg is built around, and the one `.env.example` will set.
 *
 * Deliberately NOT used by {@link geminiOptionsFromEnv} — it exists for the
 * live integration tests (F18-T08) to fall back to, exactly as
 * `DEFAULT_GROQ_MODEL` does for Groq's. The production path refuses to guess a
 * model; see {@link geminiOptionsFromEnv}.
 *
 * `gemini-1.5-flash` is retired (404) and `gemini-2.5-flash` is restricted to
 * accounts with prior 2.5 usage, which a new project does not have.
 */
export const DEFAULT_GEMINI_MODEL = "gemini-3.1-flash-lite";

/**
 * Reads credentials from the environment the Edge Runtime injects.
 *
 * @throws if `GEMINI_API_KEY` or `GEMINI_MODEL` is missing or blank.
 *
 * Note the division of labour with {@link isGeminiConfigured}: that function
 * decides whether the operator MEANT to enable this leg; this one insists the
 * leg is actually usable. A deployment that sets the key but not the model is
 * therefore a loud startup error, not a silently-skipped provider.
 */
export function geminiOptionsFromEnv(
  timeoutSeconds: number,
  environment: { get(key: string): string | undefined } = Deno.env,
): ChatClientOptions {
  const apiKey = environment.get("GEMINI_API_KEY")?.trim();

  if (!apiKey) {
    // A deploy fault, not a user error. Surfaced loudly here rather than as a
    // baffling 500 on every analysis.
    throw new Error("GEMINI_API_KEY is not set.");
  }

  // Deliberately NOT defaulted, for the same reason `GROQ_MODEL` is not: a
  // model that cannot serve `json_schema` fails EVERY analysis with a 400 the
  // user only ever sees as ANALYSIS_FAILED — a total outage wearing the
  // costume of a flaky provider. Falling back to a constant would hide exactly
  // the mistake worth shouting about.
  //
  // Read with `.trim()` rather than `??`: an env var set to "" is a string, so
  // `??` would wave it through and send an empty model name.
  const model = environment.get("GEMINI_MODEL")?.trim();

  if (!model) {
    throw new Error(
      "GEMINI_MODEL is not set. It must name a model that supports " +
        "`response_format: json_schema` — see supabase/.env.example.",
    );
  }

  return {
    baseUrl: baseUrlFromEnv(environment),
    apiKey,
    model,
    timeoutSeconds,
  };
}

/**
 * The override exists so a test or a future API version can be pointed
 * elsewhere without a code change. Trailing slashes are stripped: the client
 * appends `/chat/completions`, and `…/openai//chat/completions` is a 404 that
 * would look exactly like a retired model.
 */
function baseUrlFromEnv(
  environment: { get(key: string): string | undefined },
): string {
  const override = environment.get("GEMINI_BASE_URL")?.trim();
  const baseUrl = override && override.length > 0
    ? override
    : GEMINI_DEFAULT_BASE_URL;

  return baseUrl.replace(/\/+$/, "");
}

/**
 * Returns `true` when `GEMINI_API_KEY` is present and non-blank.
 *
 * Checks the KEY ONLY, and that is deliberate. The key is how an operator
 * expresses the intent "use this provider"; the model is a completeness
 * requirement enforced loudly by {@link geminiOptionsFromEnv} once that intent
 * is on record. Were this to require the model too, a deployment that set the
 * key and forgot the model would report as unconfigured and be skipped in
 * silence — the F18-T06 matrix would quietly fall back to Groq alone and
 * nobody would learn why Gemini never served a request.
 *
 * Gemini is an optional provider, like Google Document AI
 * (`isGoogleDocumentAiConfigured`): absent, the chain runs Groq alone, which
 * is bit-for-bit today's behaviour.
 */
export function isGeminiConfigured(
  environment: { get(key: string): string | undefined } = Deno.env,
): boolean {
  const apiKey = environment.get("GEMINI_API_KEY")?.trim();
  return apiKey !== undefined && apiKey.length > 0;
}
