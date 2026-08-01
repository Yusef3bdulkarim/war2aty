/**
 * F13-T06 · Tests for per-field validation/confidence (Azure-only).
 *
 * No network, no Azure client — `verifyCandidates` is a pure function over a
 * `content` string, a flattened `words[]` list, and the candidates T05's
 * extractors produced. Fixtures build minimal, realistic-looking OCR text so
 * each test states only the confidences and positions it cares about.
 */

import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";

import type { AzureWord } from "../../functions/_shared/azure/azure-client.ts";
import type {
  AmountCandidate,
  DateCandidate,
  ExtractedCandidates,
  PhoneCandidate,
  ReferenceCandidate,
  TimeCandidate,
} from "../../functions/_shared/prompts/analysis-prompt.ts";
import {
  VERIFIED_CONFIDENCE_THRESHOLD,
  verifyCandidates,
} from "../../functions/_shared/verification/field-verification.ts";
import { buildAnalysisResponse } from "../../functions/_shared/analyze/analyze-response.ts";
import { modelAnalysis, SESSION_ID } from "../fixtures/analyze-fixtures.ts";

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

/**
 * Builds a `words[]` fixture by locating each entry's text in `content` in
 * order (so a repeated word is matched to its next occurrence, not always
 * the first). Throws if a fixture text is not actually in `content` — a
 * broken fixture, not a case the module under test should silently accept.
 */
function wordsIn(content: string, entries: Array<[text: string, confidence: number]>): AzureWord[] {
  const words: AzureWord[] = [];
  let cursor = 0;
  for (const [text, confidence] of entries) {
    const offset = content.indexOf(text, cursor);
    if (offset === -1) {
      throw new Error(`fixture text not found in content after cursor ${cursor}: "${text}"`);
    }
    words.push({ content: text, offset, length: text.length, confidence });
    cursor = offset + text.length;
  }
  return words;
}

const HIGH = 0.97;
const LOW = 0.4;

// ── verified ────────────────────────────────────────────────────────────

Deno.test("an unambiguous amount with high confidence across its span is verified", () => {
  const content = "الإجمالي 150 EGP فقط لا غير";
  const amounts: AmountCandidate[] = [
    { raw_text: "150 EGP", value: 150, currency: "EGP", is_ambiguous: false },
  ];
  const words = wordsIn(content, [["150", HIGH], ["EGP", HIGH]]);

  const result = verifyCandidates({ content, words, candidates: emptyCandidates({ amounts }) });

  assertEquals(result.amounts, [{ status: "verified", confidence: HIGH }]);
});

// ── unverified: low confidence ─────────────────────────────────────────

Deno.test("an unambiguous amount is unverified when any covering word is below threshold", () => {
  const content = "الإجمالي 150 EGP فقط لا غير";
  const amounts: AmountCandidate[] = [
    { raw_text: "150 EGP", value: 150, currency: "EGP", is_ambiguous: false },
  ];
  const words = wordsIn(content, [["150", HIGH], ["EGP", LOW]]);

  const result = verifyCandidates({ content, words, candidates: emptyCandidates({ amounts }) });

  assertEquals(result.amounts, [{ status: "unverified", confidence: LOW }]);
});

// ── unverified: ambiguous never reaches verified, however confident ─────

Deno.test("a keyword-adjacent amount stays unverified despite high confidence", () => {
  const content = "الإجمالي 1250 جنيه";
  const amounts: AmountCandidate[] = [
    { raw_text: "إجمالي 1250", value: 1250, currency: null, is_ambiguous: true },
  ];
  const words = wordsIn(content, [["إجمالي", HIGH], ["1250", HIGH]]);

  const result = verifyCandidates({ content, words, candidates: emptyCandidates({ amounts }) });

  assertEquals(result.amounts[0].status, "unverified");
});

Deno.test("a reference candidate can never reach verified — every reference is ambiguous", () => {
  const content = "رقم الفاتورة INV-88213";
  const references: ReferenceCandidate[] = [
    { raw_text: "رقم الفاتورة INV-88213", value: "INV-88213", is_ambiguous: true },
  ];
  const words = wordsIn(content, [["رقم", HIGH], ["الفاتورة", HIGH], ["INV-88213", HIGH]]);

  const result = verifyCandidates({ content, words, candidates: emptyCandidates({ references }) });

  assertEquals(result.references[0].status, "unverified");
});

// ── conflicting: overlapping spans ───────────────────────────────────────

Deno.test("two overlapping date candidates with different normalized dates conflict", () => {
  const content = "05/06/2026";
  const dates: DateCandidate[] = [
    { raw_text: "05/06/2026", normalized_date: "2026-06-05", is_ambiguous: true },
    // A substring of the same text, parsed a different way — its span
    // overlaps the first candidate's.
    { raw_text: "06/2026", normalized_date: "2026-02-06", is_ambiguous: true },
  ];
  const words = wordsIn(content, [["05/06/2026", HIGH]]);

  const result = verifyCandidates({ content, words, candidates: emptyCandidates({ dates }) });

  assertEquals(result.dates[0].status, "conflicting");
  assertEquals(result.dates[1].status, "conflicting");
});

// ── conflicting: same label, different value ─────────────────────────────

Deno.test("the same amount label reported twice with different values conflicts", () => {
  const content = "الإجمالي 1250 وأيضا الإجمالي 1,205";
  const amounts: AmountCandidate[] = [
    { raw_text: "إجمالي 1250", value: 1250, currency: null, is_ambiguous: true },
    { raw_text: "إجمالي 1,205", value: 1205, currency: null, is_ambiguous: true },
  ];
  const words = wordsIn(content, [
    ["إجمالي", HIGH],
    ["1250", HIGH],
    ["إجمالي", HIGH],
    ["1,205", HIGH],
  ]);

  const result = verifyCandidates({ content, words, candidates: emptyCandidates({ amounts }) });

  assertEquals(result.amounts[0].status, "conflicting");
  assertEquals(result.amounts[1].status, "conflicting");
});

Deno.test("conflict outranks confidence — a conflicting candidate never becomes verified", () => {
  const content = "الإجمالي 1250 وأيضا الإجمالي 1205";
  // Not ambiguous and near-perfect confidence — would be `verified` alone.
  const amounts: AmountCandidate[] = [
    { raw_text: "إجمالي 1250", value: 1250, currency: null, is_ambiguous: false },
    { raw_text: "إجمالي 1205", value: 1205, currency: null, is_ambiguous: false },
  ];
  const words = wordsIn(content, [
    ["إجمالي", 0.99],
    ["1250", 0.99],
    ["إجمالي", 0.99],
    ["1205", 0.99],
  ]);

  const result = verifyCandidates({ content, words, candidates: emptyCandidates({ amounts }) });

  assertEquals(result.amounts[0].status, "conflicting");
  assertEquals(result.amounts[1].status, "conflicting");
});

// ── not conflicting: different labels, different values ─────────────────

Deno.test("different amount labels with different values do not conflict", () => {
  const content = "المطلوب 500 والإجمالي 700";
  const amounts: AmountCandidate[] = [
    { raw_text: "المطلوب 500", value: 500, currency: null, is_ambiguous: true },
    { raw_text: "إجمالي 700", value: 700, currency: null, is_ambiguous: true },
  ];
  const words = wordsIn(content, [
    ["المطلوب", HIGH],
    ["500", HIGH],
    ["إجمالي", HIGH],
    ["700", HIGH],
  ]);

  const result = verifyCandidates({ content, words, candidates: emptyCandidates({ amounts }) });

  assertNotEquals(result.amounts[0].status, "conflicting");
  assertNotEquals(result.amounts[1].status, "conflicting");
});

// ── confidence is a minimum ───────────────────────────────────────────────

Deno.test("confidence is the minimum across every occurrence of a repeated raw_text", () => {
  const content = "phone 01001234567 and again 01001234567 here";
  const phones: PhoneCandidate[] = [
    { raw_text: "01001234567", normalized_number: "01001234567", is_ambiguous: false },
  ];
  const words = wordsIn(content, [
    ["01001234567", 0.9],
    ["01001234567", LOW],
  ]);

  const result = verifyCandidates({ content, words, candidates: emptyCandidates({ phones }) });

  assertEquals(result.phones[0].confidence, LOW);
  assertEquals(result.phones[0].status, "unverified");
});

// ── unlocatable ────────────────────────────────────────────────────────────

Deno.test("no covering words yields null confidence, never a fabricated default", () => {
  const content = "الإجمالي 150 EGP";
  const amounts: AmountCandidate[] = [
    { raw_text: "150 EGP", value: 150, currency: "EGP", is_ambiguous: false },
  ];

  const result = verifyCandidates({ content, words: [], candidates: emptyCandidates({ amounts }) });

  assertEquals(result.amounts[0], { status: "unverified", confidence: null });
});

// ── index alignment with ExtractedCandidates ─────────────────────────────

Deno.test("every verdict array is index-aligned with its candidate array", () => {
  const content = "التاريخ 01/01/2026 والموعد 9:30 والمبلغ 100 EGP والهاتف 01001234567";
  const dates: DateCandidate[] = [
    { raw_text: "01/01/2026", normalized_date: "2026-01-01", is_ambiguous: true },
  ];
  const times: TimeCandidate[] = [{ raw_text: "9:30", hour: 9, minute: 30, is_ambiguous: true }];
  const amounts: AmountCandidate[] = [
    { raw_text: "100 EGP", value: 100, currency: "EGP", is_ambiguous: false },
  ];
  const phones: PhoneCandidate[] = [
    { raw_text: "01001234567", normalized_number: "01001234567", is_ambiguous: false },
  ];
  const words = wordsIn(content, [
    ["01/01/2026", HIGH],
    ["9:30", HIGH],
    ["100", HIGH],
    ["EGP", HIGH],
    ["01001234567", HIGH],
  ]);

  const candidates = emptyCandidates({ dates, times, amounts, phones });
  const result = verifyCandidates({ content, words, candidates });

  assertEquals(result.dates.length, dates.length);
  assertEquals(result.times.length, times.length);
  assertEquals(result.amounts.length, amounts.length);
  assertEquals(result.phones.length, phones.length);
  assertEquals(result.references.length, 0);
});

// ── the threshold is a real, exported constant ───────────────────────────

Deno.test("confidence exactly at the threshold is verified; just below is not", () => {
  const content = "150 EGP";
  const amounts: AmountCandidate[] = [
    { raw_text: "150 EGP", value: 150, currency: "EGP", is_ambiguous: false },
  ];

  const atThreshold = verifyCandidates({
    content,
    words: wordsIn(content, [["150", VERIFIED_CONFIDENCE_THRESHOLD], [
      "EGP",
      VERIFIED_CONFIDENCE_THRESHOLD,
    ]]),
    candidates: emptyCandidates({ amounts }),
  });
  assertEquals(atThreshold.amounts[0].status, "verified");

  const justBelow = verifyCandidates({
    content,
    words: wordsIn(content, [["150", VERIFIED_CONFIDENCE_THRESHOLD], [
      "EGP",
      VERIFIED_CONFIDENCE_THRESHOLD - 0.01,
    ]]),
    candidates: emptyCandidates({ amounts }),
  });
  assertEquals(justBelow.amounts[0].status, "unverified");
});

// ── backend-only: never a wire type ──────────────────────────────────────

/** True if `key` (case-insensitively) appears anywhere in `value`'s object tree. */
function hasKeyDeep(value: unknown, key: string): boolean {
  if (Array.isArray(value)) return value.some((item) => hasKeyDeep(item, key));
  if (value === null || typeof value !== "object") return false;

  for (const [k, v] of Object.entries(value)) {
    if (k.toLowerCase() === key.toLowerCase()) return true;
    if (hasKeyDeep(v, key)) return true;
  }
  return false;
}

Deno.test("verificationStatus never appears anywhere in the built §30 response body", () => {
  // Exercises the real §30 response builder (F06-T13) with a realistic
  // analysis, then walks the actual JS object the client would receive.
  // `VerificationStatus` (T06) is consumed by T08/T10 internally and must
  // never reach this boundary — locked decision #6 keeps it backend-only.
  const { body } = buildAnalysisResponse({
    analysis: modelAnalysis(),
    sessionId: SESSION_ID,
    schemaVersion: "1.0",
  });

  assert(!hasKeyDeep(body, "verificationStatus"));
});
