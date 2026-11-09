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

type Environment = { get(key: string): string | undefined };

/**
 * `GEMINI_API_KEY`, trimmed, or a loud error naming the variable only.
 *
 * Shared by the single-model reader below and the reading chain's, so the key
 * is one rule in one place.
 */
function apiKeyFrom(environment: Environment): string {
  // Trimmed: a copy-pasted `.env` value carrying a trailing newline is the
  // ordinary way a key ends up unusable.
  const apiKey = environment.get("GEMINI_API_KEY")?.trim();

  if (!apiKey) {
    throw new Error("GEMINI_API_KEY is not set.");
  }
  return apiKey;
}

/**
 * Reads credentials from the environment the Edge Runtime injects.
 *
 * @throws if `GEMINI_API_KEY` or `GEMINI_MODEL` is missing or blank: a deploy
 * fault, which `ocr-document` answers as INTERNAL_ERROR and the app never
 * falls back from (matrix row O6).
 */
export function geminiOptionsFromEnv(
  environment: Environment = Deno.env,
): GeminiOptions {
  const apiKey = apiKeyFrom(environment);

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

/**
 * Credentials without a model: the key and root every reading leg shares. The
 * ids travel separately, one per leg (see {@link GeminiReadingOptions}).
 */
export type GeminiCredentials = Omit<GeminiOptions, "model">;

export interface GeminiReadingOptions {
  readonly gemini: GeminiCredentials;
  /** In the order they are tried: one leg per id. At most three, no repeats. */
  readonly models: readonly string[];
}

/** The most ids the reading chain can name in its log; see `reading-chain.ts`. */
export const MAX_READING_MODELS = 3;

/**
 * Reads what `explain-document`'s reading chain needs (F36-T08): the shared
 * key, and the model ids from `GEMINI_OCR_MODELS`, a comma-separated list in
 * the order they are tried:
 * `gemini-3.5-flash-lite,gemini-3.1-flash-lite,gemini-3.5-flash`.
 *
 * Operator-settable without a deploy, exactly as `GEMINI_MODEL` is, because a
 * model id is the thing that goes stale: T03 found both 2.5 ids retired for
 * new users. A leg is a model id, not a provider (D1-bis), so swapping an id
 * is an operator's job and never a code change.
 *
 * ── Why there is no Mistral OCR leg ───────────────────────────────────────
 * F34 planned Mistral OCR as leg 3, and D1 approved it on the strength of a
 * $10 monthly credit. Measured on 2026-11-09 (T03), the free plan serves no
 * OCR: `POST /v1/ocr` answers **429** with `mistral-ocr-latest` and with
 * `mistral-ocr-2512` on a 583-byte image, while `POST /v1/chat/completions`
 * on the same key answers 200 — a plan gate wearing a rate limit's clothes.
 * Groq's catalogue for our key is text and audio only, so it cannot read a
 * photo at any price. The project takes no paid tier and holds no payment
 * method, so the third leg is a third Gemini id. Do not re-add Mistral OCR
 * from F34's prose; D1-bis in the F36 task file has the evidence.
 *
 * ── Cleaning ──────────────────────────────────────────────────────────────
 * Entries are trimmed and empty ones dropped (a trailing comma is the
 * ordinary slip). A repeated id keeps its FIRST position: two legs on one id
 * share one quota bucket, so the second would only repeat a 429 the first
 * just earned. More than {@link MAX_READING_MODELS} distinct ids is refused
 * rather than truncated, because silently ignoring the tail would run a
 * different chain from the one the operator wrote.
 *
 * Not defaulted (D1, as for `GEMINI_MODEL`): a stale hardcoded id answers 404
 * on every photo, which is `bad_request` and never fails over, so a default
 * would turn a config slip into a total outage of reading.
 *
 * @throws if `GEMINI_API_KEY` or `GEMINI_OCR_MODELS` is missing, blank, or
 * names no usable id, or if the list holds more than three distinct ids. Every
 * message names the variable only, never a value.
 */
export function geminiReadingOptionsFromEnv(
  environment: Environment = Deno.env,
): GeminiReadingOptions {
  const apiKey = apiKeyFrom(environment);
  const raw = environment.get("GEMINI_OCR_MODELS") ?? "";

  const models: string[] = [];
  for (const entry of raw.split(",")) {
    const id = entry.trim();
    if (id !== "" && !models.includes(id)) models.push(id);
  }

  if (models.length === 0) {
    throw new Error(
      "GEMINI_OCR_MODELS is not set. It must list one to three Gemini model " +
        "ids that accept image input, comma-separated, in the order they are tried.",
    );
  }
  if (models.length > MAX_READING_MODELS) {
    throw new Error(
      `GEMINI_OCR_MODELS lists more than ${MAX_READING_MODELS} distinct model ids.`,
    );
  }

  return { gemini: { baseUrl: GEMINI_BASE_URL, apiKey }, models };
}
