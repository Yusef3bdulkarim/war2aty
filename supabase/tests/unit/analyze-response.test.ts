/**
 * F06-T13 · Tests for the §30 response builder.
 *
 * The stakes: the Flutter mapper throws on a `dates[].date` it cannot parse and
 * the repository turns that into a failure for the WHOLE body. So each of these
 * is really asking "would this response have destroyed a good analysis on
 * someone's phone?".
 */

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import { buildAnalysisResponse } from "../../functions/_shared/analyze/analyze-response.ts";
import { ApiError } from "../../functions/_shared/errors/api-error.ts";
import { modelAnalysis, SESSION_ID } from "../fixtures/analyze-fixtures.ts";
import type { ExtractedCandidates } from "../../functions/_shared/prompts/analysis-prompt.ts";
import type { CrossProviderVerification } from "../../functions/_shared/verification/cross-provider-validator.ts";

function build(
  overrides: Parameters<typeof modelAnalysis>[0] = {},
  extra: {
    candidates?: ExtractedCandidates;
    verification?: CrossProviderVerification | null;
  } = {},
) {
  return buildAnalysisResponse({
    analysis: modelAnalysis(overrides),
    sessionId: SESSION_ID,
    schemaVersion: "2.0",
    ...extra,
  });
}

Deno.test("a clean analysis passes through with the envelope filled in", () => {
  const { body, report } = build();

  assertEquals(body.schema_version, "2.0");
  assertEquals(body.session_id, SESSION_ID);
  assertEquals(body.status, "success");
  assertEquals(body.document_type.type, "invoice");
  assertEquals(body.dates.length, 1);
  assertEquals(body.amounts.length, 1);
  assertEquals(report.dropped, []);
  assertEquals(report.droppedItems, 0);
});

Deno.test("every §30 array is present even when empty", () => {
  // The client iterates them unconditionally; a missing key is a crash.
  const { body } = build({
    key_information: [],
    dates: [],
    amounts: [],
    actions_required: [],
    warnings: [],
    instructions: [],
    required_documents: [],
  });

  for (
    const key of [
      "key_information",
      "dates",
      "amounts",
      "actions_required",
      "required_documents",
      "instructions",
      "warnings",
      "missing_fields",
    ] as const
  ) {
    assert(Array.isArray(body[key]), `${key} must be an array`);
  }
});

// ── dates: the field that can destroy a whole response ────────────────────

Deno.test("a date the client could not parse is dropped, not sent", () => {
  const { body, report } = build({
    dates: [
      {
        label: "آخر موعد",
        date: "next Tuesday",
        time: null,
        role: "deadline",
        is_reminder_worthy: true,
        confidence: "low",
      },
    ],
  });

  assertEquals(body.dates, []);
  assert(report.dropped.includes("dates"));
  // Named, so the result screen tells the user something is missing.
  assert(body.missing_fields.includes("dates"));
});

Deno.test("a date that does not exist on the calendar is dropped", () => {
  // 2026 is not a leap year; the client's mapper rejects this too.
  const { body } = build({
    dates: [
      {
        label: "موعد",
        date: "2026-02-29",
        time: null,
        role: "appointment",
        is_reminder_worthy: true,
        confidence: "high",
      },
    ],
  });

  assertEquals(body.dates, []);
});

Deno.test("an unknown date role is dropped rather than guessed", () => {
  // Downgrading a deadline to a generic event could cost the user a payment.
  const { body } = build({
    dates: [
      {
        label: "موعد",
        date: "2026-08-15",
        time: null,
        role: "renewal",
        is_reminder_worthy: true,
        confidence: "high",
      },
    ],
  });

  assertEquals(body.dates, []);
});

Deno.test("a malformed time is nulled but the date survives", () => {
  const { body } = build({
    dates: [
      {
        label: "آخر موعد للسداد",
        date: "2026-08-15",
        time: "2:30 pm",
        role: "deadline",
        is_reminder_worthy: true,
        confidence: "high",
      },
    ],
  });

  assertEquals(body.dates.length, 1);
  assertEquals(body.dates[0].time, null);
  assertEquals(body.dates[0].date, "2026-08-15");
});

Deno.test("a non-boolean is_reminder_worthy never schedules a reminder", () => {
  const { body } = build({
    dates: [
      {
        label: "آخر موعد",
        date: "2026-08-15",
        time: null,
        role: "deadline",
        is_reminder_worthy: "yes" as unknown as boolean,
        confidence: "high",
      },
    ],
  });

  assertEquals(body.dates[0].is_reminder_worthy, false);
});

// ── the other collections ─────────────────────────────────────────────────

Deno.test("an amount with no currency is dropped rather than given one", () => {
  // Defaulting a currency would be inventing a fact about someone's money.
  const { body, report } = build({
    amounts: [{ label: "إجمالي", value: 850.5, currency: "  ", confidence: "high" }],
  });

  assertEquals(body.amounts, []);
  assert(report.dropped.includes("amounts"));
});

Deno.test("a non-finite amount is dropped", () => {
  const { body } = build({
    amounts: [
      { label: "إجمالي", value: Number.NaN, currency: "جنيه", confidence: "high" },
    ],
  });

  assertEquals(body.amounts, []);
});

Deno.test("blank labels and values are dropped, since §30 requires minLength 1", () => {
  const { body } = build({
    key_information: [
      { label: "", value: "12345678", confidence: "high", source: "extracted" },
      { label: "رقم الحساب", value: "   ", confidence: "high", source: "extracted" },
      { label: "المصدر", value: "شركة الكهرباء", confidence: "high", source: "extracted" },
    ],
    instructions: ["", "  ", "سدد عبر فوري."],
    required_documents: [""],
  });

  assertEquals(body.key_information.length, 1);
  assertEquals(body.instructions, ["سدد عبر فوري."]);
  assertEquals(body.required_documents, []);
});

Deno.test("unknown enum values are coerced to the cautious default", () => {
  const { body } = build({
    document_type: { type: "utility", title: "فاتورة", confidence: "certain" as never },
    key_information: [
      { label: "رقم", value: "1", confidence: "sure" as never, source: "read" as never },
    ],
    actions_required: [
      { description: "سدد.", basis: "guessed" as never, priority: "urgent" as never },
    ],
    warnings: [{ text: "تحذير", type: "safety" as never }],
  });

  assertEquals(body.document_type.type, "other");
  // Unknown confidence reads as low, so the value shows as «قراءة غير مؤكدة».
  assertEquals(body.document_type.confidence, "low");
  assertEquals(body.key_information[0].source, "inferred");
  assertEquals(body.actions_required[0].basis, "inferred");
  assertEquals(body.actions_required[0].priority, "normal");
  assertEquals(body.warnings[0].type, "general");
});

// ── summary ───────────────────────────────────────────────────────────────

Deno.test("an over-long short summary is truncated to §30's 200 characters", () => {
  const long = "ا".repeat(180) + " " + "ب".repeat(100);
  const { body, report } = build({
    summary: { short: long, detailed: "الشرح الكامل موجود هنا." },
  });

  assert(body.summary.short.length <= 200);
  assertEquals(report.truncatedSummary, true);
  // `detailed` is untouched — nothing is actually lost.
  assertEquals(body.summary.detailed, "الشرح الكامل موجود هنا.");
});

Deno.test("a blank title or summary fails the analysis instead of shipping a blank screen", () => {
  for (
    const overrides of [
      { document_type: { type: "invoice", title: "  ", confidence: "high" as const } },
      { summary: { short: "", detailed: "شرح" } },
      { summary: { short: "ملخص", detailed: "  " } },
    ]
  ) {
    const error = assertThrows(
      () => build(overrides),
      ApiError,
    ) as ApiError;
    // Thrown inside the reserved slot, so the user is not charged for it.
    assertEquals(error.code, "ANALYSIS_FAILED");
  }
});

// ── status ────────────────────────────────────────────────────────────────

Deno.test("a success that lost fields is downgraded to partial", () => {
  // Otherwise the result screen renders without its review banner — exactly the
  // case the banner exists for.
  const { body, report } = build({
    status: "success",
    amounts: [{ label: "", value: 1, currency: "جنيه", confidence: "high" }],
  });

  assertEquals(body.status, "partial");
  assertEquals(report.statusChanged, true);
});

Deno.test("an unsupported status is never promoted", () => {
  const { body } = build({
    status: "unsupported",
    key_information: [],
    dates: [],
    amounts: [],
  });

  assertEquals(body.status, "unsupported");
});

Deno.test("missing_fields is deduplicated across the model's list and ours", () => {
  const { body } = build({
    missing_fields: ["amounts", "  ", "dates"],
    amounts: [{ label: "", value: 1, currency: "جنيه", confidence: "high" }],
  });

  assertEquals(body.missing_fields, ["amounts", "dates"]);
});

// ── rawValue (§30 v2, F13-T09) ─────────────────────────────────────────────

const CANDIDATES_WITH_MATCHES: ExtractedCandidates = {
  dates: [
    { raw_text: "15/8/2026", normalized_date: "2026-08-15", is_ambiguous: false },
  ],
  times: [],
  amounts: [
    { raw_text: "850.50 جنيه", value: 850.5, currency: "EGP", is_ambiguous: false },
  ],
  phones: [],
  references: [],
};

Deno.test("rawValue is the candidate's literal text when one matches", () => {
  const { body } = build({}, { candidates: CANDIDATES_WITH_MATCHES });

  assertEquals(body.dates[0].rawValue, "15/8/2026");
  assertEquals(body.amounts[0].rawValue, "850.50 جنيه");
});

Deno.test("rawValue is null without a matching candidate — never invented", () => {
  const { body } = build();

  assertEquals(body.dates[0].rawValue, null);
  assertEquals(body.amounts[0].rawValue, null);
});

Deno.test("rawValue is null when the candidate's normalized value differs", () => {
  const mismatched: ExtractedCandidates = {
    ...CANDIDATES_WITH_MATCHES,
    dates: [
      { raw_text: "some other date", normalized_date: "2026-01-01", is_ambiguous: false },
    ],
  };
  const { body } = build({}, { candidates: mismatched });

  assertEquals(body.dates[0].rawValue, null);
});

// ── phones / references (§30 v2, F13-T09) ──────────────────────────────────

const CANDIDATES_WITH_PHONE_AND_REFERENCE: ExtractedCandidates = {
  dates: [],
  times: [],
  amounts: [],
  phones: [
    { raw_text: "0100-123-4567", normalized_number: "01001234567", is_ambiguous: false },
  ],
  references: [
    { raw_text: "رقم الفاتورة 12345678", value: "12345678", is_ambiguous: true },
  ],
};

Deno.test("phones and references stay empty without verification, even with candidates", () => {
  // No cross-provider verification ran (today's only caller, and the
  // offline path even once F13-T11 lands) — a raw regex hit must never
  // surface as if something had confirmed it.
  const { body } = build({}, { candidates: CANDIDATES_WITH_PHONE_AND_REFERENCE });

  assertEquals(body.phones, []);
  assertEquals(body.references, []);
});

Deno.test("phones and references populate once verification is provided", () => {
  const verification: CrossProviderVerification = {
    dates: [],
    times: [],
    amounts: [],
    phones: [{ status: "verified", needsUserReview: false }],
    references: [{ status: "unverified", needsUserReview: true }],
    needsUserReview: true,
  };

  const { body } = build(
    {},
    { candidates: CANDIDATES_WITH_PHONE_AND_REFERENCE, verification },
  );

  assertEquals(body.phones, [
    { rawValue: "0100-123-4567", value: "01001234567", needsUserReview: false },
  ]);
  assertEquals(body.references, [
    { rawValue: "رقم الفاتورة 12345678", value: "12345678", needsUserReview: true },
  ]);
});

Deno.test("verificationStatus never appears on a phone or reference item", () => {
  // Locked decision #6: verificationStatus stays backend-only even though
  // needsUserReview is fair to put on the wire.
  const verification: CrossProviderVerification = {
    dates: [],
    times: [],
    amounts: [],
    phones: [{ status: "verified", needsUserReview: false }],
    references: [{ status: "conflicting", needsUserReview: true }],
    needsUserReview: true,
  };

  const { body } = build(
    {},
    { candidates: CANDIDATES_WITH_PHONE_AND_REFERENCE, verification },
  );

  assertEquals(Object.keys(body.phones[0]).sort(), ["needsUserReview", "rawValue", "value"]);
  assertEquals(
    Object.keys(body.references[0]).sort(),
    ["needsUserReview", "rawValue", "value"],
  );
});
