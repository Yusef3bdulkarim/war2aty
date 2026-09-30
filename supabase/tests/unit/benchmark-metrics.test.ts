/**
 * F20-T08 · Tests for the benchmark metrics.
 *
 * T09's gates are decided on these numbers, so each metric is pinned on small
 * cases whose answer can be worked out by hand.
 */

import { assertAlmostEquals, assertEquals } from "jsr:@std/assert@1";

import {
  arabicLetterShare,
  cer,
  compact,
  criticalFields,
  digitAccuracy,
  editDistance,
  mean,
  normalise,
  percent,
  percentile,
  precisionRecall,
  rate,
  sameAmount,
  scriptCer,
  wer,
} from "../../tools/benchmark/metrics.ts";

// ── normalisation ─────────────────────────────────────────────────────────

Deno.test("normalise folds Arabic orthographic variants", () => {
  assertEquals(normalise("أإآٱ"), "اااا");
  assertEquals(normalise("مستشفى"), "مستشفي");
  assertEquals(normalise("فاتورة"), "فاتوره");
});

Deno.test("normalise strips diacritics and tatweel", () => {
  assertEquals(normalise("مُحَمَّد"), "محمد");
  assertEquals(normalise("جنيـــه"), "جنيه");
});

Deno.test("normalise folds both digit systems and collapses whitespace", () => {
  assertEquals(normalise("  ٨٥٠   ۱۲۳\n\tABC "), "850 123 abc");
});

Deno.test("compact drops all whitespace", () => {
  assertEquals(compact("10, 99 €"), "10,99€");
});

// ── edit distance and error rates ─────────────────────────────────────────

Deno.test("editDistance counts substitutions, insertions and deletions", () => {
  assertEquals(editDistance([..."kitten"], [..."sitting"]), 3);
  assertEquals(editDistance([], [..."abc"]), 3);
  assertEquals(editDistance([..."abc"], []), 3);
  assertEquals(editDistance([..."same"], [..."same"]), 0);
});

Deno.test("cer is zero for a perfect reading, up to cosmetic variation", () => {
  assertEquals(cer("فاتورة كهرباء", "فاتوره  كهرباء"), 0);
});

Deno.test("cer is edits per truth character", () => {
  assertAlmostEquals(cer("abcd", "abxd")!, 0.25);
});

Deno.test("cer of an empty reading is 1", () => {
  assertEquals(cer("abcd", ""), 1);
});

Deno.test("cer is null when the truth is empty", () => {
  assertEquals(cer("", "anything"), null);
});

Deno.test("wer is edits per truth word", () => {
  assertAlmostEquals(wer("one two three four", "one too three four")!, 0.25);
});

Deno.test("scriptCer scores each script on its own letters", () => {
  const truth = "فاتورة Vodafone";
  const ocr = "فاتورة Vodaf0ne";

  assertEquals(scriptCer(truth, ocr, "arabic"), 0);
  assertAlmostEquals(scriptCer(truth, ocr, "latin")!, 1 / 8);
});

Deno.test("scriptCer is null when the truth has no letters of that script", () => {
  assertEquals(scriptCer("فاتورة", "فاتورة", "latin"), null);
});

Deno.test("digitAccuracy treats both digit systems as the same value", () => {
  assertEquals(digitAccuracy("المبلغ ٨٥٠", "المبلغ 850"), 1);
});

Deno.test("digitAccuracy scores a misread digit", () => {
  assertAlmostEquals(digitAccuracy("850", "860")!, 2 / 3);
});

Deno.test("digitAccuracy floors at zero and is null without digits", () => {
  assertEquals(digitAccuracy("1", "99999"), 0);
  assertEquals(digitAccuracy("no digits", "123"), null);
});

// ── critical fields ───────────────────────────────────────────────────────

Deno.test("criticalFields separates the reader's loss from the extractors'", () => {
  const score = criticalFields({
    truthValues: ["15/08/2026", "850.50", "99.00"],
    // 99.00 is not in the reading at all: OCR loss.
    ocrText: "آخر موعد 15/08/2026 المبلغ 850.50",
    // 850.50 is in the reading, but no candidate caught it: extractor loss.
    candidateRawTexts: ["15/08/2026"],
  });

  assertEquals(score.expected, 3);
  assertEquals(score.ocrLoss, 1);
  assertEquals(score.extractorLoss, 1);
  assertAlmostEquals(score.recall!, 2 / 3);
  assertEquals(score.precision, 1);
});

Deno.test("criticalFields matches across digit systems and spacing", () => {
  const score = criticalFields({
    truthValues: ["٨٥٠٫٥٠ جنيه".replace("٫", ".")],
    ocrText: "المبلغ 850.50  جنيه",
    candidateRawTexts: ["850.50 جنيه"],
  });

  assertEquals(score.recall, 1);
  assertEquals(score.ocrLoss, 0);
  assertEquals(score.extractorLoss, 0);
});

Deno.test("criticalFields counts candidates that match no truth value against precision", () => {
  const score = criticalFields({
    truthValues: ["850.50"],
    ocrText: "850.50 و 12.00",
    candidateRawTexts: ["850.50", "12.00"],
  });

  assertEquals(score.precision, 0.5);
});

Deno.test("criticalFields is null where there is nothing to measure", () => {
  const score = criticalFields({
    truthValues: [],
    ocrText: "text",
    candidateRawTexts: [],
  });

  assertEquals(score.recall, null);
  assertEquals(score.precision, null);
});

// ── analysis metrics ──────────────────────────────────────────────────────

Deno.test("precisionRecall counts duplicates once", () => {
  const pr = precisionRecall(
    ["2026-08-15", "2026-08-15", "2026-09-01"],
    ["2026-08-15", "2026-10-01"],
    (a, b) => a === b,
  );

  assertEquals(pr.precision, 0.5);
  assertEquals(pr.recall, 0.5);
});

Deno.test("precisionRecall is null on an empty side", () => {
  assertEquals(precisionRecall([], ["x"], (a, b) => a === b), {
    precision: null,
    recall: 0,
  });
  assertEquals(precisionRecall(["x"], [], (a, b) => a === b), {
    precision: 0,
    recall: null,
  });
});

Deno.test("sameAmount compares values, not formatting", () => {
  assertEquals(sameAmount(850.5, 850.50), true);
  assertEquals(sameAmount(850.5, 851), false);
});

Deno.test("arabicLetterShare counts letters only", () => {
  assertEquals(arabicLetterShare("فاتورة 850"), 1);
  assertEquals(arabicLetterShare("ab فا"), 0.5);
  assertEquals(arabicLetterShare("123 ..."), null);
});

// ── aggregation ───────────────────────────────────────────────────────────

Deno.test("mean skips missing values", () => {
  assertEquals(mean([1, null, 3]), 2);
  assertEquals(mean([null, null]), null);
});

Deno.test("percentile is nearest-rank", () => {
  const values = Array.from({ length: 20 }, (_, i) => i + 1);

  assertEquals(percentile(values, 50), 10);
  assertEquals(percentile(values, 95), 19);
  assertEquals(percentile([7], 95), 7);
  assertEquals(percentile([], 95), null);
});

Deno.test("rate is the share of true among known values", () => {
  assertEquals(rate([true, false, null, true]), 2 / 3);
  assertEquals(rate([null]), null);
});

Deno.test("percent renders a dash for a missing value", () => {
  assertEquals(percent(0.273), " 27.3%");
  assertEquals(percent(null), "  —  ");
});
