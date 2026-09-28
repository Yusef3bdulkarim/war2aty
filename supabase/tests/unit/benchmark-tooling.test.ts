/**
 * F20-T08 · Tests for the benchmark tooling: truth files, gates, corpus
 * helpers, pacing and the recording fetch.
 */

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { draftTruth, readTruth } from "../../tools/benchmark/truth.ts";
import {
  type AnalysisDocumentScore,
  analysisGates,
  type OcrDocumentScore,
  ocrGates,
} from "../../tools/benchmark/gates.ts";
import {
  candidatesFor,
  failureLabel,
  flag,
  numberFlag,
  readDimensions,
  transcriptionPath,
  withBackoff,
} from "../../tools/benchmark/corpus.ts";
import { recordingFetch } from "../../tools/benchmark/legs.ts";
import { ProviderFailure } from "../../functions/_shared/ai/provider-failure.ts";

// ── truth ─────────────────────────────────────────────────────────────────

const V2 = {
  schema_version: 2,
  category: "C4",
  writer: null,
  languages: ["ar"],
  text: "فاتورة كهرباء",
  dates: ["١٥/٠٨/٢٠٢٦"],
  amounts: ["850.50"],
  phones: [],
  references: [],
  expected_document_type: "invoice",
  key_dates: ["2026-08-15"],
  key_amounts: [850.5],
  key_actions: ["سدد الفاتورة"],
  needsOwnerCheck: [],
};

Deno.test("a v2 truth file is ready, with every field read", () => {
  const status = readTruth(V2);

  assert(status.kind === "ready");
  assertEquals(status.truth.schemaVersion, 2);
  assertEquals(status.truth.expectedDocumentType, "invoice");
  assertEquals(status.truth.keyDates, ["2026-08-15"]);
  assertEquals(status.truth.keyAmounts, [850.5]);
});

Deno.test("an F17 v1 truth file still loads, with its v2 fields empty", () => {
  const status = readTruth({
    category: "printed_clean",
    writer: null,
    text: "نص",
    dates: ["2026-08-15"],
    amounts: [],
    phones: [],
    references: [],
  });

  assert(status.kind === "ready");
  assertEquals(status.truth.schemaVersion, 1);
  assertEquals(status.truth.expectedDocumentType, null);
  assertEquals(status.truth.keyDates, []);
  assertEquals(status.truth.languages, []);
});

Deno.test("an uncorrected draft is never scored", () => {
  // Its text is the bootstrap engine's own reading: scoring it would report
  // a flawless CER.
  const status = readTruth(draftTruth("قراءة تسراكت"));

  assertEquals(status.kind, "skip");
});

Deno.test("an excluded or malformed file is skipped", () => {
  assertEquals(readTruth({ ...V2, category: "EXCLUDE" }).kind, "skip");
  assertEquals(readTruth({ category: "C1" }).kind, "skip");
  assertEquals(readTruth([]).kind, "skip");
  assertEquals(readTruth(null).kind, "skip");
});

Deno.test("key amounts that are not finite numbers are dropped", () => {
  const status = readTruth({
    ...V2,
    key_amounts: [850.5, "850", null, Infinity],
  });

  assert(status.kind === "ready");
  assertEquals(status.truth.keyAmounts, [850.5]);
});

Deno.test("a draft is v2 and carries the reading as its text", () => {
  const draft = draftTruth("نص");

  assertEquals(draft.schema_version, 2);
  assertEquals(draft.category, "UNCATEGORISED");
  assertEquals(draft.text, "نص");
});

// ── OCR gates ─────────────────────────────────────────────────────────────

function ocrDoc(overrides: Partial<OcrDocumentScore> = {}): OcrDocumentScore {
  return {
    category: "C1",
    ok: true,
    cer: 0.05,
    criticalFound: 9,
    criticalExpected: 10,
    latencyMs: 4_000,
    ...overrides,
  };
}

function gate(results: ReturnType<typeof ocrGates>, id: string) {
  return results.find((g) => g.id === id)!;
}

Deno.test("OCR gates pass a run within every limit", () => {
  const results = ocrGates([ocrDoc(), ocrDoc({ cer: 0.08 })], 0.273);

  assertEquals(results.map((g) => g.passed), [true, true, true, true]);
});

Deno.test("G1b judges only C1–C7; C10 handwriting is reported, not gated", () => {
  const results = ocrGates([
    ocrDoc({ cer: 0.05 }),
    ocrDoc({ category: "C10", cer: 0.9 }),
  ], 0.273);

  assertEquals(gate(results, "G1b").passed, true);
  assertEquals(gate(results, "G1a").passed, false);
});

Deno.test("G2 pools critical fields across gated documents", () => {
  // 9/10 + 0/1 = 9/11 < 0.9, although the per-document mean would be 0.45.
  const results = ocrGates([
    ocrDoc(),
    ocrDoc({ criticalFound: 0, criticalExpected: 1 }),
  ], null);

  assertEquals(gate(results, "G2").passed, false);
  assertEquals(gate(results, "G2").detail, "9/11 dates+amounts read");
});

Deno.test("G3 fails a p95 over 15 s and ignores failed calls", () => {
  const slow = Array.from({ length: 19 }, () => ocrDoc()).concat(
    ocrDoc({ latencyMs: 20_000 }),
  );
  const failed = ocrDoc({ ok: false, cer: null, latencyMs: 60_000 });

  assertEquals(gate(ocrGates(slow, null), "G3").passed, true);
  assertEquals(
    gate(ocrGates([...slow, ocrDoc({ latencyMs: 20_000 })], null), "G3").passed,
    false,
  );
  assertEquals(gate(ocrGates([ocrDoc(), failed], null), "G3").passed, true);
});

Deno.test("a gate this run cannot measure is null, never a pass", () => {
  const results = ocrGates([ocrDoc({ category: "C10" })], null);

  assertEquals(gate(results, "G1a").passed, null);
  assertEquals(gate(results, "G1b").passed, null);
  assertEquals(gate(results, "G2").passed, null);
});

// ── analysis gates ────────────────────────────────────────────────────────

function answer(
  overrides: Partial<AnalysisDocumentScore> = {},
): AnalysisDocumentScore {
  return { schemaValid: true, semanticValid: true, rating: null, ...overrides };
}

Deno.test("G4a demands every answer schema-valid", () => {
  const results = analysisGates({
    scores: [answer(), answer({ schemaValid: false, semanticValid: false })],
    rates: {},
    groqRates: null,
  });

  assertEquals(results.find((g) => g.id === "G4a")!.passed, false);
});

Deno.test("G4b allows up to 3 % semantic rejects", () => {
  const scores = [
    ...Array.from({ length: 33 }, () => answer()),
    answer({ semanticValid: false }),
  ];

  assertEquals(
    analysisGates({ scores, rates: {}, groqRates: null }).find((g) => g.id === "G4b")!.passed,
    true,
  );
});

Deno.test("G4c fails when Mistral trails Groq by more than 5 pp on any metric", () => {
  const results = analysisGates({
    scores: [answer()],
    rates: { typeAccuracy: 0.9, dateRecall: 0.8 },
    groqRates: { typeAccuracy: 0.92, dateRecall: 0.9 },
  });

  const g4c = results.find((g) => g.id === "G4c")!;
  assertEquals(g4c.passed, false);
  assert(g4c.detail.includes("dateRecall"));
});

Deno.test("G4c is unmeasured without a saved Groq run", () => {
  const results = analysisGates({
    scores: [answer()],
    rates: { x: 1 },
    groqRates: null,
  });

  assertEquals(results.find((g) => g.id === "G4c")!.passed, null);
});

Deno.test("G5 counts a rejected answer the owner rated acceptable as a false reject", () => {
  const g5 = (scores: AnalysisDocumentScore[]) =>
    analysisGates({ scores, rates: {}, groqRates: null }).find((g) => g.id === "G5")!.passed;

  assertEquals(g5([answer()]), true);
  assertEquals(g5([answer({ semanticValid: false })]), null); // not rated yet
  assertEquals(g5([answer({ semanticValid: false, rating: 2 })]), true);
  assertEquals(g5([answer({ semanticValid: false, rating: 3 })]), false);
});

// ── corpus helpers ────────────────────────────────────────────────────────

Deno.test("flag reads a value, or the fallback", () => {
  const args = ["--ocr", "gemini", "--bootstrap"];

  assertEquals(flag(args, "ocr"), "gemini");
  assertEquals(flag(args, "set", "golden"), "golden");
  assertEquals(flag(args, "missing"), null);
});

Deno.test("numberFlag rejects a value that is not a non-negative number", () => {
  assertEquals(numberFlag(["--delay", "500"], "delay", 0), 500);
  let threw = false;
  try {
    numberFlag(["--delay", "soon"], "delay", 0);
  } catch {
    threw = true;
  }
  assert(threw);
});

Deno.test("readDimensions reads a PNG header", () => {
  const png = new Uint8Array(32);
  png.set([0x89, 0x50, 0x4e, 0x47]);
  new DataView(png.buffer).setUint32(16, 1200);
  new DataView(png.buffer).setUint32(20, 1600);

  assertEquals(readDimensions(png), { width: 1200, height: 1600 });
});

Deno.test("readDimensions reads a JPEG SOF segment", () => {
  const jpeg = new Uint8Array([
    0xff,
    0xd8, // SOI
    0xff,
    0xe0,
    0x00,
    0x04,
    0x00,
    0x00, // APP0, length 4
    0xff,
    0xc0,
    0x00,
    0x11,
    0x08,
    0x06,
    0x40,
    0x04,
    0xb0,
    0x03, // SOF0: h=1600, w=1200
    0x00,
    0x00,
    0x00,
    0x00,
  ]);

  assertEquals(readDimensions(jpeg), { width: 1200, height: 1600 });
});

Deno.test("readDimensions is null for an unknown format", () => {
  assertEquals(readDimensions(new TextEncoder().encode("RIFF....WEBP")), null);
});

Deno.test("candidatesFor folds Arabic-Indic digits before extracting", () => {
  // The extractors match \d, which never matches ٠-٩ (F17's 8576134).
  const candidates = candidatesFor("آخر موعد للسداد ١٥/٠٨/٢٠٢٦");

  assertEquals(candidates.dates.length, 1);
});

Deno.test("transcriptionPath names the engine", () => {
  assertEquals(
    transcriptionPath("golden-ocr", "bill.jpg", "gemini"),
    "golden-ocr/bill.jpg.gemini.txt",
  );
});

// ── pacing ────────────────────────────────────────────────────────────────

Deno.test("withBackoff retries a rate limit with growing waits, without sleeping", async () => {
  const waits: number[] = [];
  let calls = 0;

  const result = await withBackoff(
    () => {
      calls += 1;
      return calls < 3
        ? Promise.reject(new ProviderFailure("rate_limited"))
        : Promise.resolve("ok");
    },
    () => {},
    (ms) => {
      waits.push(ms);
      return Promise.resolve();
    },
  );

  assertEquals(result, "ok");
  assertEquals(waits, [4_000, 8_000]);
});

Deno.test("withBackoff rethrows any other failure at once", async () => {
  let calls = 0;

  await assertRejects(
    () =>
      withBackoff(
        () => {
          calls += 1;
          return Promise.reject(new ProviderFailure("auth"));
        },
        () => {},
        () => Promise.resolve(),
      ),
    ProviderFailure,
  );
  assertEquals(calls, 1);
});

Deno.test("withBackoff gives up after six rate limits", async () => {
  let calls = 0;

  await assertRejects(
    () =>
      withBackoff(
        () => {
          calls += 1;
          return Promise.reject(new ProviderFailure("rate_limited"));
        },
        () => {},
        () => Promise.resolve(),
      ),
    ProviderFailure,
  );
  assertEquals(calls, 6);
});

Deno.test("failureLabel names the kind or the class, never the message", () => {
  assertEquals(failureLabel(new ProviderFailure("timeout")), "timeout");
  assertEquals(failureLabel(new TypeError("رقم الحساب 12345678")), "TypeError");
  assertEquals(failureLabel("string"), "unknown");
});

// ── recording fetch ───────────────────────────────────────────────────────

Deno.test("recordingFetch keeps finish reason, usage and content, and passes the response on", async () => {
  const body = {
    choices: [{
      message: { content: '{"status":"success"}' },
      finish_reason: "length",
    }],
    usage: { prompt_tokens: 1500, completion_tokens: 2000 },
  };
  const recorder = recordingFetch(() => Promise.resolve(new Response(JSON.stringify(body))));

  const response = await recorder.fetchImpl("https://example.test");

  assertEquals(await response.json(), body);
  assertEquals(recorder.last(), {
    status: 200,
    finishReason: "length",
    promptTokens: 1500,
    completionTokens: 2000,
    content: '{"status":"success"}',
  });
});

Deno.test("recordingFetch never reads an error body", async () => {
  let cancelled = false;
  const recorder = recordingFetch(() =>
    Promise.resolve(
      new Response(
        new ReadableStream({
          cancel() {
            cancelled = true;
          },
        }),
        { status: 429 },
      ),
    )
  );

  const response = await recorder.fetchImpl("https://example.test");
  await response.body?.cancel();

  assertEquals(recorder.last()?.status, 429);
  assertEquals(recorder.last()?.content, null);
  assert(cancelled);
});

Deno.test("recordingFetch forgets on reset", async () => {
  const recorder = recordingFetch(() => Promise.resolve(new Response("{}")));
  await recorder.fetchImpl("https://example.test");

  recorder.reset();

  assertEquals(recorder.last(), null);
});
