/**
 * F20-T08 · Analysis benchmark — how each analysis provider does on the
 * corpus, from each kind of text.
 *
 * Built on `compare-providers.ts`: the same legs (`benchmark/legs.ts`), the
 * same prompt and schema, and the same shape and semantic checks as
 * production. It runs over the corpus instead of one pasted document, and
 * over three texts per document: the owner's truth (`--source truth`), and
 * what Gemini or Tesseract read (`--source gemini|tesseract`, written by
 * `ocr-benchmark.ts`).
 *
 * ── Metrics (T09) ─────────────────────────────────────────────────────────
 * Per document, per category and overall: schema-valid and semantic-valid
 * rates (with the S-rules that fired), document-type accuracy, date and
 * amount precision/recall against the truth's `key_dates`/`key_amounts`, the
 * Arabic-summary rate, `finish_reason: "length"` count, tokens, latency, and
 * the owner's rating. Then the G4 and G5 gates.
 *
 * Type, date and amount scores need truth schema v2 (T02); on a v1 file they
 * read "—". Quality is scored on accepted answers only: a rejected one never
 * reaches the user.
 *
 * ── The owner's rating ────────────────────────────────────────────────────
 * Every answer, accepted or rejected, is written to `--out` as
 * `<image>.<source>.<analyser>.json`. The owner reads them there and records
 * a 1–5 score in `<out>/ratings.json` under the same name:
 *   { "bill.jpg.truth.mistral": 4, "bill.jpg.truth.groq": 3 }
 * Re-running picks the ratings up. G5 counts a semantically REJECTED answer
 * rated 3 or more as a false reject.
 *
 * PRIVACY (§7, §51): stdout carries metrics only. Answers are written to the
 * git-ignored `--out` folder (`golden*`). Both providers run on free tiers
 * that may keep and review input (accepted, D8).
 *
 * Usage (from the repo root):
 *   deno run --allow-read --allow-write --allow-env --allow-net \
 *     --env-file=supabase/.env supabase/tools/analysis-benchmark.ts \
 *     --analyser mistral --source truth --save golden-analysis/mistral-truth.json
 *
 *   --analyser <name>   mistral | groq                           (required)
 *   --source <text>     truth | gemini | tesseract               (default: truth)
 *   --set <dir>         Images and truth files.                  (default: golden)
 *   --text-in <dir>     Transcriptions from ocr-benchmark.       (default: golden-ocr)
 *   --out <dir>         Where answers and ratings.json live.     (default: golden-analysis)
 *   --compare <file>    A saved Groq run, for G4's "within 5 pp of Groq".
 *   --save <file>       Save this run's metrics (no text) as JSON.
 *   --timeout <s>       Per-document budget.                     (default: 25)
 *   --delay <ms>        Pause after each call.   (default: 2000 mistral, 30000 groq)
 */

import { assertModelAnalysis } from "../functions/_shared/ai/analysis-provider.ts";
import { semanticViolations } from "../functions/_shared/analysis/semantic-validation.ts";
import type { ModelAnalysis } from "../functions/_shared/schemas/analysis-output.schema.ts";
import {
  candidatesFor,
  failureLabel,
  flag,
  listImages,
  loadTruth,
  numberFlag,
  sleep,
  transcriptionPath,
  withBackoff,
} from "./benchmark/corpus.ts";
import type { GroundTruth } from "./benchmark/truth.ts";
import {
  type AnalyserName,
  ANALYSERS,
  analysisLeg,
  DEFAULT_DELAY_MS,
  recordingFetch,
} from "./benchmark/legs.ts";
import {
  arabicLetterShare,
  mean,
  percent,
  percentile,
  precisionRecall,
  rate,
  sameAmount,
} from "./benchmark/metrics.ts";
import {
  type AnalysisDocumentScore,
  analysisGates,
  type ComparisonRates,
  printGates,
} from "./benchmark/gates.ts";

const SOURCES = ["truth", "gemini", "tesseract"] as const;
type Source = typeof SOURCES[number];

/** An answer whose letters are at least half Arabic counts as an Arabic summary. */
const ARABIC_SUMMARY_SHARE = 0.5;

interface DocumentRow extends AnalysisDocumentScore {
  readonly file: string;
  readonly category: string;
  /** A completion arrived (HTTP 200). Only these count towards G4. */
  readonly answered: boolean;
  readonly failure: string | null;
  readonly semanticRules: string[];
  readonly lengthFinish: boolean;
  readonly promptTokens: number | null;
  readonly completionTokens: number | null;
  readonly latencyMs: number;
  readonly typeCorrect: boolean | null;
  readonly datePrecision: number | null;
  readonly dateRecall: number | null;
  readonly amountPrecision: number | null;
  readonly amountRecall: number | null;
  readonly arabicSummary: boolean | null;
}

// ── scoring ───────────────────────────────────────────────────────────────

function parseAnswer(content: string | null): ModelAnalysis | null {
  if (content === null) return null;
  try {
    return assertModelAnalysis(JSON.parse(content));
  } catch {
    return null;
  }
}

/** Quality against the truth. Only an accepted answer is scored; v1 truth has no key fields. */
function quality(truth: GroundTruth, accepted: ModelAnalysis | null) {
  if (accepted === null) {
    return {
      typeCorrect: null,
      datePrecision: null,
      dateRecall: null,
      amountPrecision: null,
      amountRecall: null,
      arabicSummary: null,
    };
  }

  const v2 = truth.schemaVersion === 2;
  const dates = precisionRecall(
    accepted.dates.map((d) => d.date),
    truth.keyDates,
    (a, b) => a === b,
  );
  const amounts = precisionRecall(
    accepted.amounts.map((a) => a.value),
    truth.keyAmounts,
    sameAmount,
  );
  const share = arabicLetterShare(accepted.summary.detailed);

  return {
    typeCorrect: v2 && truth.expectedDocumentType !== null
      ? accepted.document_type.type === truth.expectedDocumentType
      : null,
    datePrecision: v2 ? dates.precision : null,
    dateRecall: v2 ? dates.recall : null,
    amountPrecision: v2 ? amounts.precision : null,
    amountRecall: v2 ? amounts.recall : null,
    arabicSummary: share === null ? null : share >= ARABIC_SUMMARY_SHARE,
  };
}

/** The rates G4 compares with Groq's. Inferred, so `summary` keeps the named fields. */
function rates(rows: readonly DocumentRow[]) {
  const answered = rows.filter((r) => r.answered);
  return {
    semanticValid: rate(answered.map((r) => r.semanticValid)),
    typeAccuracy: rate(rows.map((r) => r.typeCorrect)),
    datePrecision: mean(rows.map((r) => r.datePrecision)),
    dateRecall: mean(rows.map((r) => r.dateRecall)),
    amountPrecision: mean(rows.map((r) => r.amountPrecision)),
    amountRecall: mean(rows.map((r) => r.amountRecall)),
    arabicSummary: rate(rows.map((r) => r.arabicSummary)),
  };
}

function summary(rows: readonly DocumentRow[]) {
  const answered = rows.filter((r) => r.answered);
  const latencies = rows.map((r) => r.latencyMs);
  const rated = rows.flatMap((r) => (r.rating === null ? [] : [r.rating]));
  return {
    documents: rows.length,
    errorRate: rows.length === 0
      ? null
      : rows.filter((r) => r.failure !== null).length / rows.length,
    schemaValid: rate(answered.map((r) => r.schemaValid)),
    ...rates(rows),
    lengthFinishes: rows.filter((r) => r.lengthFinish).length,
    meanPromptTokens: mean(rows.map((r) => r.promptTokens)),
    meanCompletionTokens: mean(rows.map((r) => r.completionTokens)),
    p50Ms: percentile(latencies, 50),
    p95Ms: percentile(latencies, 95),
    meanRating: mean(rated),
    rated: rated.length,
  };
}

// ── reporting ─────────────────────────────────────────────────────────────

function tokens(value: number | null): string {
  return value === null ? "   —" : String(Math.round(value)).padStart(5);
}

function seconds(ms: number | null): string {
  return ms === null ? "  —  " : `${(ms / 1000).toFixed(1)}s`.padStart(6);
}

function report(rows: readonly DocumentRow[]): void {
  const categories = [...new Set(rows.map((r) => r.category))].sort();

  console.log("");
  console.log(
    "category      n   err schema  sem   type  date-P date-R  amt-P  amt-R  arabic len " +
      " in-tok out-tok   p50    p95  rating",
  );
  console.log("─".repeat(124));

  const line = (label: string, group: readonly DocumentRow[]) => {
    const s = summary(group);
    console.log(
      label.padEnd(12) +
        String(s.documents).padStart(3) +
        " " + percent(s.errorRate) +
        " " + percent(s.schemaValid) +
        " " + percent(s.semanticValid) +
        " " + percent(s.typeAccuracy) +
        " " + percent(s.datePrecision) +
        " " + percent(s.dateRecall) +
        " " + percent(s.amountPrecision) +
        " " + percent(s.amountRecall) +
        " " + percent(s.arabicSummary) +
        String(s.lengthFinishes).padStart(4) +
        "  " + tokens(s.meanPromptTokens) +
        "   " + tokens(s.meanCompletionTokens) +
        " " + seconds(s.p50Ms) +
        " " + seconds(s.p95Ms) +
        "  " +
        (s.meanRating === null ? "  —" : s.meanRating.toFixed(2).padStart(5)),
    );
  };

  for (const category of categories) {
    line(
      category,
      rows.filter((r) => r.category === category),
    );
  }
  console.log("─".repeat(124));
  line("ALL", rows);

  const tally = (values: string[]) => {
    const counts = new Map<string, number>();
    for (const v of values) counts.set(v, (counts.get(v) ?? 0) + 1);
    return [...counts].map(([k, n]) => `${k}×${n}`).join(", ");
  };
  const failures = rows.flatMap((r) => (r.failure === null ? [] : [r.failure]));
  const rules = rows.flatMap((r) => r.semanticRules);
  if (failures.length > 0) console.log(`\nfailures: ${tally(failures)}`);
  if (rules.length > 0) console.log(`semantic rules fired: ${tally(rules)}`);
}

async function readJson(
  path: string | null,
): Promise<Record<string, unknown> | null> {
  if (path === null) return null;
  try {
    return JSON.parse(await Deno.readTextFile(path));
  } catch {
    return null;
  }
}

// ── entry point ───────────────────────────────────────────────────────────

async function main(args: readonly string[]): Promise<void> {
  const analyser = flag(args, "analyser") as AnalyserName | null;
  if (analyser === null || !ANALYSERS.includes(analyser)) {
    throw new Error("--analyser must be mistral or groq.");
  }
  const source = flag(args, "source", "truth") as Source;
  if (!SOURCES.includes(source)) {
    throw new Error("--source must be truth, gemini or tesseract.");
  }

  const setDir = flag(args, "set", "golden");
  const textDir = flag(args, "text-in", "golden-ocr");
  const outDir = flag(args, "out", "golden-analysis");
  const timeoutSeconds = numberFlag(args, "timeout", 25);
  const delayMs = numberFlag(args, "delay", DEFAULT_DELAY_MS[analyser]);

  // Built before any document is read: a missing key fails here, and the
  // message names the variable only.
  const recorder = recordingFetch();
  const leg = analysisLeg(analyser, recorder.fetchImpl);

  await Deno.mkdir(outDir, { recursive: true });
  const ratings = (await readJson(`${outDir}/ratings.json`)) ?? {};

  const rows: DocumentRow[] = [];
  const skipped: { file: string; reason: string }[] = [];

  for (const image of await listImages(setDir)) {
    const status = await loadTruth(image);
    if (status.kind === "skip") {
      skipped.push({ file: image.name, reason: status.reason });
      continue;
    }
    const truth = status.truth;

    let text: string;
    if (source === "truth") {
      text = truth.text;
    } else {
      try {
        text = await Deno.readTextFile(
          transcriptionPath(textDir, image.name, source),
        );
      } catch {
        skipped.push({
          file: image.name,
          reason: `no ${source} transcription — run ocr-benchmark`,
        });
        continue;
      }
    }
    if (text.trim().length === 0) {
      // O2: the app shows a blank reading as poor quality and never analyses it.
      skipped.push({
        file: image.name,
        reason: "empty transcription, never analysed (O2)",
      });
      continue;
    }

    const input = {
      ocrText: text,
      detectedLanguages: truth.languages.length > 0
        ? truth.languages
        : (arabicLetterShare(text) ?? 0) > 0
        ? ["ar"]
        : ["en"],
      candidates: candidatesFor(text),
    };

    recorder.reset();
    const startedAt = performance.now();
    let accepted: ModelAnalysis | null = null;
    let failure: string | null = null;
    try {
      accepted = await withBackoff(
        () => leg(input, AbortSignal.timeout(timeoutSeconds * 1000)),
        (s, attempt) => console.log(`    … rate limited, waiting ${s}s (attempt ${attempt})`),
      );
    } catch (thrown) {
      failure = failureLabel(thrown);
    }
    const latencyMs = performance.now() - startedAt;

    const recorded = recorder.last();
    const answered = recorded?.status === 200;
    const parsed = parseAnswer(recorded?.content ?? null);
    const semanticRules = parsed === null ? [] : semanticViolations(parsed, text);
    const key = `${image.name}.${source}.${analyser}`;
    const rating = typeof ratings[key] === "number" ? ratings[key] as number : null;

    await Deno.writeTextFile(
      `${outDir}/${key}.json`,
      `${
        JSON.stringify(
          {
            outcome: failure ?? "accepted",
            finish_reason: recorded?.finishReason ?? null,
            semantic_violations: semanticRules,
            analysis: parsed,
            // Only when the answer did not parse, so the owner can see why.
            raw_content: parsed === null ? recorded?.content ?? null : undefined,
          },
          null,
          2,
        )
      }\n`,
    );

    const row: DocumentRow = {
      file: image.name,
      category: truth.category,
      answered,
      failure,
      schemaValid: parsed !== null,
      semanticValid: parsed !== null && semanticRules.length === 0,
      semanticRules,
      lengthFinish: recorded?.finishReason === "length",
      promptTokens: recorded?.promptTokens ?? null,
      completionTokens: recorded?.completionTokens ?? null,
      latencyMs,
      rating,
      ...quality(truth, accepted),
    };
    rows.push(row);

    console.log(
      `  ${failure === null ? "·" : "!"} ${image.name}  [${truth.category}]  ` +
        `${(latencyMs / 1000).toFixed(1)}s` +
        (failure === null ? "" : `  failed: ${failure}`) +
        (semanticRules.length > 0 ? `  (${semanticRules.join(",")})` : ""),
    );
    await sleep(delayMs);
  }

  if (skipped.length > 0) {
    console.log(`\nSkipped ${skipped.length}:`);
    for (const { file, reason } of skipped) {
      console.log(`  ! ${file} — ${reason}`);
    }
  }
  if (rows.length === 0) {
    console.log("\nNothing scored.");
    return;
  }

  console.log(
    `\n${analyser} over ${source} text. Answers: ${outDir}/<image>.${source}.${analyser}.json`,
  );
  report(rows);

  const compared = analyser === "mistral" ? await readJson(flag(args, "compare")) : null;
  const groqRates = (compared?.rates as ComparisonRates | undefined) ?? null;
  printGates(
    analysisGates({
      scores: rows.filter((r) => r.answered),
      rates: rates(rows),
      groqRates,
    }),
  );

  const savePath = flag(args, "save");
  if (savePath !== null) {
    const categories = [...new Set(rows.map((r) => r.category))].sort();
    const payload = {
      recordedAt: new Date().toISOString(),
      analyser,
      source,
      rates: rates(rows),
      overall: summary(rows),
      byCategory: Object.fromEntries(
        categories.map((
          c,
        ) => [c, summary(rows.filter((r) => r.category === c))]),
      ),
      documents: rows,
    };
    await Deno.writeTextFile(savePath, `${JSON.stringify(payload, null, 2)}\n`);
    console.log(`\nSaved to ${savePath}`);
  }
}

if (import.meta.main) {
  try {
    await main(Deno.args);
  } catch (thrown) {
    console.error(thrown instanceof Error ? thrown.message : thrown);
    Deno.exit(1);
  }
}
