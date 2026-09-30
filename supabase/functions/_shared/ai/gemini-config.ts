/**
 * F20-T07 · Gemini credentials and endpoint, for OCR.
 *
 * Gemini is the online OCR provider (F20 §1, layer 1): `ocr-document` sends it
 * the photo and gets the page's text back. It is not an analysis provider.
 * F18 used it as one over the OpenAI-compatible endpoint, and F20-T04 removed
 * that leg.
 *
 * The OCR client speaks Gemini's NATIVE `generateContent` API, because that is
 * where an image goes in as `inline_data`, and where `finishReason` and
 * `promptFeedback.blockReason` say why a reading was refused (matrix row O5).
 *
 * Read here, not inline in the transport, so a deploy fault is a loud error in
 * one place: the same contract as `groqOptionsFromEnv` and
 * `mistralOptionsFromEnv`.
 *
 * PRIVACY: the app runs on Gemini's free tier, whose terms let Google use and
 * human-review API input. Here the input is the photo of the user's paper. The
 * owner accepted that (F20 context §3), and T24 rewrites the privacy copy to
 * say so. Nothing here may be named in user-facing copy (§7).
 */

/**
 * Gemini's native API root. The client appends
 * `/models/{model}:generateContent`.
 *
 * Unlike the model, this IS a constant: it is a fixed property of the API, not
 * a per-deployment choice, and getting it wrong fails loudly (404), never
 * quietly.
 */
export const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";

export interface GeminiOptions {
  readonly baseUrl: string;
  readonly apiKey: string;
  readonly model: string;
}

/**
 * Reads credentials from the environment the Edge Runtime injects.
 *
 * @throws if `GEMINI_API_KEY` or `GEMINI_MODEL` is missing or blank: a deploy
 * fault, which `ocr-document` answers as INTERNAL_ERROR and the app never
 * falls back from (matrix row O6).
 */
export function geminiOptionsFromEnv(
  environment: { get(key: string): string | undefined } = Deno.env,
): GeminiOptions {
  // Trimmed: a copy-pasted `.env` value carrying a trailing newline is the
  // ordinary way a key ends up unusable.
  const apiKey = environment.get("GEMINI_API_KEY")?.trim();

  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not set.");
  }

  // Deliberately NOT defaulted (decision D1): the model is chosen by the T09
  // benchmark from the models the key can reach. A wrong or retired model
  // answers 404 on every photo, which is `bad_request` and never falls back
  // to Tesseract, so a silent default would turn a config slip into a total
  // outage of online reading.
  //
  // `.trim()` rather than `??`: an env var set to "" is still a string.
  const model = environment.get("GEMINI_MODEL")?.trim();

  if (!model) {
    throw new Error(
      "GEMINI_MODEL is not set. It must name a Gemini model that accepts " +
        "image input, as chosen by the F20-T09 benchmark.",
    );
  }

  return { baseUrl: GEMINI_BASE_URL, apiKey, model };
}
