/**
 * F36-T18 · Explain benchmark — reading + explanation quality over the corpus.
 *
 * Runs the full `explain-document` pipeline (read image → explain text) one
 * explainer at a time, reusing cached readings across runs. Scores:
 *
 * 1. **Reading accuracy** — CER and WER of the Gemini reading against the
 *    truth text (reuses the OCR benchmark's metrics).
 * 2. **Explanation quality** — schema validity, grounding, page cap, the §33
 *    caps (title ≤ 24, paragraphs ≤ 4 × 220, page ≤ 850).
 * 3. **Latency per stage** — read and explain independently, plus the total.
 * 4. **Gemma schema enforcement** (trap #2) — whether Gemma 4 on the native
 *    API with `responseJsonSchema` actually returns constrained JSON. If it
 *    does, T11 promotes it out of EXPERIMENT; if not, leg 3 is decorative.
 *
 * The reading is the first model from `GEMINI_OCR_MODELS` (T08). Readings
 * are cached in `--text-out`, so subsequent runs with different explainers
 * reuse them. Each explainer is the production leg (the same client, prompt
 * and schema), not a mock.
 *
 * PRIVACY (§7, §51): stdout carries metrics only. Explanations are written to
 * the git-ignored `--out` folder (`golden*`). All providers run on free tiers
 * that may keep and review input.
 *
 * Usage (from the repo root):
 *   deno run --allow-read --allow-write --allow-env --allow-net \
 *     --env-file=supabase/.env supabase/tools/explain-benchmark.ts \
 *     --explainer mistral --save golden-explain/mistral.json
 *
 *   --explainer <name>   mistral | groq | gemma                   (required)
 *   --set <dir>          Images and truth files.                  (default: golden)
 *   --text-out <dir>     Cached Gemini readings.                  (default: golden-ocr)
 *   --out <dir>          Where explanations live.                 (default: golden-explain)
 *   --save <file>        Save this run's metrics (no text) as JSON.
 *   --timeout <s>        Per-document read budget.                (default: 15)
 *   --explain-timeout <s> Per-document explain budget.            (default: 25)
 *   --delay <ms>         Pause between documents.                 (default: per-provider)
 *   --skip-read          Reuse cached readings; fail if none.
 *   --ratings <file>     Owner's 1–5 quality ratings.             (default: <out>/ratings.json)
 */

import { createGeminiOcrClient } from "../functions/_shared/ai/gemini-ocr-client.ts";
import { geminiReadingOptionsFromEnv } from "../functions/_shared/ai/gemini-config.ts";
import { createChatClient } from "../functions/_shared/ai/openai-compatible-client.ts";
import { mistralOptionsFromEnv } from "../functions/_shared/ai/mistral-config.ts";
import { GROQ_REASONING_EFFORT, groqOptionsFromEnv } from "../functions/_shared/ai/groq-config.ts";
import { gemmaOptionsFromEnv } from "../functions/_shared/ai/gemma-config.ts";
import { createGemmaNativeClient } from "../functions/_shared/ai/gemma-native-client.ts";
import { assertModelExplanation, createExplainLeg } from "../functions/_shared/ai/explain-chain.ts";
import type { ModelExplanation } from "../functions/_shared/schemas/explain-output.schema.ts";
import {
  EXPLAIN_MAX_PARAGRAPHS,
  EXPLAIN_PAGE_MAX_CHARS,
  EXPLAIN_PARAGRAPH_MAX_CHARS,
  EXPLAIN_TITLE_MAX_CHARS,
} from "../functions/_shared/schemas/explain-output.schema.ts";
import { groundExplanation, pageLength } from "../functions/_shared/validators/explain-grounding.ts";
import type { GroundingReport } from "../functions/_shared/validators/explain-grounding.ts";
import {
  failureLabel,
  flag,
  listImages,
  loadTruth,
  numberFlag,
  sleep,
  stopIfKeyRefused,
  transcriptionPath,
  withBackoff,
} from "./benchmark/corpus.ts";
import { cer, mean, percent, percentile, wer } from "./benchmark/metrics.ts";
import { recordingFetch, type RecordedResponse } from "./benchmark/legs.ts";

type ExplainerName = "mistral" | "groq" | "gemma";

const EXPLAINERS: readonly ExplainerName[] = ["mistral", "groq", "gemma"];

const DEFAULT_DELAY_MS: Readonly<Record<ExplainerName, number>> = {
  mistral: 2_000,
  groq: 30_000,
  gemma: 20_000,
};

// ── the reading leg ────────────────────────────────────────────────────────

function geminiReader(timeoutSeconds: number) {
  const { gemini, models } = geminiReadingOptionsFromEnv();
  const primary = models[0];
  const client = createGeminiOcrClient({ ...gemini, model: primary });
  return {
    model: primary,
    read: async (bytes: Uint8Array, mimeType: string): Promise<{ text: string }> => {
      const result = await withBackoff(
        () => client({ bytes, mimeType }, AbortSignal.timeout(timeoutSeconds * 1000)),
        (s, attempt) => console.log(`    … rate limited, waiting ${s}s (attempt ${attempt})`),
      );
      return { text: result.text };
    },
  };
}

// ── the explaining leg ─────────────────────────────────────────────────────

function explainLeg(name: ExplainerName, recorder: ReturnType<typeof recordingFetch>) {
  switch (name) {
    case "mistral":
      return createExplainLeg({
        client: createChatClient({ ...mistralOptionsFromEnv(), fetchImpl: recorder.fetchImpl }),
      });
    case "groq":
      return createExplainLeg({
        client: createChatClient({ ...groqOptionsFromEnv(), fetchImpl: recorder.fetchImpl }),
        reasoningEffort: GROQ_REASONING_EFFORT,
      });
    case "gemma": {
      const options = gemmaOptionsFromEnv();
      const native = Deno.env.get("GEMMA_ENDPOINT")?.trim() === "native";
      return createExplainLeg({
        client: native
          ? createGemmaNativeClient({ apiKey: options.apiKey, model: options.model, fetchImpl: recorder.fetchImpl })
          : createChatClient({ ...options, fetchImpl: recorder.fetchImpl }),
      });
    }
  }
}

// ── §33 caps ───────────────────────────────────────────────────────────────

interface CapsCheck {
  readonly titleOk: boolean;
  readonly paragraphCountOk: boolean;
  readonly paragraphCapsOk: boolean;
  readonly pageOk: boolean;
  readonly titleLength: number;
  readonly paragraphCount: number;
  readonly pageTotalChars: number;
}

function checkCaps(explanation: ModelExplanation): CapsCheck {
  const titleLength = explanation.paper.title.length;
  const paragraphCount = explanation.explain.length;
  const pageTotalChars = pageLength(explanation);
  return {
    titleOk: titleLength <= EXPLAIN_TITLE_MAX_CHARS,
    paragraphCountOk: paragraphCount >= 1 && paragraphCount <= EXPLAIN_MAX_PARAGRAPHS,
    paragraphCapsOk: explanation.explain.every((p) => p.length <= EXPLAIN_PARAGRAPH_MAX_CHARS),
    pageOk: pageTotalChars <= EXPLAIN_PAGE_MAX_CHARS,
    titleLength,
    paragraphCount,
    pageTotalChars,
  };
}

// ── per-document row ───────────────────────────────────────────────────────

interface DocumentRow {
  readonly file: string;
  readonly category: string;
  // reading
  readonly readCer: number | null;
  readonly readWer: number | null;
  readonly readLatencyMs: number | null;
  readonly readFailure: string | null;
  // explaining
  readonly answered: boolean;
  readonly schemaValid: boolean;
  readonly explainFailure: string | null;
  readonly explainLatencyMs: number | null;
  readonly totalLatencyMs: number | null;
  // caps (before grounding)
  readonly caps: CapsCheck | null;
  // grounding
  readonly groundedStatus: string | null;
  readonly grounding: GroundingReport | null;
  // tokens
  readonly promptTokens: number | null;
  readonly completionTokens: number | null;
  readonly finishReason: string | null;
  // owner rating
  readonly rating: number | null;
}

// ── scoring ────────────────────────────────────────────────────────────────

function parseExplanation(content: string | null): ModelExplanation | null {
  if (content === null) return null;
  try {
    return assertModelExplanation(JSON.parse(content));
  } catch {
    return null;
  }
}

// ── reporting ──────────────────────────────────────────────────────────────

function seconds(ms: number | null): string {
  return ms === null ? "  —  " : `${(ms / 1000).toFixed(1)}s`.padStart(6);
}

function summaryOf(rows: readonly DocumentRow[]) {
  const answered = rows.filter((r) => r.answered);
  const readLatencies = rows.flatMap((r) => r.readLatencyMs !== null ? [r.readLatencyMs] : []);
  const explainLatencies = rows.flatMap((r) => r.explainLatencyMs !== null ? [r.explainLatencyMs] : []);
  const totalLatencies = rows.flatMap((r) => r.totalLatencyMs !== null ? [r.totalLatencyMs] : []);
  const rated = rows.flatMap((r) => r.rating !== null ? [r.rating] : []);

  return {
    documents: rows.length,
    readErrors: rows.filter((r) => r.readFailure !== null).length,
    explainErrors: rows.filter((r) => r.explainFailure !== null).length,
    readCer: mean(rows.map((r) => r.readCer)),
    readWer: mean(rows.map((r) => r.readWer)),
    schemaValid: answered.length === 0 ? null : answered.filter((r) => r.schemaValid).length / answered.length,
    titleOk: answered.length === 0 ? null : answered.filter((r) => r.caps?.titleOk).length / answered.length,
    paragraphCapsOk: answered.length === 0 ? null : answered.filter((r) => r.caps?.paragraphCapsOk).length / answered.length,
    pageOkBeforeGrounding: answered.length === 0 ? null : answered.filter((r) => r.caps?.pageOk).length / answered.length,
    pageOkAfterGrounding: answered.length === 0 ? null : answered.filter((r) => r.grounding?.fitsPage).length / answered.length,
    groundedPartial: answered.length === 0 ? null : answered.filter((r) => r.groundedStatus === "partial").length / answered.length,
    labelsCleaned: rows.reduce((n, r) => n + (r.grounding?.labelsCleaned ?? 0), 0),
    medicalClaimsRemoved: rows.reduce((n, r) => n + (r.grounding?.medicalClaimsRemoved ?? 0), 0),
    readP50Ms: percentile(readLatencies, 50),
    readP95Ms: percentile(readLatencies, 95),
    explainP50Ms: percentile(explainLatencies, 50),
    explainP95Ms: percentile(explainLatencies, 95),
    totalP50Ms: percentile(totalLatencies, 50),
    totalP95Ms: percentile(totalLatencies, 95),
    meanPromptTokens: mean(rows.map((r) => r.promptTokens)),
    meanCompletionTokens: mean(rows.map((r) => r.completionTokens)),
    meanRating: mean(rated),
    rated: rated.length,
  };
}

function report(rows: readonly DocumentRow[]): void {
  const categories = [...new Set(rows.map((r) => r.category))].sort();

  console.log("");
  console.log(
    "category            n  r-err  CER    WER  x-err schema title  pg-cap " +
      "partial  r-p50  r-p95  x-p50  x-p95  t-p50  t-p95  rating",
  );
  console.log("─".repeat(136));

  const line = (label: string, group: readonly DocumentRow[]) => {
    const s = summaryOf(group);
    console.log(
      label.padEnd(18) +
        String(s.documents).padStart(3) +
        String(s.readErrors).padStart(6) +
        " " + percent(s.readCer) +
        " " + percent(s.readWer) +
        String(s.explainErrors).padStart(6) +
        " " + percent(s.schemaValid) +
        " " + percent(s.titleOk) +
        " " + percent(s.pageOkAfterGrounding) +
        " " + percent(s.groundedPartial) +
        " " + seconds(s.readP50Ms) +
        " " + seconds(s.readP95Ms) +
        " " + seconds(s.explainP50Ms) +
        " " + seconds(s.explainP95Ms) +
        " " + seconds(s.totalP50Ms) +
        " " + seconds(s.totalP95Ms) +
        "  " +
        (s.meanRating === null ? "  —" : s.meanRating.toFixed(2).padStart(5)),
    );
  };

  for (const category of categories) {
    line(category, rows.filter((r) => r.category === category));
  }
  console.log("─".repeat(136));
  line("ALL", rows);

  const tally = (values: string[]) => {
    const counts = new Map<string, number>();
    for (const v of values) counts.set(v, (counts.get(v) ?? 0) + 1);
    return [...counts].map(([k, n]) => `${k}×${n}`).join(", ");
  };
  const readFails = rows.flatMap((r) => r.readFailure !== null ? [r.readFailure] : []);
  const explainFails = rows.flatMap((r) => r.explainFailure !== null ? [r.explainFailure] : []);
  if (readFails.length > 0) console.log(`\nread failures: ${tally(readFails)}`);
  if (explainFails.length > 0) console.log(`\nexplain failures: ${tally(explainFails)}`);

  const finishes = rows.flatMap((r) => r.finishReason !== null ? [r.finishReason] : []);
  if (finishes.length > 0) console.log(`finish_reasons: ${tally(finishes)}`);
}

// ── Gemma schema enforcement gate ──────────────────────────────────────────

function gemmaGate(rows: readonly DocumentRow[]): void {
  const answered = rows.filter((r) => r.answered);
  if (answered.length === 0) {
    console.log("\nGemma schema enforcement: no answered documents to measure.");
    return;
  }
  const valid = answered.filter((r) => r.schemaValid).length;
  const pct = ((valid / answered.length) * 100).toFixed(1);
  const pass = valid === answered.length;
  console.log("");
  console.log("─".repeat(72));
  console.log(
    `${pass ? "PASS" : "FAIL"}  Gemma schema enforcement: ${valid}/${answered.length} (${pct}%)`,
  );
  console.log(
    pass
      ? "  → Gemma 4 honours responseJsonSchema. T11 may promote it."
      : "  → Gemma 4 does NOT enforce the schema. Leg 3 is decorative.",
  );
  console.log("─".repeat(72));
}

// ── D4 budget gate ─────────────────────────────────────────────────────────

function budgetGate(rows: readonly DocumentRow[]): void {
  const totals = rows.flatMap((r) => r.totalLatencyMs !== null ? [r.totalLatencyMs] : []);
  const reads = rows.flatMap((r) => r.readLatencyMs !== null ? [r.readLatencyMs] : []);
  const explains = rows.flatMap((r) => r.explainLatencyMs !== null ? [r.explainLatencyMs] : []);
  if (totals.length === 0) return;

  const rp95 = percentile(reads, 95);
  const ep95 = percentile(explains, 95);
  const tp95 = percentile(totals, 95);

  console.log("");
  console.log("D4 budget check (read 10 s + explain 20 s = 30 s total):");
  console.log(`  read   p95: ${seconds(rp95)}  ${rp95 !== null && rp95 <= 10_000 ? "✓" : "✗"} (budget: 10 s)`);
  console.log(`  explain p95: ${seconds(ep95)}  ${ep95 !== null && ep95 <= 20_000 ? "✓" : "✗"} (budget: 20 s)`);
  console.log(`  total  p95: ${seconds(tp95)}  ${tp95 !== null && tp95 <= 30_000 ? "✓" : "✗"} (budget: 30 s)`);
}

// ── entry point ────────────────────────────────────────────────────────────

async function readJson(path: string): Promise<Record<string, unknown> | null> {
  try {
    return JSON.parse(await Deno.readTextFile(path));
  } catch {
    return null;
  }
}

async function main(args: readonly string[]): Promise<void> {
  const explainerName = flag(args, "explainer") as ExplainerName | null;
  if (explainerName === null || !EXPLAINERS.includes(explainerName)) {
    throw new Error("--explainer must be mistral, groq or gemma.");
  }

  const setDir = flag(args, "set", "golden");
  const textDir = flag(args, "text-out", "golden-ocr");
  const outDir = flag(args, "out", "golden-explain");
  const readTimeout = numberFlag(args, "timeout", 15);
  const explainTimeout = numberFlag(args, "explain-timeout", 25);
  const delayMs = numberFlag(args, "delay", DEFAULT_DELAY_MS[explainerName]);
  const skipRead = args.includes("--skip-read");
  const ratingsPath = flag(args, "ratings", `${outDir}/ratings.json`);

  const recorder = recordingFetch();
  const leg = explainLeg(explainerName, recorder);

  let reader: ReturnType<typeof geminiReader> | null = null;
  if (!skipRead) {
    reader = geminiReader(readTimeout);
    console.log(`Reading with ${reader.model}`);
  }

  console.log(`Explaining with ${explainerName}\n`);

  await Deno.mkdir(outDir, { recursive: true });
  await Deno.mkdir(textDir, { recursive: true });
  const ratings = (await readJson(ratingsPath)) ?? {};

  const rows: DocumentRow[] = [];
  const skipped: { file: string; reason: string }[] = [];

  for (const image of await listImages(setDir)) {
    if (image.mimeType === null) {
      skipped.push({ file: image.name, reason: "unsupported format" });
      continue;
    }

    const status = await loadTruth(image);
    if (status.kind === "skip") {
      skipped.push({ file: image.name, reason: status.reason });
      continue;
    }
    const truth = status.truth;

    // ── stage 1: read ────────────────────────────────────────────────────
    let readingText: string | null = null;
    let readLatencyMs: number | null = null;
    let readFailure: string | null = null;

    const cachedPath = transcriptionPath(textDir, image.name, "gemini");

    if (skipRead) {
      try {
        readingText = await Deno.readTextFile(cachedPath);
      } catch {
        skipped.push({ file: image.name, reason: "no cached reading — run without --skip-read" });
        continue;
      }
    } else {
      try {
        const bytes = await Deno.readFile(image.path);
        const startedAt = performance.now();
        const result = await reader!.read(bytes, image.mimeType);
        readLatencyMs = performance.now() - startedAt;
        readingText = result.text;
        await Deno.writeTextFile(cachedPath, readingText);
      } catch (thrown) {
        stopIfKeyRefused(thrown, "GEMINI_API_KEY");
        readFailure = failureLabel(thrown);
      }
    }

    if (readingText === null) {
      rows.push({
        file: image.name,
        category: truth.category,
        readCer: null,
        readWer: null,
        readLatencyMs,
        readFailure,
        answered: false,
        schemaValid: false,
        explainFailure: null,
        explainLatencyMs: null,
        totalLatencyMs: null,
        caps: null,
        groundedStatus: null,
        grounding: null,
        promptTokens: null,
        completionTokens: null,
        finishReason: null,
        rating: null,
      });
      console.log(`  ! ${image.name}  [${truth.category}]  read failed: ${readFailure}`);
      await sleep(delayMs);
      continue;
    }

    const readCer = cer(truth.text, readingText);
    const readWer = wer(truth.text, readingText);

    if (readingText.trim().length === 0) {
      rows.push({
        file: image.name,
        category: truth.category,
        readCer,
        readWer,
        readLatencyMs,
        readFailure: null,
        answered: false,
        schemaValid: false,
        explainFailure: "empty_reading",
        explainLatencyMs: null,
        totalLatencyMs: null,
        caps: null,
        groundedStatus: null,
        grounding: null,
        promptTokens: null,
        completionTokens: null,
        finishReason: null,
        rating: null,
      });
      console.log(`  - ${image.name}  [${truth.category}]  empty reading (O2)`);
      await sleep(delayMs);
      continue;
    }

    // ── stage 2: explain ─────────────────────────────────────────────────
    recorder.reset();
    const explainStart = performance.now();
    let explanation: ModelExplanation | null = null;
    let explainFailure: string | null = null;
    try {
      explanation = await withBackoff(
        () => leg({ readingText: readingText! }, AbortSignal.timeout(explainTimeout * 1000)),
        (s, attempt) => console.log(`    … rate limited, waiting ${s}s (attempt ${attempt})`),
      );
    } catch (thrown) {
      stopIfKeyRefused(
        thrown,
        explainerName === "gemma" ? "GEMINI_API_KEY" : `${explainerName.toUpperCase()}_API_KEY`,
      );
      explainFailure = failureLabel(thrown);
    }
    const explainLatencyMs = performance.now() - explainStart;

    const recorded: RecordedResponse | null = recorder.last();
    const answered = recorded?.status === 200 || explainFailure === "invalid_output";
    const parsed = parseExplanation(recorded?.content ?? null);
    const schemaValid = parsed !== null;

    const caps = parsed !== null ? checkCaps(parsed) : null;

    let groundedStatus: string | null = null;
    let grounding: GroundingReport | null = null;
    if (parsed !== null) {
      const result = groundExplanation(parsed, readingText);
      groundedStatus = result.explanation.status;
      grounding = result.report;
    }

    const totalLatencyMs = readLatencyMs !== null ? readLatencyMs + explainLatencyMs : null;

    const key = `${image.name}.${explainerName}`;
    const rating = typeof ratings[key] === "number" ? ratings[key] as number : null;

    await Deno.writeTextFile(
      `${outDir}/${key}.json`,
      `${
        JSON.stringify(
          {
            outcome: explainFailure ?? "accepted",
            finish_reason: recorded?.finishReason ?? null,
            schema_valid: schemaValid,
            caps,
            grounded_status: groundedStatus,
            grounding,
            explanation: parsed,
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
      readCer,
      readWer,
      readLatencyMs,
      readFailure: null,
      answered,
      schemaValid,
      explainFailure,
      explainLatencyMs,
      totalLatencyMs,
      caps,
      groundedStatus,
      grounding,
      promptTokens: recorded?.promptTokens ?? null,
      completionTokens: recorded?.completionTokens ?? null,
      finishReason: recorded?.finishReason ?? null,
      rating,
    };
    rows.push(row);

    const cerStr = readCer !== null ? ` CER ${(readCer * 100).toFixed(1)}%` : "";
    console.log(
      `  ${explainFailure === null ? "·" : "!"} ${image.name}  [${truth.category}]` +
        `${cerStr}  explain ${(explainLatencyMs / 1000).toFixed(1)}s` +
        (readLatencyMs !== null ? `  read ${(readLatencyMs / 1000).toFixed(1)}s` : "") +
        (explainFailure !== null ? `  failed: ${explainFailure}` : "") +
        (groundedStatus === "partial" ? "  (partial)" : ""),
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

  console.log(`\n${explainerName} over Gemini readings. Answers: ${outDir}/<image>.${explainerName}.json`);
  report(rows);
  budgetGate(rows);

  if (explainerName === "gemma") gemmaGate(rows);

  const savePath = flag(args, "save");
  if (savePath !== null) {
    const categories = [...new Set(rows.map((r) => r.category))].sort();
    const payload = {
      recordedAt: new Date().toISOString(),
      explainer: explainerName,
      reader: reader?.model ?? "(cached)",
      overall: summaryOf(rows),
      byCategory: Object.fromEntries(
        categories.map((c) => [c, summaryOf(rows.filter((r) => r.category === c))]),
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
