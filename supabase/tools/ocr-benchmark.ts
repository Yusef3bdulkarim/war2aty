/**
 * F17-T03 · OCR accuracy benchmark.
 *
 * Measures what the online pipeline actually reads off a folder of document
 * photographs, so every constant F17 changes can be justified by a number
 * instead of a judgement call (F17 locked decision #3).
 *
 * ── Why this is a Deno tool and not a Dart one ────────────────────────────
 * The things being measured — the T05 extractors and T06's `verifyCandidates`
 * — are TypeScript in `../functions/_shared/`. This imports them directly, so
 * the benchmark scores the code that ships. A Dart harness would have to
 * reimplement them and would then be scoring a copy.
 *
 * ── Why it calls Azure directly and not `analyze-document` ────────────────
 * `analyze-handler.ts` reserves a quota slot and `dailyAnalysisLimit` is 3 per
 * Cairo day; a 30-document run through it would take ten days. This uses the
 * same `createAzureDocumentIntelligenceClient`, model and API version the Edge
 * Function uses, and skips the handler (and therefore Groq, which has no
 * bearing on OCR fidelity).
 *
 * PRIVACY (§7, §51): document text never reaches stdout. Per-file output is
 * limited to metrics; `--bootstrap` writes transcriptions to disk, into a
 * git-ignored folder, and prints only the path it wrote.
 *
 * Usage:
 *   deno run --allow-read --allow-write --allow-env --allow-net \
 *     --env-file=supabase/.env supabase/tools/ocr-benchmark.ts --set golden/
 *
 *   --set <dir>        Folder of document images.        (default: golden/)
 *   --bootstrap        Write draft `<name>.truth.json` files to correct by
 *                      hand, instead of scoring. Never overwrites an existing
 *                      one.
 *   --baseline <file>  Compare this run against a saved run.
 *   --save <file>      Save this run's metrics for later comparison.
 *   --min-mp <n>       Skip images below this megapixel count. (default: 0.1)
 *   --timeout <s>      Per-document Azure budget.          (default: 60)
 *   --delay <ms>       Pause between documents, to stay under the Azure
 *                      resource's rate limit.              (default: 4000)
 */

import { createAzureDocumentIntelligenceClient } from "../functions/_shared/azure/azure-client.ts";
import { azureOptionsFromEnv } from "../functions/_shared/azure/azure-config.ts";
import type { AzureReadResult, AzureWord } from "../functions/_shared/azure/azure-client.ts";
import {
  verifyCandidates,
  VERIFIED_CONFIDENCE_THRESHOLD,
} from "../functions/_shared/verification/field-verification.ts";
import { ApiError } from "../functions/_shared/errors/api-error.ts";
import { createImageAnalysisPipeline } from "../functions/_shared/analyze/image-analysis-pipeline.ts";
import type { ImageAnalysisResult } from "../functions/_shared/analyze/image-analysis-pipeline.ts";

// ── Throttling ────────────────────────────────────────────────────────────
//
// The benchmark hammers Azure far harder than the app ever does — one call per
// document, back to back, where a user makes at most a few a day. A free-tier
// resource answers 429 within a handful of calls, so pace the run and back off
// when told to. This is a property of the harness, not of the pipeline: the
// numbers are unaffected, only the wall-clock time to collect them.

const RATE_LIMIT_ATTEMPTS = 6;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function analyseWithBackoff(
  azure: (image: Uint8Array, contentType: string) => Promise<AzureReadResult>,
  bytes: Uint8Array,
  mimeType: string,
  onWait: (seconds: number, attempt: number) => void,
): Promise<AzureReadResult> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await azure(bytes, mimeType);
    } catch (thrown) {
      const rateLimited = thrown instanceof ApiError && thrown.code === "AI_RATE_LIMITED";
      if (!rateLimited || attempt >= RATE_LIMIT_ATTEMPTS) throw thrown;

      // 4s, 8s, 16s, 32s, 64s — comfortably past a per-minute window.
      const waitSeconds = 2 ** (attempt + 1);
      onWait(waitSeconds, attempt);
      await sleep(waitSeconds * 1000);
    }
  }
}

// ── Ground truth ──────────────────────────────────────────────────────────
//
// One sidecar per image, `<basename>.truth.json`. `text` drives CER/WER;
// `dates`/`amounts` drive the verdict metric — whether the pipeline recovered
// the two field types the app exists to get right (CRITICAL_FIELD_TYPES in
// cross-provider-validator.ts).

interface GroundTruth {
  category: string;
  /** Writer id for handwritten pages, so one hand's quirks are visible as such. */
  writer?: string | null;
  text: string;
  dates: string[];
  amounts: string[];
  phones: string[];
  references: string[];
  /**
   * Fields whose value could not be established by reading the image, and that
   * only the document's owner can settle — a passport number, a name's exact
   * spelling, a digit written ambiguously.
   *
   * Ground truth drafted by reading the page (whether by Azure or by any other
   * reader) is a *second opinion*, not a fact: where a page is genuinely hard
   * to read, an automated transcription can repeat the very error it is meant
   * to catch. Listing the unsettled fields here keeps that visible instead of
   * letting a confident-looking file hide it. Purely documentation — the
   * scorer ignores it — but a non-empty list means this file is not yet truth.
   */
  needsOwnerCheck?: string[];
}

interface DocumentScore {
  readonly file: string;
  readonly category: string;
  readonly megapixels: number;
  readonly cer: number | null;
  readonly wer: number | null;
  readonly meanConfidence: number;
  /** `null` when the page yielded no candidates at all — nothing was up for verification. */
  readonly verifiedRate: number | null;
  /** Share of expected dates+amounts the pipeline recovered. `null` when none expected. */
  readonly criticalRecall: number | null;
}

interface SkippedDocument {
  readonly file: string;
  readonly reason: string;
}

// ── Text normalisation ────────────────────────────────────────────────────
//
// Comparing Arabic byte-for-byte would score cosmetic differences as errors:
// Azure may return a bare alef where the page has a hamza-carrying one, and
// diacritics are optional in print. Normalising both sides keeps CER a measure
// of misreading rather than of orthographic variation.

const ARABIC_DIACRITICS = /[ؐ-ًؚ-ٰٟۖ-ۭ]/g;
const TATWEEL = /ـ/g;

function normalise(text: string): string {
  return text
    .replace(ARABIC_DIACRITICS, "")
    .replace(TATWEEL, "")
    .replace(/[آأإٱ]/g, "ا") // alef forms → bare alef
    .replace(/ى/g, "ي") // alef maqsura → ya
    .replace(/ة/g, "ه") // ta marbuta → ha
    .replace(/[٠-٩]/g, (d) => // Arabic-Indic digits → ASCII
      String.fromCharCode(d.charCodeAt(0) - 0x0660 + 0x30))
    .replace(/[۰-۹]/g, (d) =>
      String.fromCharCode(d.charCodeAt(0) - 0x06F0 + 0x30))
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

/** Levenshtein distance, two rows rather than a full matrix. */
function editDistance(a: readonly string[], b: readonly string[]): number {
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;

  let previous = Array.from({ length: b.length + 1 }, (_, i) => i);
  let current = new Array<number>(b.length + 1);

  for (let i = 1; i <= a.length; i++) {
    current[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const substitution = previous[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1);
      current[j] = Math.min(substitution, previous[j] + 1, current[j - 1] + 1);
    }
    [previous, current] = [current, previous];
  }

  return previous[b.length];
}

function errorRate(expected: readonly string[], actual: readonly string[]): number | null {
  if (expected.length === 0) return null;
  return editDistance(expected, actual) / expected.length;
}

// ── Pipeline ──────────────────────────────────────────────────────────────

/**
 * Runs the real online pipeline over an already-fetched Azure reading.
 *
 * The benchmark used to call the extractors and `verifyCandidates` itself,
 * which quietly made it a *reimplementation* of `image-analysis-pipeline.ts`
 * rather than a measurement of it — and it promptly missed a fix applied
 * inside that module, reporting no change where the pipeline had changed
 * completely. Driving the real thing with a stub client is the only way the
 * numbers describe what ships.
 *
 * Google is never wired in: a second opinion is a network call per document
 * and changes `needsUserReview`, not the OCR fidelity this tool measures.
 */
function analyse(azure: AzureReadResult, mimeType: string): Promise<ImageAnalysisResult> {
  const pipeline = createImageAnalysisPipeline({
    azureClient: () => Promise.resolve(azure),
    googleClient: null,
  });
  return pipeline({ data: new Uint8Array(), mimeType });
}

const MIME_BY_EXTENSION: Readonly<Record<string, string>> = {
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".bmp": "image/bmp",
  ".tif": "image/tiff",
  ".tiff": "image/tiff",
  ".heic": "image/heic",
  ".pdf": "application/pdf",
};

/**
 * Pixel dimensions straight from the file header — enough for JPEG and PNG,
 * which is everything the set holds. Returns `null` when the header cannot be
 * read, which the caller treats as "unknown size", never as an error.
 */
function readDimensions(bytes: Uint8Array): { width: number; height: number } | null {
  // PNG: IHDR width/height are fixed at bytes 16..24.
  if (bytes.length > 24 && bytes[0] === 0x89 && bytes[1] === 0x50) {
    const view = new DataView(bytes.buffer, bytes.byteOffset);
    return { width: view.getUint32(16), height: view.getUint32(20) };
  }

  // JPEG: walk the segment chain to the first SOF marker.
  if (bytes.length > 4 && bytes[0] === 0xFF && bytes[1] === 0xD8) {
    let offset = 2;
    while (offset + 9 < bytes.length) {
      if (bytes[offset] !== 0xFF) {
        offset++;
        continue;
      }
      const marker = bytes[offset + 1];
      // SOF0..SOF15, excluding the non-frame markers DHT/JPG/DAC.
      if (marker >= 0xC0 && marker <= 0xCF && marker !== 0xC4 && marker !== 0xC8 && marker !== 0xCC) {
        const view = new DataView(bytes.buffer, bytes.byteOffset);
        return { height: view.getUint16(offset + 5), width: view.getUint16(offset + 7) };
      }
      offset += 2 + new DataView(bytes.buffer, bytes.byteOffset).getUint16(offset + 2);
    }
  }

  return null;
}

function scoreDocument(
  file: string,
  megapixels: number,
  truth: GroundTruth,
  azure: AzureReadResult,
  analysis: ImageAnalysisResult,
): DocumentScore {
  const { verification } = analysis;

  const expectedText = normalise(truth.text);
  const actualText = normalise(analysis.ocrText);

  const cer = errorRate([...expectedText], [...actualText]);
  const wer = errorRate(
    expectedText.split(" ").filter(Boolean),
    actualText.split(" ").filter(Boolean),
  );

  const meanConfidence = azure.words.length === 0
    ? 0
    : azure.words.reduce((sum, w) => sum + w.confidence, 0) / azure.words.length;

  const verdicts = [
    ...verification.dates,
    ...verification.times,
    ...verification.amounts,
    ...verification.phones,
    ...verification.references,
  ];
  // No candidates means nothing was up for verification — that is "not
  // applicable", not "nothing passed". Scoring it as 0 buried the real signal:
  // three pages produced no candidates whatever, and their zeros were being
  // averaged in as if verification had been tried and failed.
  const verifiedRate = verdicts.length === 0
    ? null
    : verdicts.filter((v) => v.status === "verified").length / verdicts.length;

  return {
    file,
    category: truth.category,
    megapixels,
    cer,
    wer,
    meanConfidence,
    verifiedRate,
    criticalRecall: criticalRecall(truth, analysis.ocrText),
  };
}

/**
 * Share of the dates and amounts the page really carries that survive into
 * Azure's text. Matched on the normalised string rather than on the extractor's
 * parse, so a field the extractor mis-parses still counts as read — this metric
 * scores the OCR, and T05's parsing is measured by `verifiedRate` beside it.
 *
 * Whitespace is stripped from both sides before matching. A date or an amount
 * is one compact token whose internal spacing carries no meaning: Azure
 * returning `10, 99€` for `10,99€` has read the price correctly, and scoring
 * that as a miss would blame the recogniser for the harness's own literalism.
 * Digits, separators and their order still have to agree exactly — a
 * transposed `٥/٨` for `٨/٥` remains a miss, which is the error this metric
 * exists to catch.
 */
function compact(text: string): string {
  return normalise(text).replace(/\s+/g, "");
}

function criticalRecall(truth: GroundTruth, content: string): number | null {
  const expected = [...truth.dates, ...truth.amounts];
  if (expected.length === 0) return null;

  const haystack = compact(content);
  const found = expected.filter((value) => haystack.includes(compact(value)));
  return found.length / expected.length;
}

// ── Explaining a verdict ──────────────────────────────────────────────────
//
// `verifiedRate` says how many fields cleared verification; it never says why
// the rest did not, and the three reasons call for completely different fixes.
// `is_ambiguous` is the extractor's own doubt (T05's problem). A null
// confidence means the candidate's text could not be matched to any Azure word
// at all — a span/indexing failure, not a reading failure. Only the third,
// confidence below the bar, is the threshold problem Phase 2 is about.
//
// Prints counts and confidences only — never a candidate's value (§7, §51).

function explain(analysis: ImageAnalysisResult, words: readonly AzureWord[]): void {
  const { candidates } = analysis;

  // T08 keeps only `status` and `needsUserReview`; the per-field confidence
  // T06 computed is dropped before the pipeline returns. Re-deriving T06 here
  // is the only way to see it — and it is faithful rather than a second
  // implementation, because it runs over exactly what the pipeline produced:
  // `analysis.ocrText` is the folded content T06 itself saw, and folding
  // preserves offsets, so `words` still line up.
  const verification = verifyCandidates({
    content: analysis.ocrText,
    words,
    candidates,
  });

  const groups: [string, readonly CommonCandidateLike[], readonly FieldVerdictLike[]][] = [
    ["dates", candidates.dates, verification.dates],
    ["times", candidates.times, verification.times],
    ["amounts", candidates.amounts, verification.amounts],
    ["phones", candidates.phones, verification.phones],
    ["references", candidates.references, verification.references],
  ];

  for (const [label, group, verdicts] of groups) {
    if (group.length === 0) continue;
    const reasons = group.map((candidate, i) => {
      const verdict = verdicts[i];
      if (verdict.status === "verified") return "verified";
      if (verdict.status === "conflicting") return "conflicting";
      if (candidate.is_ambiguous) return "extractor flagged ambiguous";
      if (verdict.confidence === null) return "span not matched to any word";
      return `confidence ${verdict.confidence.toFixed(2)} < ${VERIFIED_CONFIDENCE_THRESHOLD}`;
    });

    const tally = new Map<string, number>();
    for (const reason of reasons) {
      const key = reason.startsWith("confidence ") ? "below threshold" : reason;
      tally.set(key, (tally.get(key) ?? 0) + 1);
    }

    const summary = [...tally].map(([k, v]) => `${k}×${v}`).join(", ");
    console.log(`      ${label.padEnd(11)} n=${String(group.length).padEnd(3)} ${summary}`);

    reasons.forEach((reason, i) => {
      if (reason === "verified") return;
      const conf = verdicts[i].confidence;
      const shown = conf === null ? " —  " : conf.toFixed(2);
      console.log(`        [${i}] conf=${shown}  ${reason}`);
    });
  }
}

interface CommonCandidateLike {
  readonly is_ambiguous: boolean;
}

interface FieldVerdictLike {
  readonly status: string;
  readonly confidence: number | null;
}

// ── Reporting ─────────────────────────────────────────────────────────────

function mean(values: readonly (number | null)[]): number | null {
  const present = values.filter((v): v is number => v !== null);
  if (present.length === 0) return null;
  return present.reduce((a, b) => a + b, 0) / present.length;
}

function percent(value: number | null): string {
  return value === null ? "  —  " : `${(value * 100).toFixed(1)}%`.padStart(6);
}

function report(scores: readonly DocumentScore[], baseline: Record<string, unknown> | null): void {
  const categories = [...new Set(scores.map((s) => s.category))].sort();

  console.log("");
  console.log("category                  n   avg MP     CER     WER  mean conf  verified  date+amount");
  console.log("─".repeat(92));

  const row = (label: string, group: readonly DocumentScore[]) => {
    console.log(
      label.padEnd(24) +
        String(group.length).padStart(3) +
        (mean(group.map((s) => s.megapixels))?.toFixed(2) ?? "—").padStart(9) +
        "  " + percent(mean(group.map((s) => s.cer))) +
        "  " + percent(mean(group.map((s) => s.wer))) +
        "     " + percent(mean(group.map((s) => s.meanConfidence))) +
        "    " + percent(mean(group.map((s) => s.verifiedRate))) +
        "       " + percent(mean(group.map((s) => s.criticalRecall))),
    );
  };

  for (const category of categories) {
    row(category, scores.filter((s) => s.category === category));
  }
  console.log("─".repeat(92));
  row("ALL", scores);

  if (baseline !== null) {
    const previous = baseline.overall as { cer: number | null } | undefined;
    const now = mean(scores.map((s) => s.cer));
    if (previous?.cer != null && now != null) {
      const delta = (previous.cer - now) * 100;
      const direction = delta > 0 ? "better" : "worse";
      console.log("");
      console.log(`vs baseline: CER ${Math.abs(delta).toFixed(1)} points ${direction}`);
    }
  }
}

// ── Entry point ───────────────────────────────────────────────────────────

function flag(name: string, fallback: string | null = null): string | null {
  const index = Deno.args.indexOf(`--${name}`);
  if (index === -1 || index + 1 >= Deno.args.length) return fallback;
  return Deno.args[index + 1];
}

async function main(): Promise<void> {
  const setDir = flag("set", "golden") as string;
  const bootstrap = Deno.args.includes("--bootstrap");
  const minMegapixels = Number(flag("min-mp", "0.1"));
  const timeoutSeconds = Number(flag("timeout", "60"));
  const delayMs = Number(flag("delay", "4000"));
  const explainVerdicts = Deno.args.includes("--explain");

  const azure = createAzureDocumentIntelligenceClient({
    ...azureOptionsFromEnv(),
    timeoutSeconds,
  });

  const files: string[] = [];
  for await (const entry of Deno.readDir(setDir)) {
    if (!entry.isFile) continue;
    if (entry.name.endsWith(".truth.json")) continue;
    files.push(entry.name);
  }
  files.sort();

  const scores: DocumentScore[] = [];
  const skipped: SkippedDocument[] = [];

  for (const name of files) {
    const path = `${setDir}/${name}`;
    const extension = name.slice(name.lastIndexOf(".")).toLowerCase();
    const mimeType = MIME_BY_EXTENSION[extension];

    if (mimeType === undefined) {
      skipped.push({ file: name, reason: `unsupported format (${extension})` });
      continue;
    }

    const bytes = await Deno.readFile(path);
    const dimensions = readDimensions(bytes);
    const megapixels = dimensions === null
      ? 0
      : (dimensions.width * dimensions.height) / 1_000_000;

    if (dimensions !== null && megapixels < minMegapixels) {
      skipped.push({
        file: name,
        reason: `${megapixels.toFixed(2)} MP — below --min-mp ${minMegapixels}`,
      });
      continue;
    }

    const truthPath = `${path}.truth.json`;
    let truth: GroundTruth | null = null;
    try {
      truth = JSON.parse(await Deno.readTextFile(truthPath)) as GroundTruth;
    } catch {
      truth = null;
    }

    if (!bootstrap && truth === null) {
      skipped.push({ file: name, reason: "no ground truth — run --bootstrap first" });
      continue;
    }

    // An uncorrected draft still holds Azure's own output as its `text`.
    // Scoring it would compare Azure against itself and report a flawless CER
    // — the most dangerous possible result, because it looks like success.
    // `category` is the sentinel: `--bootstrap` writes UNCATEGORISED, and only
    // a human editing the file ever changes it.
    if (!bootstrap && truth!.category === "UNCATEGORISED") {
      skipped.push({
        file: name,
        reason: "draft never corrected — category is still UNCATEGORISED",
      });
      continue;
    }

    if (!bootstrap && truth!.category === "EXCLUDE") {
      skipped.push({ file: name, reason: "excluded by its ground-truth file" });
      continue;
    }

    // Decided before the call, not after: a re-run over a set that is already
    // half-transcribed must not spend an Azure request — and, on a rate-limited
    // resource, a place in the queue — to produce a draft it will discard.
    if (bootstrap && truth !== null) {
      console.log(`  = ${name} — ground truth already exists, left untouched`);
      continue;
    }

    let result: AzureReadResult;
    try {
      result = await analyseWithBackoff(
        azure,
        bytes,
        mimeType,
        (seconds, attempt) =>
          console.log(`    … rate limited, waiting ${seconds}s (attempt ${attempt})`),
      );
    } catch (thrown) {
      const code = thrown instanceof Error ? thrown.message : "unknown";
      skipped.push({ file: name, reason: `Azure call failed (${code})` });
      continue;
    }
    await sleep(delayMs);

    if (bootstrap) {
      const draft: GroundTruth = {
        category: "UNCATEGORISED",
        writer: null,
        text: result.content,
        dates: [],
        amounts: [],
        phones: [],
        references: [],
      };
      await Deno.writeTextFile(truthPath, `${JSON.stringify(draft, null, 2)}\n`);
      console.log(`  + ${truthPath}  (${megapixels.toFixed(2)} MP, ${result.words.length} words)`);
      continue;
    }

    const analysis = await analyse(result, mimeType);
    scores.push(scoreDocument(name, megapixels, truth!, result, analysis));
    console.log(`  · ${name}  (${megapixels.toFixed(2)} MP)  [${truth!.category}]`);
    if (explainVerdicts) explain(analysis, result.words);
  }

  if (skipped.length > 0) {
    console.log("");
    console.log(`Skipped ${skipped.length}:`);
    for (const { file, reason } of skipped) console.log(`  ! ${file} — ${reason}`);
  }

  if (bootstrap) {
    console.log("");
    console.log("Draft transcriptions written. Correct every one by hand before scoring:");
    console.log("  · fix `text` against the page — an uncorrected draft scores Azure against itself");
    console.log("  · set `category` and, for handwriting, `writer`");
    console.log("  · list the real `dates` and `amounts` exactly as they appear");
    return;
  }

  if (scores.length === 0) {
    console.log("");
    console.log("Nothing scored.");
    return;
  }

  const baselinePath = flag("baseline");
  let baseline: Record<string, unknown> | null = null;
  if (baselinePath !== null) {
    try {
      baseline = JSON.parse(await Deno.readTextFile(baselinePath));
    } catch {
      console.log(`(no readable baseline at ${baselinePath})`);
    }
  }

  report(scores, baseline);

  const savePath = flag("save");
  if (savePath !== null) {
    const payload = {
      recordedAt: new Date().toISOString(),
      documents: scores.length,
      overall: {
        cer: mean(scores.map((s) => s.cer)),
        wer: mean(scores.map((s) => s.wer)),
        meanConfidence: mean(scores.map((s) => s.meanConfidence)),
        verifiedRate: mean(scores.map((s) => s.verifiedRate)),
        criticalRecall: mean(scores.map((s) => s.criticalRecall)),
      },
      byCategory: Object.fromEntries(
        [...new Set(scores.map((s) => s.category))].map((category) => {
          const group = scores.filter((s) => s.category === category);
          return [category, {
            documents: group.length,
            cer: mean(group.map((s) => s.cer)),
            wer: mean(group.map((s) => s.wer)),
            meanConfidence: mean(group.map((s) => s.meanConfidence)),
            verifiedRate: mean(group.map((s) => s.verifiedRate)),
            criticalRecall: mean(group.map((s) => s.criticalRecall)),
          }];
        }),
      ),
    };
    await Deno.writeTextFile(savePath, `${JSON.stringify(payload, null, 2)}\n`);
    console.log("");
    console.log(`Saved to ${savePath}`);
  }
}

if (import.meta.main) {
  await main();
}
