/**
 * F20-T05 · Tests for semantic validation (§3, S1–S4).
 *
 * Every rule gets a pass and a fail. The extra passes pin the cases most
 * likely to become false rejects (gate G5): an `unsupported` answer, a Latin
 * brand name in an Arabic title, a summary quoting the page's heading.
 */

import {
  assertEquals,
  assertInstanceOf,
  assertStrictEquals,
  assertThrows,
} from "jsr:@std/assert@1";

import {
  assertSemanticallyValid,
  SEMANTIC_LIMITS,
  semanticViolations,
} from "../../functions/_shared/analysis/semantic-validation.ts";
import { ProviderFailure } from "../../functions/_shared/ai/provider-failure.ts";
import type { ModelAnalysis } from "../../functions/_shared/schemas/analysis-output.schema.ts";
import { modelAnalysis, OCR_TEXT } from "../fixtures/analyze-fixtures.ts";

function violations(analysis: ModelAnalysis, ocrText = OCR_TEXT) {
  return semanticViolations(analysis, ocrText);
}

function withSummary(summary: Partial<ModelAnalysis["summary"]>): ModelAnalysis {
  const base = modelAnalysis();
  return modelAnalysis({ summary: { ...base.summary, ...summary } });
}

function withTitle(title: string): ModelAnalysis {
  const base = modelAnalysis();
  return modelAnalysis({ document_type: { ...base.document_type, title } });
}

/** A long, natural-looking paper, well past the S4 minimum. */
const LONG_PAGE = [
  "جمهورية مصر العربية",
  "وزارة الداخلية - مصلحة الأحوال المدنية",
  "يرجى الحضور إلى مكتب السجل المدني بالعباسية يوم الأحد الموافق 2026/10/04",
  "ومعكم أصل شهادة الميلاد وصورة البطاقة الشخصية وإيصال سداد الرسوم المقررة",
].join("\n");

Deno.test("the shared fixture passes every rule", () => {
  assertEquals(violations(modelAnalysis()), []);
});

// ── S1 · required text ────────────────────────────────────────────────────

Deno.test("S1 passes when title and both summaries are present", () => {
  assertEquals(violations(modelAnalysis({ status: "partial" })), []);
});

Deno.test("S1 fails on a whitespace-only summary.short in a success", () => {
  assertEquals(violations(withSummary({ short: "  \n " })), ["S1"]);
});

Deno.test("S1 fails on a blank summary.detailed in a partial", () => {
  const analysis = { ...withSummary({ detailed: "" }), status: "partial" as const };

  assertEquals(violations(analysis), ["S1"]);
});

Deno.test("S1 fails on a blank document_type.title", () => {
  assertEquals(violations(withTitle(" ")), ["S1"]);
});

Deno.test("S1 does not apply to an unsupported answer", () => {
  const analysis = modelAnalysis({
    status: "unsupported",
    document_type: { type: "other", title: "", confidence: "low" },
    summary: { short: "", detailed: "" },
  });

  assertEquals(violations(analysis), []);
});

// ── S2 · Arabic script ────────────────────────────────────────────────────

Deno.test("S2 passes a Latin brand name inside Arabic text", () => {
  assertEquals(violations(withTitle("فاتورة Vodafone")), []);
});

Deno.test("S2 passes reader-facing text that has no letters at all", () => {
  const analysis = modelAnalysis({
    status: "unsupported",
    document_type: { type: "other", title: "—", confidence: "low" },
    summary: { short: "2026", detailed: "850.50" },
    actions_required: [],
    instructions: [],
  });

  assertEquals(violations(analysis), []);
});

Deno.test("S2 fails an answer written in English", () => {
  const analysis = modelAnalysis({
    document_type: { type: "invoice", title: "Electricity bill", confidence: "high" },
    summary: {
      short: "An electricity bill for June 2026 of 850.50 EGP.",
      detailed: "This is an electricity bill from South Cairo; pay it before August 15.",
    },
    actions_required: [
      { description: "Pay the bill before 15 August 2026.", basis: "explicit", priority: "high" },
    ],
    instructions: ["You can pay online through Fawry."],
  });

  assertEquals(violations(analysis), ["S2"]);
});

Deno.test("S2 fails an Arabic title over an English detailed summary", () => {
  const analysis = withSummary({
    detailed: "This is an electricity bill from the South Cairo Electricity Distribution " +
      "Company. The total due is 850.50 EGP and it must be paid before August 15, 2026, " +
      "otherwise the supply may be disconnected.",
  });

  assertEquals(violations(analysis), ["S2"]);
});

Deno.test("S2 counts actions and instructions, not only the summary", () => {
  const english = "Take the original birth certificate and a copy of the national ID card.";
  const analysis = modelAnalysis({
    actions_required: Array.from({ length: 5 }, () => ({
      description: english,
      basis: "explicit" as const,
      priority: "normal" as const,
    })),
    instructions: [english, english],
  });

  assertEquals(violations(analysis), ["S2"]);
});

// ── S3 · length bounds ────────────────────────────────────────────────────

Deno.test("S3 passes every string and array exactly at its bound", () => {
  const limits = SEMANTIC_LIMITS;
  const analysis = modelAnalysis({
    document_type: { type: "invoice", title: "ف".repeat(limits.titleMaxChars), confidence: "high" },
    summary: {
      short: "ف".repeat(limits.shortSummaryMaxChars),
      detailed: "ف".repeat(limits.detailedSummaryMaxChars),
    },
    instructions: Array.from({ length: limits.maxItems }, () => "ف".repeat(limits.itemMaxChars)),
  });

  assertEquals(violations(analysis), []);
});

Deno.test("S3 passes a summary.short over §30's 200, which the response shortens", () => {
  assertEquals(violations(withSummary({ short: "ف".repeat(201) })), []);
});

Deno.test("S3 fails a title past its bound", () => {
  assertEquals(violations(withTitle("ف".repeat(SEMANTIC_LIMITS.titleMaxChars + 1))), ["S3"]);
});

Deno.test("S3 fails a summary.short past its bound", () => {
  const analysis = withSummary({ short: "ف".repeat(SEMANTIC_LIMITS.shortSummaryMaxChars + 1) });

  assertEquals(violations(analysis), ["S3"]);
});

Deno.test("S3 fails a summary.detailed past its bound", () => {
  const analysis = withSummary({
    detailed: "ف".repeat(SEMANTIC_LIMITS.detailedSummaryMaxChars + 1),
  });

  assertEquals(violations(analysis), ["S3"]);
});

Deno.test("S3 fails an item string past its bound", () => {
  const base = modelAnalysis();
  const analysis = modelAnalysis({
    key_information: [
      { ...base.key_information[0], value: "1".repeat(SEMANTIC_LIMITS.itemMaxChars + 1) },
    ],
  });

  assertEquals(violations(analysis), ["S3"]);
});

Deno.test("S3 fails an array past its bound", () => {
  const analysis = modelAnalysis({
    missing_fields: Array.from({ length: SEMANTIC_LIMITS.maxItems + 1 }, () => "dates"),
  });

  assertEquals(violations(analysis), ["S3"]);
});

// ── S4 · echo ─────────────────────────────────────────────────────────────

Deno.test("S4 passes a real summary of a long page", () => {
  const analysis = withSummary({
    detailed: "دي ورقة من السجل المدني بتطلب منك تروح مكتب العباسية يوم الأحد 4 أكتوبر، " +
      "ومعاك شهادة الميلاد الأصلية وصورة البطاقة وإيصال الرسوم.",
  });

  assertEquals(violations(analysis, LONG_PAGE), []);
});

Deno.test("S4 passes a summary that quotes a short heading from the page", () => {
  const analysis = withSummary({ detailed: "وزارة الداخلية - مصلحة الأحوال المدنية" });

  assertEquals(violations(analysis, LONG_PAGE), []);
});

Deno.test("S4 passes a one-line page the summary happens to contain", () => {
  const page = "فاتورة كهرباء";
  const analysis = withSummary({ detailed: "دي فاتورة كهرباء عادية، مفيهاش مبلغ ولا ميعاد." });

  assertEquals(violations(analysis, page), []);
});

Deno.test("S4 fails a summary that is the page pasted back", () => {
  assertEquals(violations(withSummary({ detailed: LONG_PAGE }), LONG_PAGE), ["S4"]);
});

Deno.test("S4 fails a long verbatim stretch, even reflowed and re-punctuated", () => {
  const stretch = "يرجى الحضور إلى مكتب السجل المدني بالعباسية، يوم الأحد الموافق ٢٠٢٦/١٠/٠٤. " +
    "ومعكم أصل شهادة الميلاد";

  assertEquals(violations(withSummary({ detailed: stretch }), LONG_PAGE), ["S4"]);
});

Deno.test("S4 fails the page pasted inside a longer summary", () => {
  const analysis = withSummary({ detailed: `الورقة بتقول:\n${LONG_PAGE}\nيعني لازم تروح.` });

  assertEquals(violations(analysis, LONG_PAGE), ["S4"]);
});

// ── the throwing form ─────────────────────────────────────────────────────

Deno.test("assertSemanticallyValid returns a passing analysis unchanged", () => {
  const analysis = modelAnalysis();

  assertStrictEquals(assertSemanticallyValid(analysis, OCR_TEXT), analysis);
});

Deno.test("assertSemanticallyValid throws invalid_output, naming neither rule nor text", () => {
  const secret = "ف".repeat(SEMANTIC_LIMITS.titleMaxChars + 1);

  const failure = assertThrows(() => assertSemanticallyValid(withTitle(secret), OCR_TEXT));

  assertInstanceOf(failure, ProviderFailure);
  assertEquals(failure.kind, "invalid_output");
  assertEquals(failure.message, "AI provider failure: invalid_output.");
});

Deno.test("violations are reported together, in rule order", () => {
  const analysis = modelAnalysis({
    document_type: { type: "other", title: "", confidence: "low" },
    summary: { short: "Nothing here.", detailed: LONG_PAGE.replaceAll("\n", " ") },
    missing_fields: Array.from({ length: SEMANTIC_LIMITS.maxItems + 1 }, () => "x"),
  });

  // S2 still passes: the pasted page is Arabic.
  assertEquals(violations(analysis, LONG_PAGE), ["S1", "S3", "S4"]);
});
