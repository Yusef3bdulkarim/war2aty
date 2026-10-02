/**
 * F20-T08 · Ground truth for the benchmark corpus.
 *
 * One sidecar per image, `<image>.truth.json`, in the git-ignored `golden/`.
 * F17 wrote schema v1. T02 moves the corpus to v2, which adds what the
 * ANALYSIS benchmark needs: the document's languages, its expected type, and
 * the key dates, amounts and actions in normalised form.
 *
 * A v1 file still loads. Its v2 fields read as empty or null, so the OCR
 * metrics work on it and the analysis metrics that need v2 report "—".
 *
 * ── Schema v2 ─────────────────────────────────────────────────────────────
 *   schema_version          2
 *   category                "C1".."C10" (T02), or "UNCATEGORISED" for a
 *                           draft nobody has corrected, or "EXCLUDE"
 *   writer                  handwriting only: who wrote it, else null
 *   languages               ["ar"], ["en"] or ["ar", "en"]
 *   text                    the page, transcribed by hand          (OCR: CER/WER)
 *   dates, amounts          as PRINTED, e.g. "١٥/٠٨/٢٠٢٦"          (OCR: critical fields)
 *   phones, references      as printed
 *   expected_document_type  one of the analysis schema's types, or null
 *   key_dates               ISO "YYYY-MM-DD"                        (analysis: date P/R)
 *   key_amounts             numbers, e.g. 850.5                     (analysis: amount P/R)
 *   key_actions             what the reader must do, in Arabic      (read by the owner when rating)
 *   needsOwnerCheck         fields only the owner can settle; non-empty means
 *                           the file is not yet truth
 */

export interface GroundTruth {
  readonly schemaVersion: 1 | 2;
  readonly category: string;
  readonly writer: string | null;
  readonly languages: readonly string[];
  readonly text: string;
  readonly dates: readonly string[];
  readonly amounts: readonly string[];
  readonly phones: readonly string[];
  readonly references: readonly string[];
  readonly expectedDocumentType: string | null;
  readonly keyDates: readonly string[];
  readonly keyAmounts: readonly number[];
  readonly keyActions: readonly string[];
  readonly needsOwnerCheck: readonly string[];
}

/** Written by `--bootstrap`, and only a human editing the file changes it. */
export const DRAFT_CATEGORY = "UNCATEGORISED";
export const EXCLUDED_CATEGORY = "EXCLUDE";

/**
 * The categories the quality gates are judged on (T09: G1, G2). C8 poor
 * quality, C9 skew and C10 handwriting are reported but not gated.
 */
export const GATED_CATEGORIES: ReadonlySet<string> = new Set([
  "C1",
  "C2",
  "C3",
  "C4",
  "C5",
  "C6",
  "C7",
]);

export type TruthStatus =
  | { readonly kind: "ready"; readonly truth: GroundTruth }
  | { readonly kind: "skip"; readonly reason: string };

function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];
}

function numbers(value: unknown): number[] {
  return Array.isArray(value)
    ? value.filter((v): v is number => typeof v === "number" && Number.isFinite(v))
    : [];
}

/**
 * Parses a truth file and decides whether it may be scored.
 *
 * An uncorrected draft is never scored: its `text` is the bootstrap engine's
 * own output, so scoring it would compare that engine against itself and
 * report a flawless CER, the most dangerous possible result because it looks
 * like success.
 */
export function readTruth(raw: unknown): TruthStatus {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    return { kind: "skip", reason: "truth file is not a JSON object" };
  }
  const r = raw as Record<string, unknown>;

  if (typeof r.text !== "string" || typeof r.category !== "string") {
    return { kind: "skip", reason: "truth file has no text or category" };
  }
  if (r.category === DRAFT_CATEGORY) {
    return {
      kind: "skip",
      reason: "draft never corrected — category is still UNCATEGORISED",
    };
  }
  if (r.category === EXCLUDED_CATEGORY) {
    return { kind: "skip", reason: "excluded by its ground-truth file" };
  }

  return {
    kind: "ready",
    truth: {
      schemaVersion: r.schema_version === 2 ? 2 : 1,
      category: r.category,
      writer: typeof r.writer === "string" ? r.writer : null,
      languages: strings(r.languages),
      text: r.text,
      dates: strings(r.dates),
      amounts: strings(r.amounts),
      phones: strings(r.phones),
      references: strings(r.references),
      expectedDocumentType: typeof r.expected_document_type === "string"
        ? r.expected_document_type
        : null,
      keyDates: strings(r.key_dates),
      keyAmounts: numbers(r.key_amounts),
      keyActions: strings(r.key_actions),
      needsOwnerCheck: strings(r.needsOwnerCheck),
    },
  };
}

/** A v2 draft for the owner to correct. Its text is the bootstrap reading. */
export function draftTruth(text: string): Record<string, unknown> {
  return {
    schema_version: 2,
    category: DRAFT_CATEGORY,
    writer: null,
    languages: [],
    text,
    dates: [],
    amounts: [],
    phones: [],
    references: [],
    expected_document_type: null,
    key_dates: [],
    key_amounts: [],
    key_actions: [],
    needsOwnerCheck: [],
  };
}
