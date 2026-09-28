/**
 * F20-T08 · Corpus I/O and pacing, shared by both benchmarks.
 *
 * PRIVACY (§7, §51): everything read here is a real person's paperwork. The
 * benchmarks print metrics only. Transcriptions and analyses are written to
 * git-ignored folders (`golden*` in `.gitignore`), and only their paths are
 * printed.
 */

import { ProviderFailure } from "../../functions/_shared/ai/provider-failure.ts";
import type { ExtractedCandidates } from "../../functions/_shared/prompts/analysis-prompt.ts";
import { normaliseDigits } from "../../functions/_shared/validators/text-matching.ts";
import { extractAmounts } from "../../functions/_shared/extractors/amount-extractor.ts";
import { extractDates } from "../../functions/_shared/extractors/date-extractor.ts";
import { extractPhones } from "../../functions/_shared/extractors/phone-extractor.ts";
import { extractReferences } from "../../functions/_shared/extractors/reference-extractor.ts";
import { extractTimes } from "../../functions/_shared/extractors/time-extractor.ts";
import { readTruth, type TruthStatus } from "./truth.ts";

// ── command line ──────────────────────────────────────────────────────────

/** `--name value`, or the fallback when the flag or its value is absent. */
export function flag(
  args: readonly string[],
  name: string,
  fallback: string,
): string;
export function flag(args: readonly string[], name: string): string | null;
export function flag(
  args: readonly string[],
  name: string,
  fallback: string | null = null,
) {
  const index = args.indexOf(`--${name}`);
  if (index === -1 || index + 1 >= args.length) return fallback;
  return args[index + 1];
}

export function numberFlag(
  args: readonly string[],
  name: string,
  fallback: number,
): number {
  const value = Number(flag(args, name, String(fallback)));
  if (!Number.isFinite(value) || value < 0) {
    throw new Error(`--${name} must be a non-negative number.`);
  }
  return value;
}

// ── the corpus ────────────────────────────────────────────────────────────

const MIME_BY_EXTENSION: Readonly<Record<string, string>> = {
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".webp": "image/webp",
};

export interface CorpusImage {
  readonly name: string;
  readonly path: string;
  /** `null` for a format neither engine is benchmarked on. */
  readonly mimeType: string | null;
}

/** Every image in the set, sorted, excluding the truth sidecars. */
export async function listImages(setDir: string): Promise<CorpusImage[]> {
  const images: CorpusImage[] = [];
  for await (const entry of Deno.readDir(setDir)) {
    if (
      !entry.isFile || entry.name.endsWith(".json") ||
      entry.name.endsWith(".txt")
    ) continue;
    const extension = entry.name.slice(entry.name.lastIndexOf("."))
      .toLowerCase();
    images.push({
      name: entry.name,
      path: `${setDir}/${entry.name}`,
      mimeType: MIME_BY_EXTENSION[extension] ?? null,
    });
  }
  return images.sort((a, b) => a.name.localeCompare(b.name));
}

export function truthPath(image: CorpusImage): string {
  return `${image.path}.truth.json`;
}

/** The truth for an image, or why it cannot be scored. */
export async function loadTruth(image: CorpusImage): Promise<TruthStatus> {
  let text: string;
  try {
    text = await Deno.readTextFile(truthPath(image));
  } catch {
    return { kind: "skip", reason: "no ground truth — run --bootstrap first" };
  }
  try {
    return readTruth(JSON.parse(text));
  } catch {
    return { kind: "skip", reason: "truth file is not valid JSON" };
  }
}

/** Where an engine's transcription of an image is kept, for the analysis benchmark. */
export function transcriptionPath(
  textDir: string,
  imageName: string,
  engine: string,
): string {
  return `${textDir}/${imageName}.${engine}.txt`;
}

/**
 * Pixel dimensions straight from a JPEG or PNG header. `null` when unknown,
 * which callers treat as "size unknown", never as an error.
 */
export function readDimensions(
  bytes: Uint8Array,
): { width: number; height: number } | null {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);

  // PNG: IHDR width/height are fixed at bytes 16..24.
  if (bytes.length > 24 && bytes[0] === 0x89 && bytes[1] === 0x50) {
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
      if (
        marker >= 0xC0 && marker <= 0xCF && marker !== 0xC4 &&
        marker !== 0xC8 && marker !== 0xCC
      ) {
        return {
          height: view.getUint16(offset + 5),
          width: view.getUint16(offset + 7),
        };
      }
      offset += 2 + view.getUint16(offset + 2);
    }
  }

  return null;
}

// ── the extractors, as the online route will run them ─────────────────────

/**
 * Candidates for a reading: digits folded, then every extractor.
 *
 * This is the order T13's `createImageOcrPipeline` fixes for Gemini's text,
 * and the order the app follows before it sends Tesseract's. When T13 lands,
 * the OCR benchmark should drive that pipeline instead of this copy: F17
 * found that a benchmark reimplementing the pipeline misses fixes made inside
 * it.
 */
export function candidatesFor(text: string): ExtractedCandidates {
  const folded = normaliseDigits(text);
  return {
    dates: extractDates(folded),
    times: extractTimes(folded),
    amounts: extractAmounts(folded),
    phones: extractPhones(folded),
    references: extractReferences(folded),
  };
}

// ── pacing ────────────────────────────────────────────────────────────────
//
// A benchmark calls a provider once per document, back to back, where a user
// makes a few calls a day. Free tiers answer 429 within a handful of calls, so
// every run is paced (`--delay`) and backs off when told to. That changes the
// wall-clock time of a run, never its numbers.

const RATE_LIMIT_ATTEMPTS = 6;

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Retries `call` while it fails as `rate_limited`, waiting 4, 8, 16, 32, then
 * 64 s: comfortably past any per-minute window. Every other failure, and the
 * sixth rate limit, is rethrown for the caller to record.
 */
export async function withBackoff<T>(
  call: () => Promise<T>,
  onWait: (seconds: number, attempt: number) => void,
  wait: (ms: number) => Promise<void> = sleep,
): Promise<T> {
  for (let attempt = 1;; attempt++) {
    try {
      return await call();
    } catch (thrown) {
      const rateLimited = thrown instanceof ProviderFailure &&
        thrown.kind === "rate_limited";
      if (!rateLimited || attempt >= RATE_LIMIT_ATTEMPTS) throw thrown;
      const seconds = 2 ** (attempt + 1);
      onWait(seconds, attempt);
      await wait(seconds * 1000);
    }
  }
}

/**
 * Stops the run when the provider refused the key. That is a setup problem,
 * never a per-document result, so every later document would only fail the
 * same way. The message names the variable, never its value.
 */
export function stopIfKeyRefused(thrown: unknown, keyVariable: string): void {
  if (thrown instanceof ProviderFailure && thrown.kind === "auth") {
    throw new Error(`${keyVariable} was refused by the provider (auth). Check the key.`);
  }
}

/**
 * A failure's name for the report: the `ProviderFailure` kind, or the error's
 * class. Never its message, which for a tool error could quote a path or a
 * value.
 */
export function failureLabel(thrown: unknown): string {
  if (thrown instanceof ProviderFailure) return thrown.kind;
  return thrown instanceof Error ? thrown.name : "unknown";
}
