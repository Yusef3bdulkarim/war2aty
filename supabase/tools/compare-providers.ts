/**
 * F18-T10 · Side-by-side provider comparison.
 *
 * Runs BOTH analysis legs over the same OCR text — same prompt builder, same
 * generation schema, same shape and semantic checks, and none of the soft
 * validation pipeline — and prints the fields that decide whether one provider
 * is as good as the other on Egyptian paperwork: `status`, `document_type`,
 * `amounts`, `dates`.
 *
 * The app cannot answer that question: it deliberately never learns which
 * provider served it, so quality has to be compared here.
 *
 * F20-T07: the legs are Mistral (the analysis primary) and Groq (its
 * fallback). Gemini became the OCR provider and is no longer an analysis leg.
 * For the whole corpus rather than one document, use `analysis-benchmark.ts`
 * (T08), which builds the same legs (`benchmark/legs.ts`).
 *
 * ── Usage ─────────────────────────────────────────────────────────────────
 *   GROQ_API_KEY=… GROQ_MODEL=… MISTRAL_API_KEY=… MISTRAL_MODEL=… \
 *     deno run --allow-net --allow-env --allow-read \
 *       supabase/tools/compare-providers.ts <file.txt>
 *
 * The file holds the OCR text of one document — paste it from the app's OCR
 * review screen, or from any `.txt`. Reads stdin when no path is given, in
 * which case `--allow-read` is unnecessary:
 *
 *   cat bill.txt | GROQ_API_KEY=… … deno run --allow-net --allow-env \
 *     supabase/tools/compare-providers.ts
 *
 * ── PRIVACY, read before running ──────────────────────────────────────────
 * This sends the text you give it to BOTH providers, and prints it back to your
 * terminal. Both run on free tiers whose terms may let the provider use or
 * review API input (see CLAUDE.md §7). Feed it documents you are willing to
 * have read — a synthetic bill, or your own paperwork — and never another
 * person's. It writes nothing to disk and logs no key.
 *
 * ── Pacing ────────────────────────────────────────────────────────────────
 * One analysis per provider per run, so a single run is well inside Groq's
 * 8,000 tokens/minute. Comparing several documents in a loop is NOT: leave
 * ~20s between runs, or Groq will answer 429 and the comparison will look like
 * a Mistral win when it is only a rate limit.
 */

import type { AnalysisLeg } from "../functions/_shared/ai/analysis-provider.ts";
import type { AnalysisPromptInput } from "../functions/_shared/prompts/analysis-prompt.ts";
import type { ModelAnalysis } from "../functions/_shared/schemas/analysis-output.schema.ts";
import { candidatesFor } from "./benchmark/corpus.ts";
import { analysisLeg } from "./benchmark/legs.ts";

const TIMEOUT_SECONDS = 40;

function hasArabic(text: string): boolean {
  return /[؀-ۿ]/.test(text);
}

async function readInput(): Promise<string> {
  const path = Deno.args[0];
  if (path !== undefined) return await Deno.readTextFile(path);

  const chunks: Uint8Array[] = [];
  for await (const chunk of Deno.stdin.readable) chunks.push(chunk);
  return new TextDecoder().decode(
    chunks.reduce<Uint8Array>((all, c) => {
      const merged = new Uint8Array(all.length + c.length);
      merged.set(all);
      merged.set(c, all.length);
      return merged;
    }, new Uint8Array()),
  );
}

type Outcome =
  | { readonly ok: true; readonly analysis: ModelAnalysis; readonly ms: number }
  | { readonly ok: false; readonly error: string; readonly ms: number };

async function run(
  label: string,
  leg: AnalysisLeg,
  input: AnalysisPromptInput,
): Promise<Outcome> {
  const startedAt = Date.now();
  try {
    const analysis = await leg(
      input,
      AbortSignal.timeout(TIMEOUT_SECONDS * 1000),
    );
    return { ok: true, analysis, ms: Date.now() - startedAt };
  } catch (thrown) {
    const code = thrown instanceof Error ? thrown.message : String(thrown);
    console.error(`  ${label} failed: ${code}`);
    return { ok: false, error: code, ms: Date.now() - startedAt };
  }
}

// ── rendering ─────────────────────────────────────────────────────────────

function amountLines(analysis: ModelAnalysis): string[] {
  return analysis.amounts.map((a) => `${a.value} ${a.currency} — ${a.label} [${a.confidence}]`);
}

function dateLines(analysis: ModelAnalysis): string[] {
  return analysis.dates.map((d) =>
    `${d.date}${d.time === null ? "" : " " + d.time} — ${d.role} — ${d.label}` +
    ` [${d.confidence}]${d.is_reminder_worthy ? " ⏰" : ""}`
  );
}

function summarise(outcome: Outcome): Record<string, string> {
  if (!outcome.ok) return { status: `ERROR: ${outcome.error}` };

  const a = outcome.analysis;
  return {
    "status": a.status,
    "doc type": `${a.document_type.type} [${a.document_type.confidence}]`,
    "doc title": a.document_type.title,
    "summary.short": a.summary.short,
    "amounts": amountLines(a).join("\n") || "(none)",
    "dates": dateLines(a).join("\n") || "(none)",
    "key info": String(a.key_information.length),
    "actions": String(a.actions_required.length),
    "warnings": a.warnings.map((w) => w.type).join(", ") || "(none)",
    "missing": a.missing_fields.join(", ") || "(none)",
    "arabic?": hasArabic(a.summary.detailed) ? "yes" : "NO — investigate",
    "latency": `${outcome.ms} ms`,
  };
}

function render(mistral: Outcome, groq: Outcome): void {
  const left = summarise(mistral);
  const right = summarise(groq);
  const keys = [...new Set([...Object.keys(left), ...Object.keys(right)])];

  for (const key of keys) {
    const l = left[key] ?? "—";
    const r = right[key] ?? "—";
    const same = l === r;
    // Only `latency` is expected to differ; anything else flags for a human.
    const mark = key === "latency" ? " " : same ? "=" : "≠";

    console.log(`\n${mark} ${key.toUpperCase()}`);
    console.log(`    mistral │ ${l.split("\n").join("\n            │ ")}`);
    console.log(`    groq    │ ${r.split("\n").join("\n            │ ")}`);
  }
}

/** The fields a quality comparison actually rests on. */
function verdict(mistral: Outcome, groq: Outcome): void {
  console.log(`\n${"─".repeat(72)}`);

  if (!mistral.ok || !groq.ok) {
    console.log(
      "INCOMPLETE — one leg failed, so no quality comparison is possible.",
    );
    console.log(
      "If it was Groq with AI_RATE_LIMITED, wait a minute and re-run.",
    );
    return;
  }

  const m = mistral.analysis;
  const g = groq.analysis;

  const checks: [string, boolean][] = [
    ["same document_type", g.document_type.type === m.document_type.type],
    ["same status", g.status === m.status],
    ["same amount count", g.amounts.length === m.amounts.length],
    [
      "same amount values",
      JSON.stringify(g.amounts.map((a) => a.value).sort()) ===
        JSON.stringify(m.amounts.map((a) => a.value).sort()),
    ],
    ["same date count", g.dates.length === m.dates.length],
    [
      "same date values",
      JSON.stringify(g.dates.map((d) => d.date).sort()) ===
        JSON.stringify(m.dates.map((d) => d.date).sort()),
    ],
    [
      "both answered in Arabic",
      hasArabic(g.summary.detailed) && hasArabic(m.summary.detailed),
    ],
  ];

  for (const [name, passed] of checks) {
    console.log(`  ${passed ? "✅" : "⚠️ "} ${name}`);
  }

  const agreed = checks.every(([, passed]) => passed);
  console.log(
    agreed
      ? "\nAGREED on every decision field."
      : "\nDISAGREED on at least one field. Read the ⚠️ rows above and judge which " +
        "reading is correct against the paper itself — a difference is not " +
        "automatically either provider's failure.",
  );
}

// ── main ──────────────────────────────────────────────────────────────────

// Read once, up front: a missing variable fails before any text is sent. The
// messages name the variable only, never a value.
let mistralLeg: AnalysisLeg;
let groqLeg: AnalysisLeg;
try {
  mistralLeg = analysisLeg("mistral");
  groqLeg = analysisLeg("groq");
} catch (thrown) {
  console.error(
    `${thrown instanceof Error ? thrown.message : thrown} Both providers must be ` +
      "configured: MISTRAL_API_KEY, MISTRAL_MODEL, GROQ_API_KEY and GROQ_MODEL.",
  );
  Deno.exit(1);
}

const ocrText = (await readInput()).trim();

if (ocrText.length === 0) {
  console.error("No OCR text given. Pass a file path, or pipe text on stdin.");
  Deno.exit(1);
}

const input: AnalysisPromptInput = {
  ocrText,
  detectedLanguages: hasArabic(ocrText) ? ["ar"] : ["en"],
  candidates: candidatesFor(ocrText),
};

console.log(`${"─".repeat(72)}`);
console.log(
  `Document: ${ocrText.length} chars, ${ocrText.split("\n").length} lines`,
);
console.log(
  `Candidates found on the page: ${input.candidates.amounts.length} amounts, ` +
    `${input.candidates.dates.length} dates, ${input.candidates.references.length} references`,
);
console.log(`${"─".repeat(72)}`);

// Sequential, not Promise.all: two concurrent calls make the slower one look
// slower than it is, and Groq's per-minute token budget is shared.
const mistral = await run("mistral", mistralLeg, input);
const groq = await run("groq", groqLeg, input);

render(mistral, groq);
verdict(mistral, groq);
