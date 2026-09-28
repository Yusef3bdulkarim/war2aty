/**
 * F20-T08 · The T09 quality gates, computed from a run's per-document scores.
 *
 * The tools print these so T09 records numbers rather than re-deriving them by
 * hand. A gate is `null` when this run cannot measure it (no gated documents,
 * no baseline, nothing rated); the owner signs off on T09 either way.
 */

import { GATED_CATEGORIES } from "./truth.ts";
import { mean, percentile } from "./metrics.ts";

export interface GateResult {
  readonly id: string;
  readonly description: string;
  /** `null`: not measurable from this run. */
  readonly passed: boolean | null;
  readonly detail: string;
}

/** Gate thresholds, from the T09 row of the task file. */
export const GATE_LIMITS = {
  g1MaxGatedCer: 0.10,
  g2MinGatedCriticalRecall: 0.9,
  g3MaxP95Ms: 15_000,
  g4MinSemanticValid: 0.97,
  g4MaxGapToGroq: 0.05,
  /** G5: an owner rating at or above this marks an answer acceptable. */
  g5AcceptableRating: 3,
} as const;

function fixed(value: number | null, digits = 3): string {
  return value === null ? "—" : value.toFixed(digits);
}

// ── OCR (G1, G2, G3) ──────────────────────────────────────────────────────

export interface OcrDocumentScore {
  readonly category: string;
  /** `false` when the engine call failed; its metrics are then null. */
  readonly ok: boolean;
  readonly cer: number | null;
  readonly criticalFound: number;
  readonly criticalExpected: number;
  readonly latencyMs: number | null;
}

export function ocrGates(
  scores: readonly OcrDocumentScore[],
  baselineCer: number | null,
): GateResult[] {
  const gated = scores.filter((s) => GATED_CATEGORIES.has(s.category));
  const overallCer = mean(scores.map((s) => s.cer));
  const gatedCer = mean(gated.map((s) => s.cer));

  // Pooled, not averaged per document: one page with a single date should not
  // weigh as much as a bill with ten.
  const expected = gated.reduce((n, s) => n + s.criticalExpected, 0);
  const found = gated.reduce((n, s) => n + s.criticalFound, 0);
  const gatedRecall = expected === 0 ? null : found / expected;

  const latencies = scores.flatMap((
    s,
  ) => (s.ok && s.latencyMs !== null ? [s.latencyMs] : []));
  const p95 = percentile(latencies, 95);

  return [
    {
      id: "G1a",
      description: "CER ≤ recorded Azure baseline",
      passed: overallCer === null || baselineCer === null ? null : overallCer <= baselineCer,
      detail: `CER ${fixed(overallCer)} over ${scores.length} docs vs baseline ${
        fixed(baselineCer)
      } (compare like with like: the baseline set is its own)`,
    },
    {
      id: "G1b",
      description: `CER ≤ ${GATE_LIMITS.g1MaxGatedCer} on C1–C7`,
      passed: gatedCer === null ? null : gatedCer <= GATE_LIMITS.g1MaxGatedCer,
      detail: `CER ${fixed(gatedCer)} over ${gated.length} gated docs`,
    },
    {
      id: "G2",
      description: `critical recall ≥ ${GATE_LIMITS.g2MinGatedCriticalRecall} on C1–C7`,
      passed: gatedRecall === null ? null : gatedRecall >= GATE_LIMITS.g2MinGatedCriticalRecall,
      detail: `${found}/${expected} dates+amounts read`,
    },
    {
      id: "G3",
      description: `p95 latency ≤ ${GATE_LIMITS.g3MaxP95Ms / 1000} s`,
      passed: p95 === null ? null : p95 <= GATE_LIMITS.g3MaxP95Ms,
      detail: `p95 ${
        p95 === null ? "—" : `${(p95 / 1000).toFixed(1)} s`
      } over ${latencies.length} calls`,
    },
  ];
}

// ── analysis (G4, G5) ─────────────────────────────────────────────────────

export interface AnalysisDocumentScore {
  readonly schemaValid: boolean;
  readonly semanticValid: boolean;
  /** The owner's 1–5, from the ratings file. `null` when not rated yet. */
  readonly rating: number | null;
}

/** The comparable rates of a saved Groq run, for G4's "within 5 pp". */
export interface ComparisonRates {
  readonly [metric: string]: number | null;
}

export function analysisGates(input: {
  readonly scores: readonly AnalysisDocumentScore[];
  readonly rates: ComparisonRates;
  readonly groqRates: ComparisonRates | null;
}): GateResult[] {
  const { scores, rates, groqRates } = input;
  const n = scores.length;
  const schemaValid = n === 0 ? null : scores.filter((s) => s.schemaValid).length / n;
  const semanticValid = n === 0 ? null : scores.filter((s) => s.semanticValid).length / n;

  // Every metric Groq was also measured on; Mistral may trail by at most 5 pp.
  const gaps = groqRates === null ? [] : Object.keys(rates).flatMap((metric) => {
    const mine = rates[metric];
    const theirs = groqRates[metric];
    return mine === null || theirs === null || theirs === undefined
      ? []
      : [{ metric, gap: theirs - mine }];
  });
  const worst = gaps.reduce<{ metric: string; gap: number } | null>(
    (w, g) => (w === null || g.gap > w.gap ? g : w),
    null,
  );

  // A semantic reject the owner rated acceptable is a false reject (G5).
  const rejected = scores.filter((s) => s.schemaValid && !s.semanticValid);
  const ratedRejects = rejected.filter((s) => s.rating !== null);
  const falseRejects = ratedRejects.filter((s) => s.rating! >= GATE_LIMITS.g5AcceptableRating);

  return [
    {
      id: "G4a",
      description: "100 % schema-valid",
      passed: schemaValid === null ? null : schemaValid === 1,
      detail: `${scores.filter((s) => s.schemaValid).length}/${n}`,
    },
    {
      id: "G4b",
      description: `≥ ${GATE_LIMITS.g4MinSemanticValid * 100} % semantic-valid`,
      passed: semanticValid === null ? null : semanticValid >= GATE_LIMITS.g4MinSemanticValid,
      detail: `${scores.filter((s) => s.semanticValid).length}/${n}`,
    },
    {
      id: "G4c",
      description: `within ${GATE_LIMITS.g4MaxGapToGroq * 100} pp of Groq`,
      passed: worst === null ? null : worst.gap <= GATE_LIMITS.g4MaxGapToGroq,
      detail: worst === null
        ? "no saved Groq run to compare (--compare)"
        : `largest gap ${(worst.gap * 100).toFixed(1)} pp on ${worst.metric}`,
    },
    {
      id: "G5",
      description: "zero semantic false rejects",
      passed: rejected.length === 0
        ? true
        : ratedRejects.length < rejected.length
        ? null
        : falseRejects.length === 0,
      detail:
        `${rejected.length} rejected, ${ratedRejects.length} rated, ${falseRejects.length} rated acceptable`,
    },
  ];
}

export function printGates(gates: readonly GateResult[]): void {
  console.log("");
  console.log("gates");
  console.log("─".repeat(92));
  for (const gate of gates) {
    const mark = gate.passed === null ? "  ?  " : gate.passed ? "PASS " : "FAIL ";
    console.log(
      `${mark} ${gate.id.padEnd(4)} ${gate.description.padEnd(34)} ${gate.detail}`,
    );
  }
}
