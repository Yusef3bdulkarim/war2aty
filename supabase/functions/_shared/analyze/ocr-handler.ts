/**
 * F14 · The ocr-document handler — Azure OCR + extractors, no Groq.
 *
 * The online (F13) flow used to go straight from an image to a finished
 * `DocumentAnalysis` in one call. This handler is the first half of that
 * split: it runs exactly the same image pipeline `analyze-handler.ts` runs
 * for an `input_type: "image"` request, then STOPS and hands the OCR text
 * and candidates back to the client instead of feeding them to Groq. The
 * user reviews/edits the text on-device; the (unmodified) `analyze-document`
 * text path is what the client calls next, once the user approves.
 *
 * ── Why no slot reservation ────────────────────────────────────────────────
 * The daily quota (§9) is a limit on Groq analyses, not on reading a page.
 * Charging a slot here would mean a user who retakes a blurry photo twice
 * during review has already spent two of their three analyses before a
 * single one reaches Groq. The quota is reserved exactly once, when the
 * reviewed text is submitted to `analyze-document` — unchanged by this file.
 *
 * ── Why the same `azureOcrEnabled` gate ────────────────────────────────────
 * This endpoint has no reason to exist while the online image pipeline is
 * dark-launched off (locked decision #1): every request it could serve would
 * be refused by `analyze-document` a call later anyway. Same fixed
 * `INVALID_REQUEST` response as that endpoint gives an image-shaped body
 * while the flag is off — a disabled feature and a request this deployment
 * does not understand must look identical from the outside.
 *
 * PRIVACY: nothing derived from the document is logged. Every log line here
 * carries envelope fields and ids only (§51) — no OCR text, no candidate
 * value, no image byte.
 */

import { ApiError, apiErrorForAuthFailure } from "../errors/api-error.ts";
import { requireUser, type TokenVerifier } from "../auth/require-user.ts";
import type { RuntimeConfig } from "../config/runtime-config.ts";
import type { EndpointHandler } from "../http/endpoint.ts";
import { jsonResponse } from "../http/response.ts";
import type { ExtractedCandidates } from "../prompts/analysis-prompt.ts";
import type { ImageAnalysisPipeline } from "./image-analysis-pipeline.ts";
import { logEvent } from "../observability/log.ts";
import { parseAnalyzeImageRequest } from "./analyze-request.ts";

export interface OcrDependencies {
  readonly verifyToken: TokenVerifier;
  readonly loadConfig: () => Promise<RuntimeConfig>;
  /**
   * Same reasoning as `AnalyzeDependencies.createImagePipeline`: Azure/Google
   * credentials are a deploy fact and a missing one must fail loudly, so the
   * client is built per request rather than at module load.
   */
  readonly createImagePipeline: (timeoutSeconds: number) => ImageAnalysisPipeline;
}

/** The response this endpoint hands back — OCR output only, never an analysis. */
export interface OcrResponseBody {
  readonly schema_version: string;
  readonly session_id: string;
  readonly ocr_text: string;
  /** Always `[]` — Azure's Read model result carries no language tags, same
   * fallback `analyze-handler.ts` already uses for the image shape. */
  readonly detected_languages: readonly string[];
  readonly candidates: ExtractedCandidates;
}

export function createOcrHandler(
  dependencies: OcrDependencies,
): EndpointHandler {
  const { verifyToken, loadConfig, createImagePipeline } = dependencies;

  return async ({ request, requestId }): Promise<Response> => {
    const auth = await requireUser(request, verifyToken);
    if (!auth.ok) throw apiErrorForAuthFailure(auth.reason);

    const config = await loadConfig();
    if (!config.analysisEnabled) throw ApiError.analysisDisabled();
    // Dark-launch gate — see header comment. Mirrors the check
    // `analyze-handler.ts` runs before it will even parse an image body.
    if (!config.azureOcrEnabled) throw ApiError.invalidRequest();

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

    const pipeline = createImagePipeline(config.aiTimeoutSeconds);
    const result = await pipeline({
      data: parsed.image.data,
      mimeType: parsed.image.mimeType,
    });

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
