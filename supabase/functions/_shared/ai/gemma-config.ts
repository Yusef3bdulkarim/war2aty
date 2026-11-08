/**
 * Gemma (Google's small open models) as an ANALYSIS leg, through the Gemini
 * API's OpenAI-compatible endpoint — so it reuses `createChatClient` and the
 * shared analysis provider (strict `json_schema`, shape check, semantic check)
 * exactly as Mistral and Groq do.
 *
 * Why Gemma: on the Gemini API free tier each Gemma 4 model has its own
 * 14,400 requests/day bucket (vs 500/day for Flash-Lite), at 30 RPM and
 * 16K input tokens/minute.
 *
 * It uses the SAME key as the OCR leg (`GEMINI_API_KEY`). The model is
 * `GEMMA_MODEL` — deliberately not defaulted, for the reason `MISTRAL_MODEL`
 * is not: a wrong id must fail loudly. Find valid ids with
 * `supabase/tools/list-gemma-models.ts`.
 *
 * Status: EXPERIMENT. Wired into the benchmark legs only, not production.
 */

import type { ChatClientOptions } from "./openai-compatible-client.ts";

export const GEMINI_OPENAI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/openai";

export function gemmaOptionsFromEnv(
  environment: { get(key: string): string | undefined } = Deno.env,
): ChatClientOptions {
  const apiKey = environment.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) throw new Error("GEMINI_API_KEY is not set.");

  const model = environment.get("GEMMA_MODEL")?.trim();
  if (!model) {
    throw new Error(
      "GEMMA_MODEL is not set. Run supabase/tools/list-gemma-models.ts to see the ids, e.g. gemma-4-31b-it.",
    );
  }

  return { baseUrl: GEMINI_OPENAI_BASE_URL, apiKey, model };
}
