/**
 * F20-T05 · Semantic validation — the hard rejects (§3).
 *
 * Strict structured output guarantees the SHAPE of an answer, and
 * `assertModelAnalysis` confirms it. Neither says whether the answer is
 * usable. A model can return a perfectly-typed object whose summary is blank,
 * written in English, thousands of characters of repetition, or simply the
 * OCR text pasted back. None of those is worth showing, or charging a slot
 * for.
 *
 * Each rule here is a HARD reject: it throws `ProviderFailure("invalid_output")`
 * (matrix row A5), which is fallback-eligible, so the second provider gets a
 * chance at the same text. That is the whole difference from F06-T12's
 * `validateAnalysis`, which stays as it is: its soft checks DOWNGRADE fields
 * the page cannot confirm and never reject.
 *
 * - **S1** · with status `success` or `partial`, `summary.short`,
 *   `summary.detailed` and `document_type.title` are not blank.
 * - **S2** · the reader-facing text is mostly Arabic script.
 * - **S3** · every string and array stays within its length bound.
 * - **S4** · `summary.detailed` is not a verbatim echo of the OCR input.
 *
 * It runs inside each attempt, after `assertModelAnalysis` (wired per leg from
 * T06 on).
 *
 * ── Thresholds ────────────────────────────────────────────────────────────
 * {@link SEMANTIC_LIMITS} are PROVISIONAL. They are set loose on purpose, to
 * catch degenerate output rather than judge style, and T09 tunes them on the
 * corpus. Gate G5 is that no rule rejects an answer the owner judged
 * acceptable, so when in doubt a bound errs towards letting the answer through
 * to the soft checks.
 *
 * PRIVACY (§51): the result names rules only. It never carries, or is built
 * from, the text it judged.
 */

import { ProviderFailure } from "../ai/provider-failure.ts";
import type { ModelAnalysis } from "../schemas/analysis-output.schema.ts";
import { normaliseForMatching } from "../validators/text-matching.ts";

export type SemanticRule = "S1" | "S2" | "S3" | "S4";

export const SEMANTIC_LIMITS = {
  /**
   * S2: the share of letters that must be Arabic script, measured across all
   * the reader-facing text together. Per field would reject a legitimate
   * «فاتورة Vodafone» title; across the whole answer, one Latin brand name is
   * noise, while an answer written in English still fails.
   */
  minArabicLetterShare: 0.5,
  /** S3: `document_type.title`. A title, not a sentence. */
  titleMaxChars: 120,
  /**
   * S3: `summary.short`. §30 caps it at 200, but the response builder already
   * shortens an over-long one on a word boundary, so that alone is no reason
   * to reject. Past this bound it is not a short summary at all.
   */
  shortSummaryMaxChars: 500,
  /** S3: `summary.detailed`. "A few sentences", with room for a long letter. */
  detailedSummaryMaxChars: 3000,
  /** S3: any other string: labels, values, actions, instructions, warnings. */
  itemMaxChars: 600,
  /** S3: any array. A looping model repeats items; a real paper has far fewer. */
  maxItems: 40,
  /**
   * S4: the shorter side of an echo must be at least this long, in normalised
   * characters. Below it, containment is coincidence: a one-line page, or a
   * summary that quotes the page's own heading, is not an echo.
   */
  minEchoChars: 60,
} as const;

/**
 * Every rule the analysis breaks, in rule order. Empty when it passes.
 *
 * Returned rather than thrown so the benchmark (T08) can report WHICH rule
 * rejected an answer.
 */
export function semanticViolations(
  analysis: ModelAnalysis,
  ocrText: string,
): SemanticRule[] {
  const violations: SemanticRule[] = [];
  if (!hasRequiredText(analysis)) violations.push("S1");
  if (!isMostlyArabic(analysis)) violations.push("S2");
  if (!isWithinBounds(analysis)) violations.push("S3");
  if (isEchoOf(analysis.summary.detailed, ocrText)) violations.push("S4");
  return violations;
}

/**
 * Returns the analysis unchanged when it passes every rule.
 *
 * @throws ProviderFailure `invalid_output` on any violation. The failure does
 * not say which rule, for the same reason it carries no text: it may travel
 * further than this module.
 */
export function assertSemanticallyValid(
  analysis: ModelAnalysis,
  ocrText: string,
): ModelAnalysis {
  if (semanticViolations(analysis, ocrText).length > 0) {
    throw new ProviderFailure("invalid_output");
  }
  return analysis;
}

// ── S1 · required text ────────────────────────────────────────────────────

/**
 * `unsupported` is exempt: it is the model saying it could not read the page,
 * and it has nothing to summarise.
 */
function hasRequiredText(analysis: ModelAnalysis): boolean {
  if (analysis.status === "unsupported") return true;
  return [
    analysis.summary.short,
    analysis.summary.detailed,
    analysis.document_type.title,
  ].every((value) => value.trim().length > 0);
}

// ── S2 · Arabic script ────────────────────────────────────────────────────

const LETTER = /\p{L}/u;
const ARABIC_SCRIPT = /\p{Script=Arabic}/u;

/** The text the reader actually reads as our explanation of the paper. */
function readerFacingText(analysis: ModelAnalysis): string[] {
  return [
    analysis.document_type.title,
    analysis.summary.short,
    analysis.summary.detailed,
    ...analysis.actions_required.map((action) => action.description),
    ...analysis.instructions,
  ];
}

/**
 * Digits, punctuation and spaces are neither Arabic nor not, so only letters
 * count. Text with no letters at all passes: there is nothing to judge, and a
 * blank field is S1's to reject, not this rule's.
 */
function isMostlyArabic(analysis: ModelAnalysis): boolean {
  let letters = 0;
  let arabic = 0;
  for (const text of readerFacingText(analysis)) {
    for (const character of text) {
      if (!LETTER.test(character)) continue;
      letters += 1;
      if (ARABIC_SCRIPT.test(character)) arabic += 1;
    }
  }
  if (letters === 0) return true;
  return arabic / letters >= SEMANTIC_LIMITS.minArabicLetterShare;
}

// ── S3 · length bounds ────────────────────────────────────────────────────

function isWithinBounds(analysis: ModelAnalysis): boolean {
  const limits = SEMANTIC_LIMITS;

  const arrays: readonly (readonly unknown[])[] = [
    analysis.key_information,
    analysis.dates,
    analysis.amounts,
    analysis.actions_required,
    analysis.required_documents,
    analysis.instructions,
    analysis.warnings,
    analysis.missing_fields,
  ];
  if (arrays.some((items) => items.length > limits.maxItems)) return false;

  if (analysis.document_type.title.length > limits.titleMaxChars) return false;
  if (analysis.summary.short.length > limits.shortSummaryMaxChars) return false;
  if (analysis.summary.detailed.length > limits.detailedSummaryMaxChars) return false;

  const items: string[] = [
    ...analysis.key_information.flatMap((item) => [item.label, item.value]),
    ...analysis.dates.flatMap((date) => [date.label, date.date, date.time ?? ""]),
    ...analysis.amounts.flatMap((amount) => [amount.label, amount.currency]),
    ...analysis.actions_required.map((action) => action.description),
    ...analysis.required_documents,
    ...analysis.instructions,
    ...analysis.warnings.map((warning) => warning.text),
    ...analysis.missing_fields,
  ];
  return items.every((value) => value.length <= limits.itemMaxChars);
}

// ── S4 · echo ─────────────────────────────────────────────────────────────

/**
 * Letters and digits only, one space between runs, with the same folding the
 * soft checks use (digits, tatweel, Arabic separators, case). Punctuation and
 * line breaks are gone, so a copy that only reflowed the page still matches.
 */
function comparable(text: string): string {
  return normaliseForMatching(text)
    .replaceAll(/\p{M}/gu, "")
    .replaceAll(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
}

/**
 * Whether the summary is a copy of the page: either a long stretch of it
 * verbatim, or the whole page pasted inside it.
 */
function isEchoOf(detailed: string, ocrText: string): boolean {
  const summary = comparable(detailed);
  const page = comparable(ocrText);
  const shorter = summary.length <= page.length ? summary : page;
  const longer = shorter === summary ? page : summary;

  if (shorter.length < SEMANTIC_LIMITS.minEchoChars) return false;
  return longer.includes(shorter);
}
