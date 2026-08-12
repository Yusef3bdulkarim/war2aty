/**
 * F13-T08 · Tests for the cross-provider validator.
 *
 * No network, no Azure/Google clients — both functions under test are pure
 * over `CandidateVerification`/`ExtractedCandidates` shapes. Fixtures build
 * only the fields each test cares about; the rest come from `emptyCandidates`
 * / `verifiedEverything`.
 */

import { assertEquals } from "jsr:@std/assert@1";

import type {
  AmountCandidate,
  DateCandidate,
  ExtractedCandidates,
} from "../../functions/_shared/prompts/analysis-prompt.ts";
import type {
  CandidateVerification,
  FieldVerdict,
} from "../../functions/_shared/verification/field-verification.ts";
import {
  mergeProviderVerification,
  needsGoogleSecondOpinion,
} from "../../functions/_shared/verification/cross-provider-validator.ts";

// ── fixtures ────────────────────────────────────────────────────────────

function emptyCandidates(overrides: Partial<ExtractedCandidates> = {}): ExtractedCandidates {
  return {
    dates: [],
    times: [],
    amounts: [],
    phones: [],
    references: [],
    ...overrides,
  };
}

function emptyVerification(overrides: Partial<CandidateVerification> = {}): CandidateVerification {
  return {
    dates: [],
    times: [],
    amounts: [],
    phones: [],
    references: [],
    ...overrides,
  };
}

const VERIFIED: FieldVerdict = { status: "verified", confidence: 0.97 };
const UNVERIFIED: FieldVerdict = { status: "unverified", confidence: 0.4 };
const CONFLICTING: FieldVerdict = { status: "conflicting", confidence: 0.97 };
const UNLOCATABLE: FieldVerdict = { status: "unverified", confidence: null };

// ── needsGoogleSecondOpinion ────────────────────────────────────────────

Deno.test("no second opinion needed when every date and amount is verified", () => {
  const azure = emptyVerification({ dates: [VERIFIED], amounts: [VERIFIED] });
  assertEquals(needsGoogleSecondOpinion(azure), false);
});

Deno.test("an unverified date alone triggers a second opinion", () => {
  const azure = emptyVerification({ dates: [UNVERIFIED] });
  assertEquals(needsGoogleSecondOpinion(azure), true);
});

Deno.test("a conflicting amount alone triggers a second opinion", () => {
  const azure = emptyVerification({ amounts: [CONFLICTING] });
  assertEquals(needsGoogleSecondOpinion(azure), true);
});

Deno.test("an unlocatable (null-confidence) critical field triggers a second opinion", () => {
  const azure = emptyVerification({ amounts: [UNLOCATABLE] });
  assertEquals(needsGoogleSecondOpinion(azure), true);
});

Deno.test("non-critical fields never trigger a second opinion on their own", () => {
  const azure = emptyVerification({
    times: [UNVERIFIED],
    phones: [CONFLICTING],
    references: [UNLOCATABLE],
    dates: [VERIFIED],
    amounts: [VERIFIED],
  });
  assertEquals(needsGoogleSecondOpinion(azure), false);
});

Deno.test("no candidates at all needs no second opinion", () => {
  assertEquals(needsGoogleSecondOpinion(emptyVerification()), false);
});

// ── mergeProviderVerification: verified fields never need review ──────────

Deno.test("a verified Azure field never needs review, with or without Google", () => {
  const amounts: AmountCandidate[] = [
    { raw_text: "150 EGP", value: 150, currency: "EGP", is_ambiguous: false },
  ];
  const azureCandidates = emptyCandidates({ amounts });
  const azureVerification = emptyVerification({ amounts: [VERIFIED] });

  const withoutGoogle = mergeProviderVerification({
    azureCandidates,
    azureVerification,
    googleCandidates: null,
  });
  assertEquals(withoutGoogle.amounts, [{ status: "verified", needsUserReview: false }]);
  assertEquals(withoutGoogle.needsUserReview, false);

  const withDisagreeingGoogle = mergeProviderVerification({
    azureCandidates,
    azureVerification,
    googleCandidates: emptyCandidates({
      amounts: [{ raw_text: "200 EGP", value: 200, currency: "EGP", is_ambiguous: false }],
    }),
  });
  assertEquals(withDisagreeingGoogle.amounts, [{ status: "verified", needsUserReview: false }]);
});

// ── mergeProviderVerification: unconfirmed, no Google consulted ───────────

Deno.test("an unverified field with no Google consultation stays flagged for review", () => {
  const dates: DateCandidate[] = [
    { raw_text: "05/06/2026", normalized_date: "2026-06-05", is_ambiguous: true },
  ];
  const result = mergeProviderVerification({
    azureCandidates: emptyCandidates({ dates }),
    azureVerification: emptyVerification({ dates: [UNVERIFIED] }),
    googleCandidates: null,
  });

  assertEquals(result.dates, [{ status: "unverified", needsUserReview: true }]);
  assertEquals(result.needsUserReview, true);
});

// ── mergeProviderVerification: corroborated by Google ──────────────────────

Deno.test("Google independently reporting the same normalized date clears the review flag", () => {
  const dates: DateCandidate[] = [
    { raw_text: "05/06/2026", normalized_date: "2026-06-05", is_ambiguous: true },
  ];
  const googleDates: DateCandidate[] = [
    { raw_text: "5 يونيو 2026", normalized_date: "2026-06-05", is_ambiguous: false },
  ];

  const result = mergeProviderVerification({
    azureCandidates: emptyCandidates({ dates }),
    azureVerification: emptyVerification({ dates: [CONFLICTING] }),
    googleCandidates: emptyCandidates({ dates: googleDates }),
  });

  assertEquals(result.dates, [{ status: "conflicting", needsUserReview: false }]);
  assertEquals(result.needsUserReview, false);
});

Deno.test("Google reporting a different value leaves the review flag set", () => {
  const amounts: AmountCandidate[] = [
    { raw_text: "إجمالي 1250", value: 1250, currency: null, is_ambiguous: true },
  ];
  const googleAmounts: AmountCandidate[] = [
    { raw_text: "إجمالي 1205", value: 1205, currency: null, is_ambiguous: true },
  ];

  const result = mergeProviderVerification({
    azureCandidates: emptyCandidates({ amounts }),
    azureVerification: emptyVerification({ amounts: [UNVERIFIED] }),
    googleCandidates: emptyCandidates({ amounts: googleAmounts }),
  });

  assertEquals(result.amounts, [{ status: "unverified", needsUserReview: true }]);
  assertEquals(result.needsUserReview, true);
});

Deno.test("a candidate with no comparable normalized value can never be corroborated", () => {
  const amounts: AmountCandidate[] = [
    { raw_text: "مبلغ غير واضح", value: null, currency: null, is_ambiguous: true },
  ];
  const result = mergeProviderVerification({
    azureCandidates: emptyCandidates({ amounts }),
    azureVerification: emptyVerification({ amounts: [UNVERIFIED] }),
    googleCandidates: emptyCandidates({
      amounts: [{ raw_text: "أي مبلغ", value: null, currency: null, is_ambiguous: true }],
    }),
  });

  assertEquals(result.amounts, [{ status: "unverified", needsUserReview: true }]);
});

// ── needsUserReview rolls up across every field group ─────────────────────

Deno.test("overall needsUserReview is true if any single field of any type is flagged", () => {
  const phones = [
    { raw_text: "01001234567", normalized_number: "01001234567", is_ambiguous: false },
  ];
  const result = mergeProviderVerification({
    azureCandidates: emptyCandidates({ phones }),
    azureVerification: emptyVerification({ phones: [UNVERIFIED] }),
    googleCandidates: null,
  });

  assertEquals(result.needsUserReview, true);
});

Deno.test("overall needsUserReview is false when nothing at all was flagged", () => {
  const result = mergeProviderVerification({
    azureCandidates: emptyCandidates(),
    azureVerification: emptyVerification(),
    googleCandidates: null,
  });

  assertEquals(result.needsUserReview, false);
});

// ── index alignment with the candidates that were merged ──────────────────

Deno.test("every merged group is index-aligned with its Azure candidate array", () => {
  const azureCandidates = emptyCandidates({
    dates: [{ raw_text: "01/01/2026", normalized_date: "2026-01-01", is_ambiguous: true }],
    amounts: [
      { raw_text: "100 EGP", value: 100, currency: "EGP", is_ambiguous: false },
      { raw_text: "200 EGP", value: 200, currency: "EGP", is_ambiguous: false },
    ],
  });
  const azureVerification = emptyVerification({
    dates: [VERIFIED],
    amounts: [VERIFIED, UNVERIFIED],
  });

  const result = mergeProviderVerification({
    azureCandidates,
    azureVerification,
    googleCandidates: null,
  });

  assertEquals(result.dates.length, 1);
  assertEquals(result.amounts.length, 2);
  assertEquals(result.times.length, 0);
});
