/**
 * F06-T13 · The analyze-document handler.
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
 *   5. reserve slot  — the quota is enforced BEFORE the AI is called, or the
 *                      limit costs us money anyway
 *   6. analyse       — the only expensive step
 *   7. validate      — the model's answer is never returned as-is
 *
 * There is deliberately no daily-limit pre-check before the reservation. The
 * reserve is atomic and already answers `limit_reached`; a read-then-reserve
 * would add a round-trip and a race it cannot win (F06-T07).
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
import { logEvent } from "../observability/log.ts";
import { cairoDayOf, nextCairoResetAfter, toCairoIsoString } from "../time/cairo-day.ts";
import type { SlotStore } from "../usage/slot-reservation.ts";
import { withReservedSlot } from "../usage/slot-reservation.ts";
import { validateAnalysis } from "../validators/validation-pipeline.ts";
import { parseAnalyzeRequest } from "./analyze-request.ts";
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

export function createAnalyzeHandler(
  dependencies: AnalyzeDependencies,
): EndpointHandler {
  const { verifyToken, loadConfig, slots, createAnalyser, hashInstallation, now } = dependencies;

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

    const parsed = parseAnalyzeRequest(rawBody, config);

    const instant = now();
    // Built before the reservation: a missing GROQ_API_KEY is a deploy fault,
    // and it must not burn a slot to discover it.
    const analyse = createAnalyser(config.aiTimeoutSeconds);
    const installationHash = await hashInstallation(parsed.installationId);

    const outcome = await withReservedSlot<BuiltAnalysisResponse>(
      slots,
      {
        userId: auth.user.id,
        day: cairoDayOf(instant),
        requestId,
        installationHash,
        dailyLimit: config.dailyLimit,
        ttlSeconds: config.aiTimeoutSeconds + RESERVATION_GRACE_SECONDS,
      },
      async () => {
        const model = await analyse({
          ocrText: parsed.ocrText,
          detectedLanguages: parsed.detectedLanguages,
          candidates: parsed.candidates,
        });

        const validated = validateAnalysis({
          analysis: model,
          ocrText: parsed.ocrText,
          candidates: parsed.candidates,
          now: instant,
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
      dropped_candidates: parsed.droppedCandidates,
      dropped_fields: report.dropped.join(",") || null,
      dropped_items: report.droppedItems,
    });

    return jsonResponse(body, { requestId });
  };
}
