/**
 * F06-T12 · Tests for the validation pipeline.
 *
 * The question every one of these asks: could a value the model invented reach
 * the user looking like a fact?
 */

import { assert, assertEquals } from "jsr:@std/assert@1";

import type { ExtractedCandidates } from "../../functions/_shared/prompts/analysis-prompt.ts";
import type { ModelAnalysis } from "../../functions/_shared/schemas/groq-output.schema.ts";
import { validateAnalysis } from "../../functions/_shared/validators/validation-pipeline.ts";
import {
  containsDigitSequence,
  containsNumber,
  extractNumbers,
  normaliseDigits,
} from "../../functions/_shared/validators/text-matching.ts";
import {
  isDateTraceable,
  isWellFormedDate,
  isWellFormedTime,
} from "../../functions/_shared/validators/date-validator.ts";
import { requiredWarningFor } from "../../functions/_shared/validators/business-validator.ts";

const NOW = new Date("2026-07-26T12:00:00Z");

const NO_CANDIDATES: ExtractedCandidates = {
  dates: [],
  times: [],
  amounts: [],
  phones: [],
  references: [],
};

const BILL_TEXT = [
  "شركة جنوب القاهرة لتوزيع الكهرباء",
  "رقم الحساب: 12345678",
  "قيمة الفاتورة: 850.50 جنيه",
  "آخر موعد للسداد: 2026/09/15",
].join("\n");

function analysis(overrides: Partial<ModelAnalysis> = {}): ModelAnalysis {
  return {
    status: "success",
    document_type: { type: "invoice", title: "فاتورة كهرباء", confidence: "high" },
    summary: { short: "فاتورة", detailed: "تفاصيل" },
    key_information: [],
    dates: [],
    amounts: [],
    actions_required: [],
    required_documents: [],
    instructions: [],
    warnings: [],
    missing_fields: [],
    ...overrides,
  };
}

function run(model: ModelAnalysis, ocrText = BILL_TEXT, candidates = NO_CANDIDATES) {
  return validateAnalysis({ analysis: model, ocrText, candidates, now: NOW });
}

// ── text matching ─────────────────────────────────────────────────────────

Deno.test("Arabic-Indic digits normalise to Western", () => {
  assertEquals(normaliseDigits("٨٥٠٫٥٠"), "850٫50");
  assertEquals(normaliseDigits("۱۲۳"), "123");
});

Deno.test("numbers are extracted through separators", () => {
  assertEquals(extractNumbers("المبلغ 1,250.75 جنيه"), [1250.75]);
  assertEquals(extractNumbers("٨٥٠٫٥٠"), [850.5]);
});

Deno.test("a printed 850.50 matches a reported 850.5", () => {
  // The model drops the trailing zero; it is the same amount.
  assertEquals(containsNumber("قيمة الفاتورة: 850.50 جنيه", 850.5), true);
});

Deno.test("a near miss is not a match", () => {
  // 851 must never satisfy a check for 850.5 — that is the whole point.
  assertEquals(containsNumber("850.50", 851), false);
  assertEquals(containsNumber("850.50", 85.05), false);
});

Deno.test("identifiers match across separators", () => {
  assertEquals(containsDigitSequence("0100-123-4567", "01001234567"), true);
  assertEquals(containsDigitSequence("رقم الحساب: 12345678", "12345678"), true);
  assertEquals(containsDigitSequence("رقم الحساب: 12345678", "87654321"), false);
});

// ── amounts ───────────────────────────────────────────────────────────────

Deno.test("an amount printed on the page keeps its confidence", () => {
  const { analysis: result } = run(
    analysis({
      amounts: [{ label: "الإجمالي", value: 850.5, currency: "جنيه", confidence: "high" }],
    }),
  );

  assertEquals(result.amounts[0].confidence, "high");
  assertEquals(result.status, "success");
});

Deno.test("an invented amount is downgraded, not deleted", () => {
  // Deleting would hide from the user that we read something we could not
  // confirm; low confidence shows «قراءة غير مؤكدة» and lets them correct it.
  const { analysis: result } = run(
    analysis({
      amounts: [{ label: "الإجمالي", value: 9999, currency: "جنيه", confidence: "high" }],
    }),
  );

  assertEquals(result.amounts.length, 1, "the value must survive");
  assertEquals(result.amounts[0].confidence, "low");
  assertEquals(result.status, "partial");
  assert(result.missing_fields.includes("amounts"));
});

Deno.test("a negative amount is dropped as an OCR artefact", () => {
  const { analysis: result, report } = run(
    analysis({
      amounts: [{ label: "الإجمالي", value: -50, currency: "جنيه", confidence: "high" }],
    }),
  );

  assertEquals(result.amounts.length, 0);
  assertEquals(report.droppedAmounts, 1);
});

Deno.test("an amount found only in the candidates is accepted", () => {
  const candidates: ExtractedCandidates = {
    ...NO_CANDIDATES,
    amounts: [{ raw_text: "٧٥٠ جنيه", value: 750, currency: "EGP", is_ambiguous: false }],
  };

  const { analysis: result } = run(
    analysis({
      amounts: [{ label: "مقدم", value: 750, currency: "جنيه", confidence: "high" }],
    }),
    "نص لا يحتوي رقما",
    candidates,
  );

  assertEquals(result.amounts[0].confidence, "high");
});

// ── key information / source claims ───────────────────────────────────────

Deno.test("an extracted account number present on the page is kept", () => {
  const { analysis: result } = run(
    analysis({
      key_information: [
        { label: "رقم الحساب", value: "12345678", confidence: "high", source: "extracted" },
      ],
    }),
  );

  assertEquals(result.key_information[0].confidence, "high");
  assertEquals(result.key_information[0].source, "extracted");
});

Deno.test("an extracted claim that is not on the page is re-labelled inferred", () => {
  // A false "extracted" is how a hallucination reaches the user looking like a
  // printed fact.
  const { analysis: result } = run(
    analysis({
      key_information: [
        { label: "رقم الحساب", value: "99999999", confidence: "high", source: "extracted" },
      ],
    }),
  );

  assertEquals(result.key_information[0].confidence, "low");
  assertEquals(result.key_information[0].source, "inferred");
  assertEquals(result.status, "partial");
});

Deno.test("an inferred claim is accepted without proof", () => {
  // The label is the disclosure; the client shows a basis indicator.
  const { analysis: result } = run(
    analysis({
      key_information: [
        { label: "الجهة", value: "شركة الكهرباء غالبا", confidence: "medium", source: "inferred" },
      ],
    }),
  );

  assertEquals(result.key_information[0].confidence, "medium");
  assertEquals(result.status, "success");
});

Deno.test("a textual value printed on the page is verified", () => {
  const { analysis: result } = run(
    analysis({
      key_information: [
        {
          label: "الجهة",
          value: "شركة جنوب القاهرة لتوزيع الكهرباء",
          confidence: "high",
          source: "extracted",
        },
      ],
    }),
  );

  assertEquals(result.key_information[0].confidence, "high");
});

// ── dates ─────────────────────────────────────────────────────────────────

Deno.test("well-formed dates are recognised, impossible ones are not", () => {
  assertEquals(isWellFormedDate("2026-09-15"), true);
  assertEquals(isWellFormedDate("2026-02-30"), false, "February has no 30th");
  assertEquals(isWellFormedDate("2027-02-29"), false, "2027 is not a leap year");
  assertEquals(isWellFormedDate("2026-13-01"), false);
  assertEquals(isWellFormedDate("15/09/2026"), false, "must be ISO");
  assertEquals(isWellFormedDate("next Tuesday"), false);
});

Deno.test("a free-text date is downgraded", () => {
  // Strict mode cannot enforce a format — no `pattern` keyword — so
  // "next Tuesday" satisfies the schema perfectly. This is the only check.
  const { analysis: result } = run(
    analysis({
      dates: [{
        label: "الموعد",
        date: "next Tuesday",
        time: null,
        role: "deadline",
        is_reminder_worthy: true,
        confidence: "high",
      }],
    }),
  );

  assertEquals(result.dates[0].confidence, "low");
  assertEquals(result.status, "partial");
});

Deno.test("a date is traceable through any printed spelling", () => {
  const sources = { ocrText: "آخر موعد: 15/9/2026", candidates: NO_CANDIDATES };

  assertEquals(isDateTraceable("2026-09-15", sources), true);
});

Deno.test("a date the page never mentions is not traceable", () => {
  const sources = { ocrText: "آخر موعد: 15/9/2026", candidates: NO_CANDIDATES };

  // §33 rule 14: an assumed year is the classic confidently-wrong deadline.
  assertEquals(isDateTraceable("2027-09-15", sources), false);
});

Deno.test("an untraceable date is downgraded", () => {
  const { analysis: result } = run(
    analysis({
      dates: [{
        label: "آخر موعد للسداد",
        date: "2029-01-01",
        time: null,
        role: "deadline",
        is_reminder_worthy: true,
        confidence: "high",
      }],
    }),
  );

  assertEquals(result.dates[0].confidence, "low");
  assert(result.missing_fields.includes("dates"));
});

Deno.test("a time the page never stated is removed", () => {
  // Otherwise F09 would schedule a notification at an hour nobody chose.
  const { analysis: result } = run(
    analysis({
      dates: [{
        label: "آخر موعد للسداد",
        date: "2026-09-15",
        time: "09:30",
        role: "deadline",
        is_reminder_worthy: true,
        confidence: "high",
      }],
    }),
  );

  assertEquals(result.dates[0].time, null);
  assertEquals(result.dates[0].confidence, "low");
});

Deno.test("a time the page does state is kept", () => {
  const { analysis: result } = run(
    analysis({
      dates: [{
        label: "الموعد",
        date: "2026-09-15",
        time: "09:30",
        role: "appointment",
        is_reminder_worthy: true,
        confidence: "high",
      }],
    }),
    BILL_TEXT + "\nالساعة 09:30 صباحا",
  );

  assertEquals(result.dates[0].time, "09:30");
  assertEquals(result.dates[0].confidence, "high");
});

Deno.test("time format is validated", () => {
  assertEquals(isWellFormedTime("09:30"), true);
  assertEquals(isWellFormedTime("23:59"), true);
  assertEquals(isWellFormedTime("24:00"), false);
  assertEquals(isWellFormedTime("9:30"), false);
  assertEquals(isWellFormedTime("09:60"), false);
});

// ── reminders ─────────────────────────────────────────────────────────────

Deno.test("a past deadline cannot drive a reminder", () => {
  const { analysis: result, report } = run(
    analysis({
      dates: [{
        label: "آخر موعد للسداد",
        date: "2020-01-15",
        time: null,
        role: "deadline",
        is_reminder_worthy: true,
        confidence: "high",
      }],
    }),
    "آخر موعد للسداد: 15/1/2020",
  );

  assertEquals(result.dates[0].is_reminder_worthy, false);
  assertEquals(report.clearedReminders, 1);
});

Deno.test("an issue date is never reminder-worthy", () => {
  // It is a fact about the document, not something to be reminded of.
  const { analysis: result } = run(
    analysis({
      dates: [{
        label: "تاريخ الإصدار",
        date: "2026-09-15",
        time: null,
        role: "issued",
        is_reminder_worthy: true,
        confidence: "high",
      }],
    }),
  );

  assertEquals(result.dates[0].is_reminder_worthy, false);
});

Deno.test("a future deadline keeps its reminder", () => {
  const { analysis: result } = run(
    analysis({
      dates: [{
        label: "آخر موعد للسداد",
        date: "2026-09-15",
        time: null,
        role: "deadline",
        is_reminder_worthy: true,
        confidence: "high",
      }],
    }),
  );

  assertEquals(result.dates[0].is_reminder_worthy, true);
});

// ── safety warnings ───────────────────────────────────────────────────────

Deno.test("a medical document always carries its disclaimer", () => {
  // Non-negotiable (§7). Relying on the model to remember is exactly what it
  // will forget.
  const { analysis: result, report } = run(
    analysis({ document_type: { type: "medical", title: "تحليل", confidence: "high" } }),
  );

  assertEquals(result.warnings.length, 1);
  assertEquals(result.warnings[0].type, "medical");
  assertEquals(report.addedWarnings, ["medical"]);
});

Deno.test("legal, government and financial documents carry theirs too", () => {
  for (const type of ["legal", "government", "financial"]) {
    const { analysis: result } = run(
      analysis({ document_type: { type, title: "ورقة", confidence: "high" } }),
    );
    assertEquals(result.warnings[0]?.type, type);
  }
});

Deno.test("an existing warning is not duplicated", () => {
  const { analysis: result, report } = run(
    analysis({
      document_type: { type: "medical", title: "تحليل", confidence: "high" },
      warnings: [{ text: "راجع طبيبك", type: "medical" }],
    }),
  );

  assertEquals(result.warnings.length, 1);
  assertEquals(report.addedWarnings, []);
});

Deno.test("an invoice needs no disclaimer", () => {
  assertEquals(requiredWarningFor("invoice"), null);
  assertEquals(requiredWarningFor("receipt"), null);
});

// ── status consistency ────────────────────────────────────────────────────

Deno.test("success becomes partial once anything is downgraded", () => {
  // success renders without the review banner, hiding that a value is unsure.
  const { analysis: result, report } = run(
    analysis({
      amounts: [{ label: "الإجمالي", value: 4242, currency: "جنيه", confidence: "high" }],
    }),
  );

  assertEquals(result.status, "partial");
  assertEquals(report.statusChanged, true);
});

Deno.test("a clean analysis is left alone", () => {
  const { analysis: result, report } = run(
    analysis({
      amounts: [{ label: "الإجمالي", value: 850.5, currency: "جنيه", confidence: "high" }],
      key_information: [
        { label: "رقم الحساب", value: "12345678", confidence: "high", source: "extracted" },
      ],
    }),
  );

  assertEquals(result.status, "success");
  assertEquals(report.downgraded, []);
  assertEquals(report.statusChanged, false);
});

Deno.test("unsupported with confident facts stays unsupported", () => {
  // "I could not read it" and "here are seven facts from it" cannot both hold.
  const { analysis: result } = run(
    analysis({
      status: "unsupported",
      amounts: [{ label: "الإجمالي", value: 850.5, currency: "جنيه", confidence: "high" }],
    }),
  );

  assertEquals(result.status, "unsupported");
});

Deno.test("the report names fields, never values", () => {
  // It is safe to log; document content never is (§51).
  const { report } = run(
    analysis({
      amounts: [{ label: "سري", value: 4242, currency: "جنيه", confidence: "high" }],
    }),
  );

  const serialised = JSON.stringify(report);
  assert(!serialised.includes("4242"));
  assert(!serialised.includes("سري"));
  assertEquals(report.downgraded, ["amounts"]);
});
