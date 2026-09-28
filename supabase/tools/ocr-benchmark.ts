/**
 * F20-T08 · OCR benchmark — what each reader gets off the corpus photos.
 *
 * Ported from F17's `ocr-benchmark.ts` (not merged, decision D7) and made
 * provider-agnostic: `--ocr gemini` runs the production Gemini OCR client
 * (T07), `--ocr tesseract` runs the Tesseract command-line tool. Azure is
 * never called. Its numbers come from the run F17 recorded (`--baseline`).
 *
 * ── Tesseract is an approximation ─────────────────────────────────────────
 * The app runs Tesseract 4 through `flutter_tesseract_ocr` with `ara+eng`,
 * the default page segmentation, and the trained data in `assets/tessdata`.
 * This runs whatever `tesseract` is installed (often 5.x) with the same
 * languages and the SAME `assets/tessdata` files. It skips the phone's
 * capture pipeline (crop, perspective, compression). Treat its numbers as
 * the floor Gemini must beat (gate G6), not as the app's exact accuracy.
 *
 * ── Metrics (T09) ─────────────────────────────────────────────────────────
 * Per document, per category and overall: CER and WER; CER on Arabic and on
 * Latin letters separately; digit accuracy; recall of the printed dates and
 * amounts, and precision of the extractors' candidates; how many truth
 * values the READER lost versus how many the EXTRACTORS lost; the error rate;
 * and p50/p95 latency. Then the G1–G3 gates.
 *
 * PRIVACY (§7, §51): document text never reaches stdout. Transcriptions are
 * written to `--text-out` (git-ignored, `golden*`), where the analysis
 * benchmark reads them, and `--bootstrap` writes drafts next to the images.
 * Only paths and metrics are printed. `--ocr gemini` sends every photo to
 * Gemini's free tier, which may keep and review it (accepted, D8).
 *
 * Usage (from the repo root):
 *   deno run --allow-read --allow-write --allow-env --allow-net --allow-run \
 *     --env-file=supabase/.env supabase/tools/ocr-benchmark.ts --ocr gemini
 *
 *   --ocr <engine>       gemini | tesseract                       (required)
 *   --set <dir>          Folder of images and truth files.        (default: golden)
 *   --text-out <dir>     Where transcriptions are written.        (default: golden-ocr)
 *   --bootstrap          Write draft `<image>.truth.json` files for the owner
 *                        to correct, instead of scoring. Tesseract only: a
 *                        Gemini draft would bias the truth towards Gemini
 *                        (T02). Never overwrites an existing file.
 *   --baseline <file>    F17's recorded Azure run, e.g. baseline.json.
 *   --save <file>        Save this run's metrics (no text) as JSON.
 *   --min-mp <n>         Skip images below this many megapixels.  (default: 0.1)
 *   --timeout <s>        Per-document budget.                     (default: 25)
 *   --delay <ms>         Pause after each call. Gemini's free tier allows a
 *                        few requests a minute.       (default: 6000 gemini, 0 tesseract)
 *   --tesseract <bin>    The Tesseract executable.                (default: tesseract)
 *   --tessdata <dir>     Trained data.                            (default: assets/tessdata)
 */

import { createGeminiOcrClient } from "../functions/_shared/ai/gemini-ocr-client.ts";
import { geminiOptionsFromEnv } from "../functions/_shared/ai/gemini-config.ts";
import {
  candidatesFor,
  type CorpusImage,
  failureLabel,
  flag,
  listImages,
  loadTruth,
  numberFlag,
  readDimensions,
  sleep,
  stopIfKeyRefused,
  transcriptionPath,
  truthPath,
  withBackoff,
} from "./benchmark/corpus.ts";
import { draftTruth, type GroundTruth } from "./benchmark/truth.ts";
import {
  cer,
  criticalFields,
  digitAccuracy,
  mean,
  percent,
  percentile,
  scriptCer,
  wer,
} from "./benchmark/metrics.ts";
import { type OcrDocumentScore, ocrGates, printGates } from "./benchmark/gates.ts";

/** Reads one image. Throws on failure; the caller records the failure's label. */
type Reader = (image: CorpusImage, bytes: Uint8Array) => Promise<string>;

/** A broken setup, not a per-document failure: it stops the whole run. */
class SetupError extends Error {}

interface DocumentRow extends OcrDocumentScore {
  readonly file: string;
  readonly megapixels: number;
  readonly failure: string | null;
  readonly wer: number | null;
  readonly cerArabic: number | null;
  readonly cerLatin: number | null;
  readonly digits: number | null;
  readonly criticalRecall: number | null;
  readonly candidatePrecision: number | null;
  readonly ocrLoss: number;
  readonly extractorLoss: number;
  readonly openOwnerChecks: number;
}

// ── readers ───────────────────────────────────────────────────────────────

function geminiReader(timeoutSeconds: number): Reader {
  const client = createGeminiOcrClient(geminiOptionsFromEnv());
  return async (image, bytes) => {
    const result = await withBackoff(
      () =>
        client(
          { bytes, mimeType: image.mimeType! },
          AbortSignal.timeout(timeoutSeconds * 1000),
        ),
      (seconds, attempt) =>
        console.log(
          `    … rate limited, waiting ${seconds}s (attempt ${attempt})`,
        ),
    );
    return result.text;
  };
}

function tesseractReader(
  bin: string,
  tessdata: string,
  timeoutSeconds: number,
): Reader {
  return async (_image, bytes) => {
    let child: Deno.ChildProcess;
    try {
      child = new Deno.Command(bin, {
        // The image goes in on stdin, not as a path: on Windows, Tesseract
        // cannot open a path with non-ASCII characters, such as an Arabic
        // file name.
        args: ["stdin", "stdout", "-l", "ara+eng", "--tessdata-dir", tessdata],
        stdin: "piped",
        stdout: "piped",
        // Tesseract's stderr is progress chatter; it is dropped, not printed.
        stderr: "null",
        signal: AbortSignal.timeout(timeoutSeconds * 1000),
      }).spawn();
    } catch (thrown) {
      if (thrown instanceof Deno.errors.NotFound) {
        throw new SetupError(
          `"${bin}" not found. Install Tesseract (on Windows, the UB Mannheim build) ` +
            "or pass --tesseract <path-to-executable>.",
        );
      }
      throw thrown;
    }
    const pending = child.output();
    const writer = child.stdin.getWriter();
    await writer.write(bytes);
    await writer.close();
    const output = await pending;
    if (!output.success) {
      throw new Error(`tesseract exited with code ${output.code}`);
    }
    return new TextDecoder().decode(output.stdout);
  };
}

async function fileExists(path: string): Promise<boolean> {
  try {
    await Deno.stat(path);
    return true;
  } catch {
    return false;
  }
}

// ── scoring ───────────────────────────────────────────────────────────────

function score(
  file: string,
  megapixels: number,
  truth: GroundTruth,
  reading: { text: string; latencyMs: number } | { failure: string },
): DocumentRow {
  if ("failure" in reading) {
    return {
      file,
      megapixels,
      category: truth.category,
      ok: false,
      failure: reading.failure,
      cer: null,
      wer: null,
      cerArabic: null,
      cerLatin: null,
      digits: null,
      criticalRecall: null,
      candidatePrecision: null,
      criticalFound: 0,
      criticalExpected: truth.dates.length + truth.amounts.length,
      ocrLoss: 0,
      extractorLoss: 0,
      latencyMs: null,
      openOwnerChecks: truth.needsOwnerCheck.length,
    };
  }

  const { text, latencyMs } = reading;
  const candidates = candidatesFor(text);
  const critical = criticalFields({
    truthValues: [...truth.dates, ...truth.amounts],
    ocrText: text,
    candidateRawTexts: [...candidates.dates, ...candidates.amounts].map((c) => c.raw_text),
  });

  return {
    file,
    megapixels,
    category: truth.category,
    ok: true,
    failure: null,
    cer: cer(truth.text, text),
    wer: wer(truth.text, text),
    cerArabic: scriptCer(truth.text, text, "arabic"),
    cerLatin: scriptCer(truth.text, text, "latin"),
    digits: digitAccuracy(truth.text, text),
    criticalRecall: critical.recall,
    candidatePrecision: critical.precision,
    criticalFound: critical.expected - critical.ocrLoss,
    criticalExpected: critical.expected,
    ocrLoss: critical.ocrLoss,
    extractorLoss: critical.extractorLoss,
    latencyMs,
    openOwnerChecks: truth.needsOwnerCheck.length,
  };
}

// ── reporting ─────────────────────────────────────────────────────────────

function summary(rows: readonly DocumentRow[]) {
  const latencies = rows.flatMap((
    r,
  ) => (r.latencyMs === null ? [] : [r.latencyMs]));
  return {
    documents: rows.length,
    errorRate: rows.length === 0 ? null : rows.filter((r) => !r.ok).length / rows.length,
    cer: mean(rows.map((r) => r.cer)),
    wer: mean(rows.map((r) => r.wer)),
    cerArabic: mean(rows.map((r) => r.cerArabic)),
    cerLatin: mean(rows.map((r) => r.cerLatin)),
    digitAccuracy: mean(rows.map((r) => r.digits)),
    criticalRecall: mean(rows.map((r) => r.criticalRecall)),
    candidatePrecision: mean(rows.map((r) => r.candidatePrecision)),
    ocrLoss: rows.reduce((n, r) => n + r.ocrLoss, 0),
    extractorLoss: rows.reduce((n, r) => n + r.extractorLoss, 0),
    p50Ms: percentile(latencies, 50),
    p95Ms: percentile(latencies, 95),
  };
}

function seconds(ms: number | null): string {
  return ms === null ? "  —  " : `${(ms / 1000).toFixed(1)}s`.padStart(6);
}

function report(rows: readonly DocumentRow[]): void {
  const categories = [...new Set(rows.map((r) => r.category))].sort();

  console.log("");
  console.log(
    "category            n  err    CER    WER  CER-ar CER-lat digits  recall  prec  " +
      "ocr-loss ext-loss   p50    p95",
  );
  console.log("─".repeat(118));

  const line = (label: string, group: readonly DocumentRow[]) => {
    const s = summary(group);
    console.log(
      label.padEnd(18) +
        String(s.documents).padStart(3) +
        " " + percent(s.errorRate) +
        " " + percent(s.cer) +
        " " + percent(s.wer) +
        " " + percent(s.cerArabic) +
        "  " + percent(s.cerLatin) +
        " " + percent(s.digitAccuracy) +
        "  " + percent(s.criticalRecall) +
        " " + percent(s.candidatePrecision) +
        String(s.ocrLoss).padStart(9) +
        String(s.extractorLoss).padStart(9) +
        " " + seconds(s.p50Ms) +
        " " + seconds(s.p95Ms),
    );
  };

  for (const category of categories) {
    line(
      category,
      rows.filter((r) => r.category === category),
    );
  }
  console.log("─".repeat(118));
  line("ALL", rows);

  const failures = new Map<string, number>();
  for (const row of rows) {
    if (row.failure !== null) {
      failures.set(row.failure, (failures.get(row.failure) ?? 0) + 1);
    }
  }
  if (failures.size > 0) {
    console.log(
      `\nfailures: ${[...failures].map(([k, v]) => `${k}×${v}`).join(", ")}`,
    );
  }
}

async function readBaseline(
  path: string | null,
): Promise<{ cer: number | null } | null> {
  if (path === null) return null;
  try {
    const saved = JSON.parse(await Deno.readTextFile(path));
    const cerValue = saved?.overall?.cer;
    console.log(
      `\nAzure baseline (recorded ${saved?.recordedAt ?? "?"}, ${saved?.documents ?? "?"} docs, ` +
        `never re-run): CER ${percent(typeof cerValue === "number" ? cerValue : null)}`,
    );
    return { cer: typeof cerValue === "number" ? cerValue : null };
  } catch {
    console.log(`\n(no readable baseline at ${path})`);
    return null;
  }
}

// ── entry point ───────────────────────────────────────────────────────────

async function main(args: readonly string[]): Promise<void> {
  const engine = flag(args, "ocr");
  if (engine !== "gemini" && engine !== "tesseract") {
    throw new Error("--ocr must be gemini or tesseract.");
  }
  const bootstrap = args.includes("--bootstrap");
  if (bootstrap && engine !== "tesseract") {
    throw new Error(
      "--bootstrap drafts truth from Tesseract only, never Gemini (T02).",
    );
  }

  const setDir = flag(args, "set", "golden");
  const textDir = flag(args, "text-out", "golden-ocr");
  const minMegapixels = numberFlag(args, "min-mp", 0.1);
  const timeoutSeconds = numberFlag(args, "timeout", 25);
  const delayMs = numberFlag(args, "delay", engine === "gemini" ? 6000 : 0);

  const read: Reader = engine === "gemini" ? geminiReader(timeoutSeconds) : tesseractReader(
    flag(args, "tesseract", "tesseract"),
    flag(args, "tessdata", "assets/tessdata"),
    timeoutSeconds,
  );

  await Deno.mkdir(textDir, { recursive: true });

  const rows: DocumentRow[] = [];
  const skipped: { file: string; reason: string }[] = [];

  for (const image of await listImages(setDir)) {
    if (image.mimeType === null) {
      skipped.push({ file: image.name, reason: "unsupported format" });
      continue;
    }

    const bytes = await Deno.readFile(image.path);
    const dimensions = readDimensions(bytes);
    const megapixels = dimensions === null ? 0 : (dimensions.width * dimensions.height) / 1e6;
    if (dimensions !== null && megapixels < minMegapixels) {
      skipped.push({
        file: image.name,
        reason: `${megapixels.toFixed(2)} MP, below --min-mp`,
      });
      continue;
    }

    if (bootstrap) {
      // Decided before the call: a re-run over a half-drafted set must not
      // redo work it would discard.
      if (await fileExists(truthPath(image))) {
        console.log(
          `  = ${image.name} — ground truth already exists, left untouched`,
        );
        continue;
      }
      let text: string;
      try {
        text = await read(image, bytes);
      } catch (thrown) {
        // One unreadable image must not end the run for the rest.
        if (thrown instanceof SetupError) throw thrown;
        skipped.push({ file: image.name, reason: `draft failed (${failureLabel(thrown)})` });
        continue;
      }
      await Deno.writeTextFile(
        truthPath(image),
        `${JSON.stringify(draftTruth(text), null, 2)}\n`,
      );
      console.log(`  + ${truthPath(image)}`);
      continue;
    }

    const status = await loadTruth(image);
    if (status.kind === "skip") {
      skipped.push({ file: image.name, reason: status.reason });
      continue;
    }

    const startedAt = performance.now();
    let row: DocumentRow;
    try {
      const text = await read(image, bytes);
      const latencyMs = performance.now() - startedAt;
      await Deno.writeTextFile(
        transcriptionPath(textDir, image.name, engine),
        text,
      );
      row = score(image.name, megapixels, status.truth, { text, latencyMs });
    } catch (thrown) {
      if (thrown instanceof SetupError) throw thrown;
      stopIfKeyRefused(thrown, "GEMINI_API_KEY");
      row = score(image.name, megapixels, status.truth, {
        failure: failureLabel(thrown),
      });
    }
    rows.push(row);

    const note = row.openOwnerChecks > 0 ? `  (${row.openOwnerChecks} owner checks open)` : "";
    console.log(
      `  ${row.ok ? "·" : "!"} ${image.name}  [${row.category}]  ${megapixels.toFixed(2)} MP` +
        (row.ok ? "" : `  failed: ${row.failure}`) + note,
    );
    if (delayMs > 0) await sleep(delayMs);
  }

  if (skipped.length > 0) {
    console.log(`\nSkipped ${skipped.length}:`);
    for (const { file, reason } of skipped) {
      console.log(`  ! ${file} — ${reason}`);
    }
  }

  if (bootstrap) {
    console.log(
      "\nDrafts written. Correct every one by hand before scoring (T02):",
    );
    console.log(
      "  · fix `text` against the page: an uncorrected draft scores Tesseract against itself",
    );
    console.log(
      "  · set `category` (C1–C10), `languages`, `expected_document_type`",
    );
    console.log(
      "  · list the printed `dates`/`amounts`, and the `key_*` values for the analysis benchmark",
    );
    return;
  }
  if (rows.length === 0) {
    console.log("\nNothing scored.");
    return;
  }

  console.log(`\nTranscriptions: ${textDir}/<image>.${engine}.txt`);
  report(rows);
  const baseline = await readBaseline(flag(args, "baseline"));
  printGates(ocrGates(rows, baseline?.cer ?? null));
  if (engine === "tesseract") {
    console.log("\nG6: Tesseract recorded as the floor.");
  }

  const savePath = flag(args, "save");
  if (savePath !== null) {
    const categories = [...new Set(rows.map((r) => r.category))].sort();
    const payload = {
      recordedAt: new Date().toISOString(),
      engine,
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
