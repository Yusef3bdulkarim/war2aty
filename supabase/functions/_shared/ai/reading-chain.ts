/**
 * F36-T07 · The reading chain — one photo, up to three Gemini legs, one text.
 *
 * `explain-document` reads the page server-side and never hands the reading
 * back to the phone (trap #4), so a failed read is not something the user can
 * work around: after F39 there is no on-device reader left to fall back to.
 * That is why reading is a CHAIN here and a single attempt in `ocr-document`.
 *
 * ── Three legs, one provider (D1-bis) ─────────────────────────────────────
 * D1 planned Mistral OCR as leg 3. The free plan answers `/v1/ocr` with 429 at
 * the first call while chat on the same key answers 200 — a plan gate wearing
 * a rate limit's clothes — and Groq's catalogue for our key holds no vision
 * model at all. With no paid tier anywhere, the owner chose a third **Gemini
 * model id** instead: its own quota bucket, its own 15 RPM, and no new client
 * and no new provider. The order D1-bis settled is
 * `gemini-3.5-flash-lite` → `gemini-3.1-flash-lite` → `gemini-3.5-flash`,
 * and T08 makes it operator-settable so a retired id can be swapped without a
 * deploy — which is exactly what happened to both 2.5 ids during T03.
 *
 * So this file builds no transport. Every leg is `createGeminiOcrClient` bound
 * to a different model id, which already has the shape of a `ChainLeg.run`:
 * `(image, signal) => Promise<GeminiOcrResult>`. The chain gains a leg without
 * gaining a client.
 *
 * What three legs buy is BURST headroom, not provider diversity. T03 measured
 * 1,500 requests a day per model and our own global cap is 900, so the day's
 * ceiling was never the pressure point; 15 requests a MINUTE per model is.
 * Three legs make that 45 a minute. One key, one account, one outage — a
 * Google-wide failure takes all three, and nothing here pretends otherwise.
 *
 * ── Time ──────────────────────────────────────────────────────────────────
 * The stage owns a deadline inside T15's budget: D4 split 30 s into 10 s of
 * reading and 20 s of explaining. The cap and floor below are sized so that
 * three legs still FIT in those 10 s when every one of them hangs — see
 * {@link DEFAULT_READ_ATTEMPT_CAP_MS}. The analysis chain's 18 s cap would
 * have let leg 1 eat the whole stage and made legs 2 and 3 decorative.
 *
 * ── What is NOT decided here ──────────────────────────────────────────────
 * An empty reading is an ANSWER, not a failure (F20 matrix row O2): a blank
 * page really is blank, and `createGeminiOcrClient` returns `""` for it. This
 * chain passes that through unchanged rather than quietly spending a second
 * leg on it. Whether `explain-document` can do anything with an empty reading
 * is T15's question, and it is flagged in the task file.
 *
 * PRIVACY (§7, §51): nothing here touches the image or the reading. The legs
 * are opaque functions and the chain logs provider names, failure kinds and
 * §31 codes only.
 */

import { createGeminiOcrClient, type GeminiOcrResult, type OcrImage } from "./gemini-ocr-client.ts";
import type { GeminiCredentials } from "./gemini-config.ts";
import {
  type ChainLeg,
  createLegChain,
  type LegChainOptions,
  type ProviderName,
} from "./leg-chain.ts";
import { analysisApiErrorFor } from "./provider-failure.ts";

/**
 * The reading stage's share of D4's 30 s budget.
 *
 * Recorded here, where the stage lives, for T15 to split the request with. The
 * other 20 s are the explaining stage's.
 */
export const DEFAULT_READ_STAGE_SECONDS = 10;

/**
 * The longest one read may run.
 *
 * Derived from the stage budget rather than from a provider's p95, because the
 * p95 is not the binding constraint here: T03's probes read a page in 0.7–1.4 s,
 * and the same model varied more between two runs than two models did. What
 * binds is that **all three legs must still be reachable when each one hangs**:
 * 4 s + 4 s leaves 2 s of the 10 s stage, which is exactly
 * {@link DEFAULT_READ_MIN_FALLBACK_MS}, so leg 3 is always given its chance.
 * At ~3× the slowest reading T03 saw, the cap is also loose enough that a
 * dense page is not cut off in the ordinary case.
 *
 * T18's benchmark measures real pages and may move this; it is a deliberate
 * default, not a measurement.
 */
export const DEFAULT_READ_ATTEMPT_CAP_MS = 4_000;

/**
 * The least time worth starting a further read with.
 *
 * A read that normally finishes in about a second is worth attempting with 2 s
 * left. Below that it would almost certainly time out, turning one failure
 * into two and spending the user's wait on nothing.
 */
export const DEFAULT_READ_MIN_FALLBACK_MS = 2_000;

/**
 * The chain's log event, kept apart from the explaining stage's.
 *
 * Two chains run inside one `explain-document` request. A shared event name
 * would make the log explorer unable to say whether the reading or the
 * explaining is the one burning through its quota.
 */
export const READ_EVENT = "explain.read";

/**
 * One name per position, in order. The closed union is the reason
 * {@link MAX_READING_LEGS} exists: a fourth leg would have nothing to be
 * called in the log.
 */
const READING_LEG_NAMES: readonly ProviderName[] = [
  "gemini_read_1",
  "gemini_read_2",
  "gemini_read_3",
];

export const MAX_READING_LEGS = READING_LEG_NAMES.length;

/** Image in, the page's text out. Throws only `ApiError`. */
export type ReadingChain = (image: OcrImage) => Promise<GeminiOcrResult>;

export interface ReadingChainOptions {
  /**
   * The key and base URL every leg shares, as `geminiReadingOptionsFromEnv`
   * reads them (T08). It carries no model: the ids come from {@link models},
   * one per leg, which is the whole point of the chain. A full `GeminiOptions`
   * is still assignable, and its `model` is never read.
   */
  readonly gemini: GeminiCredentials;
  /**
   * The model ids, in the order they are tried, one leg each. Required and
   * never defaulted, for the same reason `GEMINI_MODEL` is not: a stale
   * hardcoded id answers 404 on every photo, which is `bad_request` and so
   * never fails over, turning a config slip into a total outage of reading.
   * T08 is what supplies these from the environment.
   *
   * Duplicates are not rejected here — two legs on one id share a bucket,
   * which is useless but not harmful, and T08 is where an operator's input is
   * cleaned up.
   */
  readonly models: readonly string[];
  /** The stage's budget. Defaults to {@link DEFAULT_READ_STAGE_SECONDS}. */
  readonly totalSeconds?: number;
  /** Per-read cap. Defaults to {@link DEFAULT_READ_ATTEMPT_CAP_MS}. */
  readonly attemptCapMs?: number;
  /** Floor for starting a further read. Defaults to {@link DEFAULT_READ_MIN_FALLBACK_MS}. */
  readonly minFallbackMs?: number;
  /** Correlates the `explain.read` line with the rest of the request. */
  readonly requestId: string;
  /**
   * How a read failure becomes the §31 error the endpoint throws.
   *
   * Defaults to `analysisApiErrorFor`, which is already the mapping this
   * stage needs: 429 → AI_RATE_LIMITED, our budget → TIMEOUT, an outage or an
   * unusable reading → ANALYSIS_FAILED, and a bad key or a bad model id →
   * INTERNAL_ERROR. **`OCR_UNAVAILABLE` is unreachable here and must stay so**
   * (trap #3): that code tells the app it may read on the device instead, and
   * after F39 there is no on-device reader, so emitting it would be an
   * instruction the client cannot follow. T17 writes the full table into §33
   * and pins every row; this default is what it is expected to confirm.
   */
  readonly apiErrorFor?: LegChainOptions<OcrImage, GeminiOcrResult>["apiErrorFor"];
  /** Injected so tests never touch the network. */
  readonly fetchImpl?: typeof fetch;
  /** Milliseconds since epoch. Injected so tests need no clock. */
  readonly now?: () => number;
  /** Injected so tests can see each attempt's budget without a real timer. */
  readonly timeoutSignal?: LegChainOptions<OcrImage, GeminiOcrResult>["timeoutSignal"];
  /** Injected so tests can read the event without capturing stdout. */
  readonly log?: LegChainOptions<OcrImage, GeminiOcrResult>["log"];
}

/**
 * Builds the reading chain for one request.
 *
 * Credentials and model ids are read by the CALLER and passed in, so a deploy
 * fault is thrown while the handler is still building its chains — before it
 * reserves a slot, and so before it can cost a user one of their five
 * (matrix row A8, and `explain-handler.ts`'s ordering in T15).
 */
export function createReadingChain(options: ReadingChainOptions): ReadingChain {
  const {
    gemini,
    models,
    totalSeconds = DEFAULT_READ_STAGE_SECONDS,
    attemptCapMs = DEFAULT_READ_ATTEMPT_CAP_MS,
    minFallbackMs = DEFAULT_READ_MIN_FALLBACK_MS,
    requestId,
    apiErrorFor = analysisApiErrorFor,
    fetchImpl,
    now,
    timeoutSignal,
    log,
  } = options;

  // Programmer errors, not runtime conditions: the ids come from config at
  // deploy time, never from the request, so they are checked loudly and once.
  if (models.length === 0) {
    throw new RangeError("The reading chain needs at least one Gemini model id.");
  }
  if (models.length > MAX_READING_LEGS) {
    throw new RangeError(
      `The reading chain takes at most ${MAX_READING_LEGS} model ids: ` +
        "each leg is named by its position in the log, and there is no fourth name.",
    );
  }
  if (models.some((model) => model.trim() === "")) {
    throw new RangeError("A reading leg's Gemini model id must not be blank.");
  }

  const legs: ChainLeg<OcrImage, GeminiOcrResult>[] = models.map((model, index) => ({
    name: READING_LEG_NAMES[index],
    // The only difference between the legs. Same key, same transport, same
    // prompt — a different id, and so a different quota bucket.
    run: createGeminiOcrClient({ ...gemini, model, fetchImpl }),
  }));

  return createLegChain<OcrImage, GeminiOcrResult>({
    legs,
    totalSeconds,
    attemptCapMs,
    minFallbackMs,
    requestId,
    event: READ_EVENT,
    apiErrorFor,
    now,
    timeoutSignal,
    log,
  });
}
