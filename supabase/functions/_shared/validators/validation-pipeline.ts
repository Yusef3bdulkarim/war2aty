/**
 * F06-T12 · The validation pipeline (§34).
 *
 * Groq's answer is never returned to the app as-is. Schema-constrained output
 * guarantees the SHAPE; this stage is the only thing that says anything about
 * the TRUTH — whether the values are actually on the page the user
 * photographed.
 *
 * ── How "needs review" is expressed ──────────────────────────────────────
 * §34 asks for `verificationStatus = not_verified` and `needsUserReview = true`.
 * API_CONTRACT §30 has neither field, and sets `additionalProperties: false`,
 * so emitting them would fail validation on the device. The contract's own
 * mechanism is `confidence`, and §30.5 already defines exactly the behaviour
 * §34 wants:
 *
 *   low → the client shows «قراءة غير مؤكدة» and makes the value editable.
 *
 * So an unverified fact is DOWNGRADED to `low`, never deleted. Deleting it
 * would be the worse failure: the user would never learn the paper says
 * something we could not confirm, and they would have no way to correct it.
 *
 * The document is also marked `partial` and the field named in `missing_fields`
 * so the result screen shows its review banner.
 *
 * PRIVACY: the report counts what was downgraded, never what it contained.
 * Field names are contract labels, not document content, so they are safe to
 * log (§51).
 */

import type { ModelAnalysis, ModelWarning } from "../schemas/groq-output.schema.ts";
import type { ExtractedCandidates } from "../prompts/analysis-prompt.ts";
import { verifyDate } from "./date-validator.ts";
import type { VerificationSources } from "./number-validator.ts";
import { isNumberVerified } from "./number-validator.ts";
import { isSourceClaimSupported } from "./source-validator.ts";
import {
  hasWarningOfType,
  isContradictoryUnsupported,
  isPlausibleAmount,
  mayDriveReminder,
  requiredWarningFor,
} from "./business-validator.ts";

/** What the pipeline changed. Counts and field names only — no values. */
export interface ValidationReport {
  readonly downgraded: string[];
  readonly droppedAmounts: number;
  readonly clearedReminders: number;
  readonly addedWarnings: ModelWarning["type"][];
  readonly statusChanged: boolean;
}

export interface ValidationResult {
  readonly analysis: ModelAnalysis;
  readonly report: ValidationReport;
}

export interface ValidationInput {
  readonly analysis: ModelAnalysis;
  readonly ocrText: string;
  readonly candidates: ExtractedCandidates;
  /** Injected so "is this in the past" is testable. */
  readonly now: Date;
}

/** Lowering only: verification can never raise the model's own confidence. */
function downgrade<T extends { confidence: "high" | "medium" | "low" }>(
  item: T,
): T {
  return { ...item, confidence: "low" };
}

export function validateAnalysis(input: ValidationInput): ValidationResult {
  const { analysis, ocrText, candidates, now } = input;
  const sources: VerificationSources = { ocrText, candidates };

  const downgraded: string[] = [];
  const addedWarnings: ModelWarning["type"][] = [];
  let clearedReminders = 0;

  // ── Numbers: every amount must be on the page ──────────────────────────
  const plausibleAmounts = analysis.amounts.filter(isPlausibleAmount);
  const droppedAmounts = analysis.amounts.length - plausibleAmounts.length;

  const amounts = plausibleAmounts.map((amount) => {
    if (isNumberVerified(amount.value, sources)) return amount;
    downgraded.push("amounts");
    return downgrade(amount);
  });

  // ── Sources: an "extracted" claim must be supported ────────────────────
  const keyInformation = analysis.key_information.map((item) => {
    if (isSourceClaimSupported(item, sources)) return item;
    downgraded.push("key_information");
    // Re-label as inferred: it was not read from the page, whatever the model
    // asserted, and the client shows a basis indicator for inferred values.
    return { ...downgrade(item), source: "inferred" as const };
  });

  // ── Dates: format, traceability, and reminder sanity ───────────────────
  const dates = analysis.dates.map((date) => {
    const verdict = verifyDate(date, sources, now);
    let result = date;

    if (!verdict.wellFormed || !verdict.traceable || !verdict.timeSupported) {
      downgraded.push("dates");
      result = downgrade(result);
    }

    // A time the page never stated is worse than no time: F09 would schedule
    // a notification at an hour nobody chose.
    if (!verdict.timeSupported) {
      result = { ...result, time: null };
    }

    if (result.is_reminder_worthy && !mayDriveReminder(date, verdict.inPast)) {
      clearedReminders += 1;
      result = { ...result, is_reminder_worthy: false };
    }

    return result;
  });

  // ── Safety: the warning a document type must carry ─────────────────────
  const warnings = [...analysis.warnings];
  const required = requiredWarningFor(analysis.document_type.type);
  if (required !== null && !hasWarningOfType(analysis, required.type)) {
    warnings.push(required);
    addedWarnings.push(required.type);
  }

  // ── Status: keep it honest about what happened ─────────────────────────
  const missingFields = Array.from(
    new Set([...analysis.missing_fields, ...downgraded]),
  );

  let status = analysis.status;
  if (isContradictoryUnsupported(analysis)) {
    // It says it could not read the document; believe that over its facts.
    status = "unsupported";
  } else if (status === "success" && missingFields.length > 0) {
    // `success` would render without the review banner, hiding the fact that
    // some values could not be confirmed.
    status = "partial";
  }

  return {
    analysis: {
      ...analysis,
      status,
      amounts,
      key_information: keyInformation,
      dates,
      warnings,
      missing_fields: missingFields,
    },
    report: {
      downgraded,
      droppedAmounts,
      clearedReminders,
      addedWarnings,
      statusChanged: status !== analysis.status,
    },
  };
}
