/**
 * F14, rewired in F20-T13 · The ocr-document handler: the online reading, no
 * analysis.
 *
 * The first half of the online flow. Gemini reads the photo, the extractors
 * pull candidates from the reading, and both go back to the app. The user
 * reviews and edits the text on the device; `analyze-document`'s text path is
 * what the app calls next, once the user approves.
 *
 * ── Why no slot reservation ────────────────────────────────────────────────
 * The daily quota (§9) is a limit on analyses, not on reading a page.
 * Charging a slot here would mean a user who retakes a blurry photo twice
 * during review has already spent two of their three analyses before a
 * single one is analysed. The quota is reserved exactly once, when the
 * reviewed text is submitted to `analyze-document`.
 *
 * ── Failures (F20 matrix §1, rows O3–O6, O10) ─────────────────────────────
 * One Gemini attempt, with the whole `aiTimeoutSeconds` as its deadline (§2).
 * Its `ProviderFailure` becomes a §31 error through `ocrApiErrorFor`, and that
 * code alone tells the app whether it may read the page on the device instead.
 * - Rate limit, timeout, outage, network, unusable reading: yes (429, 408,
 *   502 `OCR_UNAVAILABLE`).
 * - Bad key, bad request, or missing `GEMINI_*`: no (500 `INTERNAL_ERROR`).
 *   A deploy fault must be seen and fixed, not papered over by the phone.
 * - Online reading switched off after the app chose the online route: 502
 *   `OCR_UNAVAILABLE`, so the app reads on the device (O10).
 *
 * PRIVACY: nothing derived from the document is logged. Every log line here
 * carries envelope fields, ids and failure kinds only (§51): no OCR text, no
 * candidate value, no image byte.
 */

import { ApiError, apiErrorForAuthFailure } from "../errors/api-error.ts";
import { requireUser, type TokenVerifier } from "../auth/require-user.ts";
import type { RuntimeConfig } from "../config/runtime-config.ts";
import type { EndpointHandler } from "../http/endpoint.ts";
import { jsonResponse } from "../http/response.ts";
import type { ExtractedCandidates } from "../prompts/analysis-prompt.ts";
import type { ImageOcrPipeline } from "./image-ocr-pipeline.ts";
import { logEvent } from "../observability/log.ts";
import { parseAnalyzeImageRequest } from "./analyze-request.ts";
import { ocrApiErrorFor, ProviderFailure } from "../ai/provider-failure.ts";

export interface OcrDependencies {
  readonly verifyToken: TokenVerifier;
  readonly loadConfig: () => Promise<RuntimeConfig>;
  /**
   * Built per request, so the `GEMINI_*` credentials are read when there is a
   * page to read. A missing one throws here, before any provider call, and
   * answers INTERNAL_ERROR (O6).
   */
  readonly createPipeline: () => ImageOcrPipeline;
  /** Injected so tests can see the deadline without a real timer. */
  readonly timeoutSignal?: (ms: number) => AbortSignal;
}

/** The response this endpoint hands back — OCR output only, never an analysis. */
export interface OcrResponseBody {
  readonly schema_version: string;
  readonly session_id: string;
  readonly ocr_text: string;
  /** Always `[]`: the reading carries no language tags. */
  readonly detected_languages: readonly string[];
  readonly candidates: ExtractedCandidates;
}

export function createOcrHandler(
  dependencies: OcrDependencies,
): EndpointHandler {
  const {
    verifyToken,
    loadConfig,
    createPipeline,
    timeoutSignal = (ms: number) => AbortSignal.timeout(ms),
  } = dependencies;

  return async ({ request, requestId }): Promise<Response> => {
    const auth = await requireUser(request, verifyToken);
    if (!auth.ok) throw apiErrorForAuthFailure(auth.reason);

    const config = await loadConfig();
    if (!config.analysisEnabled) throw ApiError.analysisDisabled();
    // The app only calls this endpoint after choosing the online route. If
    // online reading was switched off since, the page can still be read on
    // the device, so this is OCR_UNAVAILABLE rather than a refusal (O10).
    if (!config.azureOcrEnabled) throw ApiError.ocrUnavailable();

    let rawBody: unknown;
    try {
      rawBody = await request.json();
    } catch {
      // The parse error quotes the body it choked on, and the body is the
      // user's document. Discarded, never logged (§51).
      throw ApiError.invalidRequest();
    }

    // This endpoint only ever serves the image shape — there is no text
    // variant of "read this page's OCR". `parseAnalyzeImageRequest` already
    // throws INVALID_REQUEST for anything whose `input_type` is not
    // `"image"`, so nothing else needs to check the discriminant first.
    const parsed = parseAnalyzeImageRequest(rawBody, config);

    const pipeline = createPipeline();
    let result;
    try {
      result = await pipeline(
        { data: parsed.image.data, mimeType: parsed.image.mimeType },
        timeoutSignal(config.aiTimeoutSeconds * 1000),
      );
    } catch (thrown) {
      // Anything else is our own bug; the endpoint turns it into
      // INTERNAL_ERROR with its message discarded.
      if (!(thrown instanceof ProviderFailure)) throw thrown;
      const wire = ocrApiErrorFor(thrown);
      logEvent("ocr.failed", {
        request_id: requestId,
        session_id: parsed.sessionId,
        failure: thrown.kind,
        error_code: wire.code,
      });
      throw wire;
    }

    logEvent("ocr.completed", {
      request_id: requestId,
      session_id: parsed.sessionId,
    });

    const body: OcrResponseBody = {
      schema_version: config.schemaVersion,
      session_id: parsed.sessionId,
      ocr_text: result.ocrText,
      detected_languages: [],
      candidates: result.candidates,
    };

    return jsonResponse(body, { requestId });
  };
}
