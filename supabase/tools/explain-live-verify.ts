/**
 * F36-T20 · Live verification of the deployed `explain-document` endpoint.
 *
 * Sends real golden-set photos through the deployed endpoint (staging or
 * production) and validates the §33 response shape, latency, and no-leak
 * guarantee. This is NOT the benchmark (T18) — it tests the DEPLOYED
 * endpoint over the wire, including auth, config gates, slot reservation,
 * real Gemini OCR, and real Mistral/Groq explain.
 *
 * PRIVACY (§7, §51): stdout carries metrics only. Response bodies are
 * written to the git-ignored `--out` directory.
 *
 * Usage (from the repo root):
 *   deno run --allow-read --allow-write --allow-net \
 *     supabase/tools/explain-live-verify.ts \
 *     --url https://jecujrsvbmashkpobtsz.supabase.co \
 *     --anon-key <staging-anon-key> \
 *     --set golden \
 *     --out golden-live \
 *     --delay 5000
 *
 *   --url <supabase-url>   Target Supabase project URL.       (required)
 *   --anon-key <key>       Project's public anon key.          (required)
 *   --set <dir>            Directory with images.              (default: golden)
 *   --out <dir>            Where response bodies are saved.    (default: golden-live)
 *   --images <list>        Comma-separated image filenames.    (default: all with truth)
 *   --delay <ms>           Pause between requests.             (default: 5000)
 *   --max <n>              Stop after n images.                (default: all)
 *   --save <file>          Save summary JSON.
 */

import {
  EXPLAIN_MAX_PARAGRAPHS,
  EXPLAIN_PAGE_MAX_CHARS,
  EXPLAIN_PARAGRAPH_MAX_CHARS,
  EXPLAIN_TITLE_MAX_CHARS,
} from "../functions/_shared/schemas/explain-output.schema.ts";
import { pageLength } from "../functions/_shared/validators/explain-grounding.ts";
import { flag, listImages, numberFlag } from "./benchmark/corpus.ts";

// ── CLI ──────────────────────────────────────────────────────────────────

const args = Deno.args;
const supabaseUrl = flag(args, "url");
const anonKey = flag(args, "anon-key");
if (!supabaseUrl || !anonKey) {
  console.error("Usage: --url <supabase-url> --anon-key <anon-key>");
  Deno.exit(1);
}

const setDir = flag(args, "set", "golden");
const outDir = flag(args, "out", "golden-live");
const delayMs = numberFlag(args, "delay", 5000);
const maxImages = numberFlag(args, "max", 999);
const saveFile = flag(args, "save");
const imageFilter = flag(args, "images");

// ── anonymous auth ───────────────────────────────────────────────────────

async function mintToken(): Promise<string> {
  const res = await fetch(`${supabaseUrl}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: anonKey!, "Content-Type": "application/json" },
    body: "{}",
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Auth failed (${res.status}): ${text}`);
  }
  const session = await res.json();
  return session.access_token as string;
}

// ── per-document result ──────────────────────────────────────────────────

interface LiveResult {
  readonly file: string;
  readonly httpStatus: number;
  readonly latencyMs: number;
  // success fields
  readonly status: string | null;
  readonly title: string | null;
  readonly titleLength: number | null;
  readonly explainParagraphs: number | null;
  readonly pageTotalChars: number | null;
  readonly titleOk: boolean | null;
  readonly paragraphCapsOk: boolean | null;
  readonly pageOk: boolean | null;
  readonly hasTodo: boolean | null;
  readonly hasDate: boolean | null;
  readonly hasCaution: boolean | null;
  readonly hasContact: boolean | null;
  readonly hasPlace: boolean | null;
  // error fields
  readonly errorCode: string | null;
  readonly errorMessage: string | null;
}

// ── call the endpoint ────────────────────────────────────────────────────

async function callExplain(
  token: string,
  imageBytes: Uint8Array,
  mimeType: string,
): Promise<
  { status: number; body: Record<string, unknown>; latencyMs: number }
> {
  const base64 = btoa(
    imageBytes.reduce((s, b) => s + String.fromCharCode(b), ""),
  );

  const requestBody = {
    explain_schema_version: "1.0",
    session_id: crypto.randomUUID(),
    installation_id: crypto.randomUUID(),
    app_version: "1.1.0",
    image: { data: base64, mime_type: mimeType },
  };

  const t0 = performance.now();
  const res = await fetch(`${supabaseUrl}/functions/v1/explain-document`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      apikey: anonKey!,
    },
    body: JSON.stringify(requestBody),
    signal: AbortSignal.timeout(60_000),
  });
  const latencyMs = Math.round(performance.now() - t0);
  const body = await res.json();
  return { status: res.status, body, latencyMs };
}

// ── validate a success response ──────────────────────────────────────────

function validateSuccess(
  body: Record<string, unknown>,
): LiveResult & { raw: Record<string, unknown> } {
  const status = body.status as string;
  const paper = body.paper as { title: string } | undefined;
  const explain = body.explain as string[] | undefined;
  const todo = body.todo as { required: boolean; text: string } | undefined;
  const date = body.date as
    | { date: string; time: string | null; text: string }
    | null;
  const caution = body.caution as { text: string } | null;
  const contact = body.contact as { name: string; phone: string } | null;
  const place = body.place as { text: string } | null;

  const title = paper?.title ?? null;
  const titleLength = title?.length ?? null;
  const explainParagraphs = explain?.length ?? null;

  // page total (reuse the grounding module's counter)
  let pageTotalChars: number | null = null;
  if (explain && todo && paper) {
    try {
      pageTotalChars = pageLength(body as Parameters<typeof pageLength>[0]);
    } catch {
      pageTotalChars = null;
    }
  }

  const titleOk = titleLength !== null
    ? titleLength <= EXPLAIN_TITLE_MAX_CHARS
    : null;
  const paragraphCapsOk = explain
    ? explain.every((p) => p.length <= EXPLAIN_PARAGRAPH_MAX_CHARS)
    : null;
  const pageOk = pageTotalChars !== null
    ? pageTotalChars <= EXPLAIN_PAGE_MAX_CHARS
    : null;

  return {
    file: "",
    httpStatus: 200,
    latencyMs: 0,
    status,
    title,
    titleLength,
    explainParagraphs,
    pageTotalChars,
    titleOk,
    paragraphCapsOk,
    pageOk,
    hasTodo: todo !== undefined && todo !== null,
    hasDate: date !== null,
    hasCaution: caution !== null,
    hasContact: contact !== null,
    hasPlace: place !== null,
    errorCode: null,
    errorMessage: null,
    raw: body,
  };
}

// ── main ─────────────────────────────────────────────────────────────────

async function main() {
  console.log(`\n  explain-document live verification`);
  console.log(`  target: ${supabaseUrl}`);
  console.log(`  set:    ${setDir}\n`);

  // mkdir -p outDir
  try {
    await Deno.mkdir(outDir, { recursive: true });
  } catch { /* exists */ }

  // mint a token
  console.log("  Signing in anonymously…");
  const token = await mintToken();
  console.log("  ✓ Token minted.\n");

  // list images
  let images = await listImages(setDir);
  if (imageFilter) {
    const names = new Set(imageFilter.split(",").map((s) => s.trim()));
    images = images.filter((i) => names.has(i.name));
  }
  // only images with a truth file (real papers, not unprocessed ones)
  const withTruth: typeof images = [];
  for (const img of images) {
    try {
      await Deno.stat(`${img.path}.truth.json`);
      withTruth.push(img);
    } catch { /* no truth file */ }
  }
  images = withTruth.slice(0, maxImages);

  if (images.length === 0) {
    console.error("  No images found in the set.");
    Deno.exit(1);
  }

  console.log(`  ${images.length} image(s) to verify:\n`);

  const results: LiveResult[] = [];

  for (let i = 0; i < images.length; i++) {
    const img = images[i];
    if (!img.mimeType) {
      console.log(
        `  [${
          i + 1
        }/${images.length}] ${img.name} — unsupported format, skipping`,
      );
      continue;
    }

    console.log(`  [${i + 1}/${images.length}] ${img.name} (${img.mimeType})`);

    const bytes = await Deno.readFile(img.path);
    const sizeKb = (bytes.length / 1024).toFixed(1);
    console.log(`    size: ${sizeKb} KB`);

    try {
      const { status, body, latencyMs } = await callExplain(
        token,
        bytes,
        img.mimeType,
      );

      if (status === 200) {
        const v = validateSuccess(body);
        const result: LiveResult = {
          ...v,
          file: img.name,
          httpStatus: status,
          latencyMs,
        };
        results.push(result);

        console.log(`    ${status} ${v.status} — ${latencyMs} ms`);
        console.log(
          `    title: "${v.title}" (${v.titleLength} chars${
            v.titleOk ? "" : " ⚠ OVER CAP"
          })`,
        );
        console.log(
          `    explain: ${v.explainParagraphs} paragraphs, ${v.pageTotalChars} chars total${
            v.pageOk ? "" : " ⚠ OVER PAGE CAP"
          }`,
        );
        console.log(
          `    cards: todo=${v.hasTodo} date=${v.hasDate} caution=${v.hasCaution} contact=${v.hasContact} place=${v.hasPlace}`,
        );

        // save the response body (no reading, only the explained output)
        const outFile = `${outDir}/${img.name}.response.json`;
        await Deno.writeTextFile(outFile, JSON.stringify(body, null, 2));
      } else {
        const errorCode = (body as Record<string, unknown>).code as string ??
          "unknown";
        const errorMessage =
          (body as Record<string, unknown>).message as string ?? "";
        results.push({
          file: img.name,
          httpStatus: status,
          latencyMs,
          status: null,
          title: null,
          titleLength: null,
          explainParagraphs: null,
          pageTotalChars: null,
          titleOk: null,
          paragraphCapsOk: null,
          pageOk: null,
          hasTodo: null,
          hasDate: null,
          hasCaution: null,
          hasContact: null,
          hasPlace: null,
          errorCode,
          errorMessage,
        });
        console.log(`    ${status} ${errorCode} — ${latencyMs} ms`);
        console.log(`    ${errorMessage}`);
      }
    } catch (err) {
      console.log(`    FAILED: ${(err as Error).message}`);
      results.push({
        file: img.name,
        httpStatus: 0,
        latencyMs: 0,
        status: null,
        title: null,
        titleLength: null,
        explainParagraphs: null,
        pageTotalChars: null,
        titleOk: null,
        paragraphCapsOk: null,
        pageOk: null,
        hasTodo: null,
        hasDate: null,
        hasCaution: null,
        hasContact: null,
        hasPlace: null,
        errorCode: "client_error",
        errorMessage: (err as Error).message,
      });
    }

    if (i < images.length - 1) {
      console.log(`    waiting ${delayMs} ms…`);
      await new Promise((r) => setTimeout(r, delayMs));
    }
    console.log();
  }

  // ── summary ──────────────────────────────────────────────────────────

  const total = results.length;
  const succeeded = results.filter((r) => r.httpStatus === 200);
  const failed = results.filter((r) => r.httpStatus !== 200);

  console.log(`\n  ── Summary ──────────────────────────────────────────────`);
  console.log(`  Total:     ${total}`);
  console.log(`  Succeeded: ${succeeded.length}`);
  console.log(`  Failed:    ${failed.length}`);

  if (succeeded.length > 0) {
    const latencies = succeeded.map((r) => r.latencyMs).sort((a, b) => a - b);
    const p50 = latencies[Math.floor(latencies.length * 0.5)];
    const p95 = latencies[Math.floor(latencies.length * 0.95)];
    const max = latencies[latencies.length - 1];

    console.log(`\n  Latency: p50 ${p50} ms, p95 ${p95} ms, max ${max} ms`);
    console.log(
      `  D4 budget (30 s): ${
        latencies.every((l) => l <= 30_000) ? "✓ all within" : "⚠ some exceeded"
      }`,
    );

    const titleOk = succeeded.filter((r) => r.titleOk === true).length;
    const pageOk = succeeded.filter((r) => r.pageOk === true).length;
    const paragraphOk = succeeded.filter((r) =>
      r.paragraphCapsOk === true
    ).length;

    console.log(`\n  §33 caps:`);
    console.log(
      `    title ≤ ${EXPLAIN_TITLE_MAX_CHARS}:       ${titleOk}/${succeeded.length}`,
    );
    console.log(
      `    para ≤ ${EXPLAIN_PARAGRAPH_MAX_CHARS}:      ${paragraphOk}/${succeeded.length}`,
    );
    console.log(
      `    page ≤ ${EXPLAIN_PAGE_MAX_CHARS}:      ${pageOk}/${succeeded.length}`,
    );

    const statuses = succeeded.reduce((acc, r) => {
      acc[r.status ?? "?"] = (acc[r.status ?? "?"] ?? 0) + 1;
      return acc;
    }, {} as Record<string, number>);
    console.log(`\n  Statuses: ${JSON.stringify(statuses)}`);

    const withDate = succeeded.filter((r) => r.hasDate).length;
    const withCaution = succeeded.filter((r) => r.hasCaution).length;
    const withContact = succeeded.filter((r) => r.hasContact).length;
    const withPlace = succeeded.filter((r) => r.hasPlace).length;
    console.log(
      `  Cards: date ${withDate}, caution ${withCaution}, contact ${withContact}, place ${withPlace}`,
    );
  }

  if (failed.length > 0) {
    console.log(`\n  Failures:`);
    for (const r of failed) {
      console.log(
        `    ${r.file}: ${r.httpStatus} ${r.errorCode} — ${r.errorMessage}`,
      );
    }
  }

  // save summary
  if (saveFile) {
    const summary = {
      timestamp: new Date().toISOString(),
      target: supabaseUrl,
      total,
      succeeded: succeeded.length,
      failed: failed.length,
      results: results.map((
        {
          file,
          httpStatus,
          latencyMs,
          status,
          titleLength,
          pageTotalChars,
          titleOk,
          pageOk,
          errorCode,
        },
      ) => ({
        file,
        httpStatus,
        latencyMs,
        status,
        titleLength,
        pageTotalChars,
        titleOk,
        pageOk,
        errorCode,
      })),
    };
    await Deno.writeTextFile(saveFile, JSON.stringify(summary, null, 2));
    console.log(`\n  Summary saved to ${saveFile}`);
  }

  console.log();
}

main().catch((err) => {
  console.error(err);
  Deno.exit(1);
});
