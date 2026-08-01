/**
 * F13-T08 · Cross-provider validator.
 *
 * T06's `verifyCandidates` (`./field-verification.ts`) asks whether Azure's
 * own extraction can be trusted, using signals Azure alone provides. This
 * module is the layer above it: it decides whether that trust is enough, and
 * if not, whether a second, independent read from Google closes the gap.
 * Nothing else in the pipeline makes either call — the "when to spend a
 * Google request" decision and the "did the two providers agree" merge both
 * live here (§ Locked decisions #1, #4), so both are testable without a
 * network and without either provider's SDK.
 *
 * ── When Google gets called ────────────────────────────────────────────
 * Only `dates`/`amounts` gate the call. They are the two things the app
 * exists to get right — a missed deadline, a wrong bill — so a "missing,
 * invalid or low-confidence" reading on one of them (§ Locked decisions #1)
 * is worth the extra request. `times`/`phones`/`references` support those two
 * but never trigger a call on their own.
 *
 * ── How agreement is judged ─────────────────────────────────────────────
 * Google's client (T07) returns whole-document text only, not per-word
 * confidence — a whole-document resend has no crop to score confidence
 * against. So corroboration is judged the same way T06 groups candidates
 * under one label: by normalized value. If Azure's unconfirmed candidate's
 * normalized value also comes out of running the same T05 extractors over
 * Google's text, the two providers agree independently and the field no
 * longer needs the user's eyes. If they disagree, or Google was never
 * called, the doubt stands.
 *
 * `needsUserReview` only ever turns doubt off when a second, independent
 * provider confirms — it can never turn doubt on for something Azure alone
 * already verified (§06 field-verification.ts: "verification only ever
 * lowers trust, never raises it").
 *
 * `VerificationStatus` itself is never rewritten here — T06 already decided
 * it, and T08 only adds the one new flag on top. This module's output feeds
 * `validateAnalysis` (`../validators/validation-pipeline.ts`) as a peer input
 * alongside `candidates`, and T10's Groq prompt — never the wire (locked
 * decision #6 keeps verification concepts backend-only).
 *
 * PRIVACY (§7, §51): never log a span, a raw value, or a normalized value.
 */

import type {
  AmountCandidate,
  DateCandidate,
  ExtractedCandidates,
  PhoneCandidate,
  ReferenceCandidate,
  TimeCandidate,
} from "../prompts/analysis-prompt.ts";
import type {
  CandidateVerification,
  FieldVerdict,
  VerificationStatus,
} from "./field-verification.ts";

export type CriticalFieldType = "dates" | "amounts";

/** The only field types that can trigger a Google second opinion. */
export const CRITICAL_FIELD_TYPES: readonly CriticalFieldType[] = ["dates", "amounts"];

export interface CrossProviderFieldVerdict {
  /** T06's verdict, carried through unchanged. */
  readonly status: VerificationStatus;
  /** The one decision this module adds: should the UI ask the user to check this value. */
  readonly needsUserReview: boolean;
}

/** Index-aligned with `ExtractedCandidates` — same order, same lengths, same contract as `CandidateVerification`. */
export interface CrossProviderVerification {
  readonly dates: readonly CrossProviderFieldVerdict[];
  readonly times: readonly CrossProviderFieldVerdict[];
  readonly amounts: readonly CrossProviderFieldVerdict[];
  readonly phones: readonly CrossProviderFieldVerdict[];
  readonly references: readonly CrossProviderFieldVerdict[];
  /** True when any field above needs review — the single flag T10/T11 actually branch on. */
  readonly needsUserReview: boolean;
}

/**
 * Whether Azure's own extraction leaves a critical field unconfirmed:
 * missing (unlocatable, `confidence: null`), invalid (`conflicting`), or
 * low-confidence (`unverified`) — everything short of `verified`.
 */
export function needsGoogleSecondOpinion(azure: CandidateVerification): boolean {
  return CRITICAL_FIELD_TYPES.some((type) =>
    azure[type].some((verdict) => verdict.status !== "verified")
  );
}

export interface MergeProviderVerificationInput {
  readonly azureCandidates: ExtractedCandidates;
  readonly azureVerification: CandidateVerification;
  /**
   * Google's own extraction of its resent document, run through the same T05
   * extractors. Null when Google was not consulted (not needed, or the call
   * itself failed) — a field Azure could not confirm then simply needs review.
   */
  readonly googleCandidates: ExtractedCandidates | null;
}

export function mergeProviderVerification(
  input: MergeProviderVerificationInput,
): CrossProviderVerification {
  const { azureCandidates, azureVerification, googleCandidates } = input;

  const dates = mergeGroup(
    azureCandidates.dates,
    azureVerification.dates,
    googleCandidates?.dates ?? null,
    dateValue,
  );
  const times = mergeGroup(
    azureCandidates.times,
    azureVerification.times,
    googleCandidates?.times ?? null,
    timeValue,
  );
  const amounts = mergeGroup(
    azureCandidates.amounts,
    azureVerification.amounts,
    googleCandidates?.amounts ?? null,
    amountValue,
  );
  const phones = mergeGroup(
    azureCandidates.phones,
    azureVerification.phones,
    googleCandidates?.phones ?? null,
    phoneValue,
  );
  const references = mergeGroup(
    azureCandidates.references,
    azureVerification.references,
    googleCandidates?.references ?? null,
    referenceValue,
  );

  const needsUserReview = [dates, times, amounts, phones, references].some((group) =>
    group.some((verdict) => verdict.needsUserReview)
  );

  return { dates, times, amounts, phones, references, needsUserReview };
}

// ── the shared merge algorithm, parameterised per candidate type ──────────

function mergeGroup<T>(
  azureCandidates: readonly T[],
  azureVerdicts: readonly FieldVerdict[],
  googleCandidates: readonly T[] | null,
  normalizedValue: (candidate: T) => string | null,
): CrossProviderFieldVerdict[] {
  return azureCandidates.map((candidate, i) => {
    const verdict = azureVerdicts[i];

    if (verdict.status === "verified") {
      return { status: verdict.status, needsUserReview: false };
    }

    if (googleCandidates === null) {
      return { status: verdict.status, needsUserReview: true };
    }

    const value = normalizedValue(candidate);
    const corroborated = value !== null &&
      googleCandidates.some((g) => normalizedValue(g) === value);

    return { status: verdict.status, needsUserReview: !corroborated };
  });
}

// ── per-type normalisers — the same comparison T06 groups candidates by ───

function dateValue(c: DateCandidate): string | null {
  return c.normalized_date ?? null;
}

function timeValue(c: TimeCandidate): string {
  return `${c.hour}:${c.minute}`;
}

function amountValue(c: AmountCandidate): string | null {
  return c.value === null || c.value === undefined ? null : String(c.value);
}

function phoneValue(c: PhoneCandidate): string {
  return c.normalized_number;
}

function referenceValue(c: ReferenceCandidate): string {
  return c.value;
}
