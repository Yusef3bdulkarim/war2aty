/**
 * F06-T13 / F13-T11 · The analyze-document handler.
 *
 * The one place the pieces built by T03–T12 are put in order. It owns no rules
 * of its own — every decision below belongs to a module that can be tested on
 * its own — so what this file has to get right is the SEQUENCE.
 *
 * ── Why the order is what it is ──────────────────────────────────────────
 * Each step is cheaper than the one after it, and each one refuses a request
 * that must never reach the next:
 *
 *   1. auth          — nobody unauthenticated may cost us a database round-trip
 *   2. runtime config — one read; also the kill switch
 *   3. kill switch   — a disabled service should not care about body shape
 *   4. parse body    — free, and gates everything below on a valid contract
 *   5. reserve slot  — both quotas (the caller's own and the service-wide cap)
 *                      are enforced BEFORE the AI is called, or a refusal
 *                      costs us the provider call anyway
 *   6. analyse       — the only expensive step (Azure/Google for an image
 *                      request, T11; Groq for both shapes)
 *   7. validate      — the model's answer is never returned as-is
 *
 * There is deliberately no daily-limit pre-check before the reservation. The
 * reserve is atomic and already answers `limit_reached`; a read-then-reserve
 * would add a round-trip and a race it cannot win (F06-T07).
 *
 * ── Two request shapes, one sequence (F13-T11) ────────────────────────────
 * `input_type` picks the shape before anything else is parsed. The `"image"`
 * shape is dark-launched behind `RuntimeConfig.azureOcrEnabled` (locked
 * decision #1): off, it is refused exactly as it always was before this task
 * — `INVALID_REQUEST`, indistinguishable from a shape this deployment does
 * not parse. On, the image is read by `image-analysis-pipeline.ts` (T04–T08)
 * INSIDE the reserved slot, same as the Groq call — it is a paid provider
 * call and must not run before the quota check. The `"text"` shape's own
 * sequence is untouched: same parser, same fields, same order.
 *
 * PRIVACY: nothing derived from the document is logged. Every log line here
 * carries envelope fields, statuses and counts only (§51).
 */

import { ApiError, apiErrorForAuthFailure } from "../errors/api-error.ts";
import { requireUser, type TokenVerifier } from "../auth/require-user.ts";
import type { RuntimeConfig } from "../config/runtime-config.ts";
import type { EndpointHandler } from "../http/endpoint.ts";
import { jsonResponse } from "../http/response.ts";
import type { AiAnalysisProvider } from "../groq/groq-provider.ts";
import type { ImageAnalysisPipeline } from "./image-analysis-pipeline.ts";
import { logEvent } from "../observability/log.ts";
import { cairoDayOf, nextCairoResetAfter, toCairoIsoString } from "../time/cairo-day.ts";
import type { SlotStore } from "../usage/slot-reservation.ts";
import { withReservedSlot } from "../usage/slot-reservation.ts";
import { validateAnalysis } from "../validators/validation-pipeline.ts";
import {
  type AnalyzeImageRequest,
  parseAnalyzeImageRequest,
  parseAnalyzeRequest,
} from "./analyze-request.ts";
import { buildAnalysisResponse, type BuiltAnalysisResponse } from "./analyze-response.ts";

export interface AnalyzeDependencies {
  readonly verifyToken: TokenVerifier;
  readonly loadConfig: () => Promise<RuntimeConfig>;
  readonly slots: SlotStore;
  /**
   * Built per request because the timeout comes from runtime config, which an
   * operator can change without a redeploy.
   */
  readonly createAnalyser: (timeoutSeconds: number) => AiAnalysisProvider;
  /**
   * Same reasoning as {@link createAnalyser}: Azure/Google credentials are a
   * deploy fact and a missing one must fail loudly. Only ever invoked for an
   * image-shaped request (F13-T11) — text-shaped traffic, still the
   * overwhelming majority while `azureOcrEnabled` stays dark, never
   * constructs this and so never requires Azure/Google to be configured.
   */
  readonly createImagePipeline: (timeoutSeconds: number) => ImageAnalysisPipeline;
  readonly hashInstallation: (installationId: string) => Promise<string>;
  /** Injected so Cairo-day boundaries are testable. */
  readonly now: () => Date;
}

/**
 * How much longer than the AI timeout a slot is held.
 *
 * Must be positive, or a slow-but-successful analysis would have its slot swept
 * out from under it mid-flight and finalize would find nothing to settle. Must
 * stay small, because until it lapses a crashed request keeps a slot the user
 * cannot use.
 */
const RESERVATION_GRACE_SECONDS = 10;

/** `input_type`, read without trusting the body is even an object yet. */
function requestedInputType(body: unknown): unknown {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return undefined;
  return (body as Record<string, unknown>).input_type;
}

/**
 * Runs the online pipeline and reshapes its result into the same
 * `{ ocrText, detectedLanguages, candidates, verification }` fields the text
 * shape already carries, so the sequence below never has to know which shape
 * produced them.
 *
 * `detectedLanguages` is always `[]`: Azure's Read model result carries no
 * language tags (unlike the on-device OCR engine), and an empty list reads to
 * the prompt builder as "unknown" — the same fallback it already had.
 */
async function readImage(
  pipeline: ImageAnalysisPipeline,
  request: AnalyzeImageRequest,
) {
  const result = await pipeline({
    data: request.image.data,
    mimeType: request.image.mimeType,
  });

  return {
    ocrText: result.ocrText,
    detectedLanguages: [] as readonly string[],
    candidates: result.candidates,
    verification: result.verification,
  };
}

export function createAnalyzeHandler(
  dependencies: AnalyzeDependencies,
): EndpointHandler {
  const {
    verifyToken,
    loadConfig,
    slots,
    createAnalyser,
    createImagePipeline,
    hashInstallation,
    now,
  } = dependencies;

  return async ({ request, requestId, requestIdSource }): Promise<Response> => {
    const auth = await requireUser(request, verifyToken);
    if (!auth.ok) throw apiErrorForAuthFailure(auth.reason);

    const config = await loadConfig();
    if (!config.analysisEnabled) throw ApiError.analysisDisabled();

    let rawBody: unknown;
    try {
      rawBody = await request.json();
    } catch {
      // The parse error quotes the body it choked on, and the body is the
      // user's document. Discarded, never logged (§51).
      throw ApiError.invalidRequest();
    }

    // §29 v2 dispatch. Off, the image shape is refused exactly as it always
    // was before this task — the parser below already throws INVALID_REQUEST
    // for anything but `input_type: "text"`, and that is precisely the
    // behaviour a dark `azureOcrEnabled` must preserve.
    const isImageRequest = requestedInputType(rawBody) === "image";
    if (isImageRequest && !config.azureOcrEnabled) throw ApiError.invalidRequest();

    const parsed = isImageRequest
      ? parseAnalyzeImageRequest(rawBody, config)
      : parseAnalyzeRequest(rawBody, config);

    const instant = now();
    // Built before the reservation: a missing GROQ_API_KEY (or, for an image
    // request, Azure/Google credential) is a deploy fault, and it must not
    // burn a slot to discover it.
    const analyse = createAnalyser(config.aiTimeoutSeconds);
    const imagePipeline = parsed.inputType === "image"
      ? createImagePipeline(config.aiTimeoutSeconds)
      : null;
    const installationHash = await hashInstallation(parsed.installationId);

    const outcome = await withReservedSlot<BuiltAnalysisResponse>(
      slots,
      {
        userId: auth.user.id,
        day: cairoDayOf(instant),
        requestId,
        installationHash,
        dailyLimit: config.dailyLimit,
        globalDailyCallCap: config.globalDailyCallCap,
        ttlSeconds: config.aiTimeoutSeconds + RESERVATION_GRACE_SECONDS,
      },
      async () => {
        // The online image read (Azure, and a conditional Google second
        // opinion) is exactly as expensive as the Groq call below, and for
        // the same reason must run only after the slot is held.
        const { ocrText, detectedLanguages, candidates, verification } =
          parsed.inputType === "image" ? await readImage(imagePipeline!, parsed) : {
            ocrText: parsed.ocrText,
            detectedLanguages: parsed.detectedLanguages,
            candidates: parsed.candidates,
            verification: null,
          };

        const model = await analyse({ ocrText, detectedLanguages, candidates, verification });

        const validated = validateAnalysis({
          analysis: model,
          ocrText,
          candidates,
          now: instant,
          crossProviderVerification: verification,
        });

        logEvent("analyze.validated", {
          request_id: requestId,
          downgraded: validated.report.downgraded.join(",") || null,
          dropped_amounts: validated.report.droppedAmounts,
          cleared_reminders: validated.report.clearedReminders,
          added_warnings: validated.report.addedWarnings.join(",") || null,
        });

        // Built inside the slot on purpose: it can still fail (a blank title
        // is not a usable analysis), and that failure must release the slot
        // rather than charge the user for a screen they cannot read.
        return buildAnalysisResponse({
          analysis: validated.analysis,
          sessionId: parsed.sessionId,
          schemaVersion: config.schemaVersion,
          candidates,
          verification,
        });
      },
      // §31 rule 6: `unsupported` is a 200 that costs the user nothing.
      (result) => result.body.status !== "unsupported",
    );

    if (outcome.status !== "ran") {
      if (outcome.status === "limit_reached") {
        throw ApiError.dailyLimitReached(
          toCairoIsoString(nextCairoResetAfter(instant)),
        );
      }

      if (outcome.status === "global_capacity_reached") {
        // Logged at the point it fires because nothing else surfaces it: the
        // breaker tripping is a service-wide event an operator needs to see to
        // decide whether to raise the cap, and the caller is told only that
        // capacity is gone. Counts and ids only (§51).
        logEvent("analyze.global_capacity_reached", {
          request_id: requestId,
          global_daily_call_cap: config.globalDailyCallCap,
          // The CALLER's count, not the global one — the reserve returns
          // per-user figures even on this branch. Named explicitly so nobody
          // reads it as the day's global total next to the cap above; its only
          // use is showing that the refused caller was not at their own limit.
          caller_used_today: outcome.reservation.usedToday,
        });
        throw ApiError.globalCapacityReached();
      }

      // Another request already holds — or already settled — this id. Running
      // it again would either double-charge the quota or return a second
      // reading of the same paper, so it is refused.
      //
      // ANALYSIS_FAILED because §31 has no duplicate code and the client maps
      // it to a retryable service failure, which is the honest advice: results
      // are not stored server-side, so there is nothing to hand back. A client
      // that sends a fresh id per attempt (F06-T14) never lands here.
      logEvent("analyze.duplicate", {
        request_id: requestId,
        request_id_source: requestIdSource,
      });
      throw ApiError.analysisFailed();
    }

    const { body, report } = outcome.value;

    logEvent("analyze.completed", {
      request_id: requestId,
      session_id: parsed.sessionId,
      status: body.status,
      document_type: body.document_type.type,
      counted: outcome.finalize.outcome === "succeeded",
      used_today: outcome.finalize.usedToday,
      daily_limit: config.dailyLimit,
      // Only the text shape's client-supplied candidates can be malformed and
      // dropped (§29); the image shape's candidates are this server's own
      // extractor output, so there is nothing to count here.
      dropped_candidates: parsed.inputType === "text" ? parsed.droppedCandidates : 0,
      dropped_fields: report.dropped.join(",") || null,
      dropped_items: report.droppedItems,
    });

    return jsonResponse(body, { requestId });
  };
}
