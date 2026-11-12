/**
 * F36-T15 · The explain-document handler.
 *
 * The one place the pieces built by T06–T14 are put in order. It owns no rules
 * of its own — every decision below belongs to a module that can be tested on
 * its own — so what this file has to get right is the SEQUENCE.
 *
 * ── Why the order is what it is ──────────────────────────────────────────
 * Each step is cheaper than the one after it, and each one refuses a request
 * that must never reach the next:
 *
 *   1. auth               — nobody unauthenticated may cost us a database round-trip
 *   2. runtime config      — one read; also the two gates below
 *   3. analysisEnabled     — the service-wide kill switch (trap #3: checked FIRST)
 *   4. explainEnabled      — the feature's opt-in flag. A disabled explain while
 *                            analysis is up tells the client it is OUR problem,
 *                            not the caller's — and it is: the pipeline is off
 *   5. parse body          — free, and gates everything below on a valid contract
 *   6. build both chains   — credentials read BEFORE the reservation, so a deploy
 *                            fault (missing key / missing model) costs no slot
 *                            (matrix row A8)
 *   7. hash installation   — cheap, and also before the slot for the same reason
 *   8. reserve slot        — both quotas (the caller's own and the service-wide
 *                            cap) enforced BEFORE the AI is called
 *   9. read                — the reading chain: image → text (10 s budget, D4)
 *  10. explain             — the explaining chain: text → cards (20 s budget, D4)
 *  11. ground              — truth and length enforcement
 *  12. build response      — the reading is NOT in the builder's signature (trap #4)
 *
 * There is deliberately no daily-limit pre-check before the reservation. The
 * reserve is atomic and already answers `limit_reached`; a read-then-reserve
 * would add a round-trip and a race it cannot win (F06-T07).
 *
 * ── Two stages, one budget (D4, §33.8) ──────────────────────────────────
 * `explainTimeoutSeconds` (default 30) is the whole request's budget. The read
 * stage takes its fixed 10 s and the explain stage gets the rest (20 s by
 * default). The slot's TTL is the sum plus the 10 s reservation grace, so a
 * slow-but-successful request always finishes before the slot expires.
 *
 * ── Empty reading (T07's note) ───────────────────────────────────────────
 * An empty reading is an ANSWER, not a failure: a blank page really is blank.
 * But `explain-document` cannot explain nothing, so the handler short-circuits
 * with `status: "unsupported"`, skipping the explain chain and releasing the
 * slot. An honest answer, and it saves a provider call.
 *
 * PRIVACY: nothing derived from the document is logged. Every log line here
 * carries envelope fields, statuses and counts only (§51).
 */

import { ApiError, apiErrorForAuthFailure } from "../errors/api-error.ts";
import { requireUser, type TokenVerifier } from "../auth/require-user.ts";
import type { RuntimeConfig } from "../config/runtime-config.ts";
import type { EndpointHandler } from "../http/endpoint.ts";
import { jsonResponse } from "../http/response.ts";
import type { OcrImage } from "../ai/gemini-ocr-client.ts";
import type { ReadingChain } from "../ai/reading-chain.ts";
import { DEFAULT_READ_STAGE_SECONDS } from "../ai/reading-chain.ts";
import type { ExplainChain } from "../ai/explain-chain.ts";
import { logEvent } from "../observability/log.ts";
import { cairoDayOf, nextCairoResetAfter, toCairoIsoString } from "../time/cairo-day.ts";
import type { SlotStore } from "../usage/slot-reservation.ts";
import { withReservedSlot } from "../usage/slot-reservation.ts";
import { groundExplanation } from "../validators/explain-grounding.ts";
import { parseExplainRequest } from "./explain-request.ts";
import { buildExplainResponse, type BuiltExplainResponse } from "./explain-response.ts";

export interface ExplainDependencies {
  readonly verifyToken: TokenVerifier;
  readonly loadConfig: () => Promise<RuntimeConfig>;
  readonly slots: SlotStore;
  /**
   * Built per request because the time budget comes from runtime config, which
   * an operator can change without a redeploy.
   *
   * Credentials are read inside the factory. The handler calls it BEFORE
   * reserving a slot, so a missing key is a deploy fault that costs no slot.
   *
   * `requestId` correlates the chain's own `explain.read` log line.
   */
  readonly createReader: (
    stageSeconds: number,
    requestId: string,
  ) => ReadingChain;
  /**
   * As {@link createReader}, but for the explain stage. Its log event is
   * `explain.write`, kept apart from the reading stage's.
   */
  readonly createExplainer: (
    stageSeconds: number,
    requestId: string,
  ) => ExplainChain;
  readonly hashInstallation: (installationId: string) => Promise<string>;
  /** Injected so Cairo-day boundaries are testable. */
  readonly now: () => Date;
}

/**
 * How much longer than the AI timeout a slot is held.
 *
 * Must be positive, or a slow-but-successful request would have its slot swept
 * out from under it mid-flight. Must stay small, because until it lapses a
 * crashed request keeps a slot the user cannot use.
 */
const RESERVATION_GRACE_SECONDS = 10;

/**
 * The minimum `explainTimeoutSeconds` that leaves room for both stages.
 * Reading alone needs {@link DEFAULT_READ_STAGE_SECONDS}; explaining needs at
 * least a second on top.
 */
const MIN_EXPLAIN_TIMEOUT_SECONDS = DEFAULT_READ_STAGE_SECONDS + 1;

/** A blank page read server-side: nothing to explain. */
function unsupportedForEmptyReading(): BuiltExplainResponse {
  return {
    body: {
      explain_schema_version: "", // filled by the caller
      session_id: "", // filled by the caller
      status: "unsupported",
      paper: { title: "صورة مش واضحة" },
      explain: ["مقدرتش أقرا حاجة من الصورة دي. جرب صوّر الورقة تاني في مكان منوّر."],
      todo: { required: false, text: "صوّر الورقة تاني في مكان منوّر." },
      date: null,
      caution: null,
      contact: null,
      place: null,
    },
    report: { titleTruncated: false, paragraphsTruncated: 0, paragraphsDropped: 0 },
  };
}

export function createExplainHandler(
  dependencies: ExplainDependencies,
): EndpointHandler {
  const {
    verifyToken,
    loadConfig,
    slots,
    createReader,
    createExplainer,
    hashInstallation,
    now,
  } = dependencies;

  return async ({ request, requestId, requestIdSource }): Promise<Response> => {
    // ── 1. auth ──────────────────────────────────────────────────────────
    const auth = await requireUser(request, verifyToken);
    if (!auth.ok) throw apiErrorForAuthFailure(auth.reason);

    // ── 2. runtime config ────────────────────────────────────────────────
    const config = await loadConfig();

    // ── 3. service-wide kill switch (checked FIRST — trap #3) ────────────
    if (!config.analysisEnabled) throw ApiError.analysisDisabled();

    // ── 4. feature opt-in flag ───────────────────────────────────────────
    if (!config.explainEnabled) throw ApiError.analysisDisabled();

    // ── 5. parse body ────────────────────────────────────────────────────
    let rawBody: unknown;
    try {
      rawBody = await request.json();
    } catch {
      throw ApiError.invalidRequest();
    }
    const parsed = parseExplainRequest(rawBody, config);

    // ── 6. build both chains (credentials read before the slot) ──────────
    const totalSeconds = config.explainTimeoutSeconds;
    if (totalSeconds < MIN_EXPLAIN_TIMEOUT_SECONDS) {
      throw new Error(
        `EXPLAIN_TIMEOUT_SECONDS (${totalSeconds}) must be at least ${MIN_EXPLAIN_TIMEOUT_SECONDS}.`,
      );
    }

    const readStageSeconds = DEFAULT_READ_STAGE_SECONDS;
    const explainStageSeconds = totalSeconds - readStageSeconds;

    const read = createReader(readStageSeconds, requestId);
    const explain = createExplainer(explainStageSeconds, requestId);

    // ── 7. hash installation ─────────────────────────────────────────────
    const instant = now();
    const installationHash = await hashInstallation(parsed.installationId);

    // ── 8. reserve slot ──────────────────────────────────────────────────
    const outcome = await withReservedSlot<BuiltExplainResponse>(
      slots,
      {
        userId: auth.user.id,
        day: cairoDayOf(instant),
        requestId,
        installationHash,
        dailyLimit: config.explainDailyLimit,
        globalDailyCallCap: config.globalDailyCallCap,
        ttlSeconds: totalSeconds + RESERVATION_GRACE_SECONDS,
      },
      async () => {
        // ── 9. read ──────────────────────────────────────────────────────
        const image: OcrImage = {
          bytes: parsed.image.data,
          mimeType: parsed.image.mimeType,
        };
        const reading = await read(image);

        // ── empty reading → unsupported (T07's note) ─────────────────────
        if (reading.text.trim().length === 0) {
          logEvent("explain.empty_reading", { request_id: requestId });
          const empty = unsupportedForEmptyReading();
          return {
            body: {
              ...empty.body,
              explain_schema_version: config.explainSchemaVersion,
              session_id: parsed.sessionId,
            },
            report: empty.report,
          };
        }

        // ── 10. explain ──────────────────────────────────────────────────
        const model = await explain({ readingText: reading.text });

        // ── 11. ground ───────────────────────────────────────────────────
        const { explanation, report: groundingReport } = groundExplanation(
          model,
          reading.text,
        );

        logEvent("explain.grounded", {
          request_id: requestId,
          status: explanation.status,
          ungrounded_phones: groundingReport.ungroundedPhones,
          ungrounded_amounts: groundingReport.ungroundedAmounts,
          ungrounded_dates: groundingReport.ungroundedDates,
          ungrounded_times: groundingReport.ungroundedTimes,
          duplicate_sentences: groundingReport.duplicateSentences,
          labels_cleaned: groundingReport.labelsCleaned,
          medical_claims_removed: groundingReport.medicalClaimsRemoved,
          referrals_added: groundingReport.referralsAdded,
          paragraphs_trimmed: groundingReport.paragraphsTrimmed,
          fits_page: groundingReport.fitsPage,
        });

        // ── 12. build response (trap #4: reading NOT in signature) ───────
        return buildExplainResponse({
          explanation,
          sessionId: parsed.sessionId,
          explainSchemaVersion: config.explainSchemaVersion,
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
        logEvent("explain.global_capacity_reached", {
          request_id: requestId,
          global_daily_call_cap: config.globalDailyCallCap,
          caller_used_today: outcome.reservation.usedToday,
        });
        throw ApiError.globalCapacityReached();
      }

      logEvent("explain.duplicate", {
        request_id: requestId,
        request_id_source: requestIdSource,
      });
      throw ApiError.analysisFailed();
    }

    const { body, report } = outcome.value;

    logEvent("explain.completed", {
      request_id: requestId,
      session_id: parsed.sessionId,
      status: body.status,
      counted: outcome.finalize.outcome === "succeeded",
      used_today: outcome.finalize.usedToday,
      daily_limit: config.explainDailyLimit,
      title_truncated: report.titleTruncated,
      paragraphs_truncated: report.paragraphsTruncated,
      paragraphs_dropped: report.paragraphsDropped,
    });

    return jsonResponse(body, { requestId });
  };
}
