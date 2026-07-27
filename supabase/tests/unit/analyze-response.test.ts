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

function build(overrides: Parameters<typeof modelAnalysis>[0] = {}) {
  return buildAnalysisResponse({
    analysis: modelAnalysis(overrides),
    sessionId: SESSION_ID,
    schemaVersion: "1.0",
  });
}

Deno.test("a clean analysis passes through with the envelope filled in", () => {
  const { body, report } = build();

  assertEquals(body.schema_version, "1.0");
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
