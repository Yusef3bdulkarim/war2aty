/**
 * F13-T06 · Per-field validation/confidence (Azure-only).
 *
 * T05's extractors produce candidates from Azure's OCR text alone — a regex
 * match with an `is_ambiguous` guess about its own parsing, nothing more. This
 * module is the first thing that asks whether a candidate is actually
 * trustworthy, using signals Azure itself provides (per-word confidence) and
 * signals visible in the extraction set itself (does the document disagree
 * with itself about this field).
 *
 * Deliberately not in `_shared/validators/` — that package (F06-T12) verifies
 * Groq's *output* against the page, after the model has run. This module runs
 * *before* Groq ever sees anything, over Azure's raw extraction. T08's
 * cross-provider validator is the next layer up: it takes this module's
 * output as one input among (later) a Google second opinion, and is the only
 * place that decides `needsUserReview`.
 *
 * `VerificationStatus` never crosses the wire (locked decision #6) — it is
 * consumed by T08 and T10, never serialized. There is no route wired to this
 * module yet; that is T11.
 *
 * PRIVACY (§7, §51): never log a span, a raw value, or a normalized value.
 */

import type { AzureWord } from "../azure/azure-client.ts";
import type { ExtractedCandidates } from "../prompts/analysis-prompt.ts";
import { AMOUNT_KEYWORDS } from "../extractors/amount-extractor.ts";
import { REFERENCE_KEYWORDS } from "../extractors/reference-extractor.ts";

export type VerificationStatus = "verified" | "unverified" | "conflicting";

export interface FieldVerdict {
  readonly status: VerificationStatus;
  /** Minimum Azure word confidence over the candidate's span(s); null when unlocatable. */
  readonly confidence: number | null;
}

/** Index-aligned with `ExtractedCandidates` — same order, same lengths. */
export interface CandidateVerification {
  readonly dates: readonly FieldVerdict[];
  readonly times: readonly FieldVerdict[];
  readonly amounts: readonly FieldVerdict[];
  readonly phones: readonly FieldVerdict[];
  readonly references: readonly FieldVerdict[];
}

export interface VerifyCandidatesInput {
  readonly content: string;
  readonly words: readonly AzureWord[];
  readonly candidates: ExtractedCandidates;
}

/**
 * Below this, a candidate stays `unverified` even when unambiguous and
 * unopposed. Exported so T08 and the T19 sandbox run can tune it against real
 * documents without touching the logic here.
 */
export const VERIFIED_CONFIDENCE_THRESHOLD = 0.85;

export function verifyCandidates(input: VerifyCandidatesInput): CandidateVerification {
  const { content, words } = input;

  return {
    dates: verifyGroup(input.candidates.dates, content, words, {
      normalizedValue: (c) => c.normalized_date ?? null,
    }),
    times: verifyGroup(input.candidates.times, content, words, {
      normalizedValue: (c) => `${c.hour}:${c.minute}`,
    }),
    amounts: verifyGroup(input.candidates.amounts, content, words, {
      normalizedValue: (c) => (c.value === null || c.value === undefined ? null : String(c.value)),
      keywords: AMOUNT_KEYWORDS,
    }),
    phones: verifyGroup(input.candidates.phones, content, words, {
      normalizedValue: (c) => c.normalized_number,
    }),
    references: verifyGroup(input.candidates.references, content, words, {
      normalizedValue: (c) => c.value,
      keywords: REFERENCE_KEYWORDS,
    }),
  };
}

// ── the shared algorithm, parameterised per candidate type ────────────────

interface Span {
  readonly start: number;
  readonly end: number;
}

/** Every candidate type in `ExtractedCandidates` already has this shape. */
interface CommonCandidate {
  readonly raw_text: string;
  readonly is_ambiguous: boolean;
}

interface GroupOptions<T> {
  /** Null means "no value to compare" — never treated as conflict evidence. */
  readonly normalizedValue: (candidate: T) => string | null;
  /**
   * Present only for candidate types whose extractor embeds a label keyword
   * at the start of `raw_text` (amounts, references). Two candidates sharing
   * the same matched keyword are grouped even when their spans are far apart
   * in the document — the same field reported twice, once per label.
   */
  readonly keywords?: readonly string[];
}

function verifyGroup<T extends CommonCandidate>(
  candidates: readonly T[],
  content: string,
  words: readonly AzureWord[],
  options: GroupOptions<T>,
): FieldVerdict[] {
  const n = candidates.length;
  if (n === 0) return [];

  const spans = candidates.map((c) => locateAll(content, c.raw_text));
  const confidences = spans.map((s) => minConfidenceOverSpans(s, words));
  const labelKeys = candidates.map((c) =>
    options.keywords ? matchedKeyword(c.raw_text, options.keywords) : null
  );
  const normalizedValues = candidates.map((c) => options.normalizedValue(c));

  // ── group same-type candidates into "slots" ─────────────────────────────
  const parent = Array.from({ length: n }, (_, i) => i);
  const find = (i: number): number => {
    while (parent[i] !== i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  };
  const union = (a: number, b: number) => {
    const rootA = find(a);
    const rootB = find(b);
    if (rootA !== rootB) parent[rootA] = rootB;
  };

  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      if (spansOverlap(spans[i], spans[j])) {
        union(i, j);
      } else if (labelKeys[i] !== null && labelKeys[i] === labelKeys[j]) {
        union(i, j);
      }
    }
  }

  // ── a slot with >1 distinct value is a conflict for every member ────────
  const valuesByRoot = new Map<number, Set<string>>();
  for (let i = 0; i < n; i++) {
    const value = normalizedValues[i];
    if (value === null) continue;
    const root = find(i);
    const set = valuesByRoot.get(root) ?? new Set<string>();
    set.add(value);
    valuesByRoot.set(root, set);
  }

  const conflictingRoots = new Set<number>();
  for (const [root, values] of valuesByRoot) {
    if (values.size > 1) conflictingRoots.add(root);
  }

  return candidates.map((c, i) => {
    if (conflictingRoots.has(find(i))) {
      return { status: "conflicting", confidence: confidences[i] };
    }

    const confidence = confidences[i];
    const verified = !c.is_ambiguous &&
      confidence !== null &&
      confidence >= VERIFIED_CONFIDENCE_THRESHOLD;

    return { status: verified ? "verified" : "unverified", confidence };
  });
}

// ── locating a candidate's raw text in the OCR content ─────────────────────

/**
 * Every occurrence of `needle` in `content`. A candidate's `raw_text` is
 * always a literal substring of the text the extractor ran over, so a plain
 * `indexOf` walk is sufficient — no normalisation needed on this side.
 */
function locateAll(content: string, needle: string): Span[] {
  if (needle.length === 0) return [];

  const spans: Span[] = [];
  let from = 0;
  while (true) {
    const index = content.indexOf(needle, from);
    if (index === -1) break;
    spans.push({ start: index, end: index + needle.length });
    from = index + 1;
  }
  return spans;
}

function spansOverlap(a: readonly Span[], b: readonly Span[]): boolean {
  for (const spanA of a) {
    for (const spanB of b) {
      if (spanA.start < spanB.end && spanB.start < spanA.end) return true;
    }
  }
  return false;
}

/**
 * The minimum confidence among every word intersecting any occurrence of the
 * candidate. Multiple occurrences and multiple covering words are both
 * folded with `min`, so one weak reading anywhere pulls the whole candidate
 * down — conservative by design, matching the F06-T12 principle that
 * verification only ever lowers trust, never raises it.
 *
 * Null means no word could be matched to any occurrence (an empty `words[]`,
 * or a `stringIndexType` mismatch) — never treated as a stand-in for zero.
 */
function minConfidenceOverSpans(
  spans: readonly Span[],
  words: readonly AzureWord[],
): number | null {
  let min: number | null = null;
  for (const span of spans) {
    for (const word of words) {
      const wordEnd = word.offset + word.length;
      const intersects = word.offset < span.end && span.start < wordEnd;
      if (!intersects) continue;
      if (min === null || word.confidence < min) min = word.confidence;
    }
  }
  return min;
}

/** The longest keyword that `rawText` starts with, compared case-insensitively. */
function matchedKeyword(rawText: string, keywords: readonly string[]): string | null {
  const lower = rawText.toLowerCase();
  let best: string | null = null;
  for (const keyword of keywords) {
    if (lower.startsWith(keyword.toLowerCase())) {
      if (best === null || keyword.length > best.length) best = keyword;
    }
  }
  return best;
}
