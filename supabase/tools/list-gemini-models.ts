/**
 * F36-T03 — what the reading chain can actually reach.
 *
 * F34 named "Gemini 3.5 Flash-Lite" and "Gemini 3.1 Flash-Lite" as the two
 * reading legs. Those are marketing names; T07 needs **model ids the production
 * key can call**, and T08 needs to know whether the Mistral key can call
 * `/v1/ocr` at all. This tool answers both from the keys themselves.
 *
 *   deno run --allow-net --allow-env --env-file=supabase/.env \
 *     supabase/tools/list-gemini-models.ts
 *
 * Optional flags:
 *   --models=a,b      probe exactly these ids instead of the Flash-Lite ones
 *   --probe-limit=6   cap on how many models are probed (default 6)
 *   --image=<path>    probe with a real photo (needs --allow-read) instead of
 *                     the built-in "123" bitmap
 *   --no-probe        list only; make no image calls
 *   --out=<path>      also write the report to a file (needs --allow-write)
 *
 * Listing a model is not reaching it: a key can see models it may not call, and
 * a free tier can refuse one at call time. So every candidate gets ONE real
 * image call — the built-in 260x140 PNG of the digits "123" — and the report
 * says whether the model answered, and whether it read the digits back. That is
 * reachability and permission, NOT reading quality: quality is T18's benchmark
 * against the real corpus.
 *
 * Daily limits cannot be read from any API. The report ends with the AI Studio
 * rows to copy, which is the same manual step F36-T02 ended with.
 *
 * Prints no key. The probe image is generated, not a user's paper.
 */

const GEMINI_KEY = Deno.env.get("GEMINI_API_KEY")?.trim();
const MISTRAL_KEY = Deno.env.get("MISTRAL_API_KEY")?.trim();

const GEMINI_REST = "https://generativelanguage.googleapis.com/v1beta";
const MISTRAL_REST = "https://api.mistral.ai/v1";

/**
 * A 260x140 PNG of the digits "123", black on white. Generated, not a photo:
 * it carries real glyphs, so a model that answers "123" has read an image
 * rather than merely accepted one.
 */
const PROBE_PNG_BASE64 =
  "iVBORw0KGgoAAAANSUhEUgAAAQQAAACMCAIAAAAV/kBcAAACDklEQVR42u3cwZEEIQwEQfnvNETgAg8kOsuCaU753Ksl6VSeQIJBgkGCQYJBgkGCQYJBgkGCQYJBgkGCQYJBgkGCQYJBgkGCQYrGUBdN/OZX2QsDDDDAAAMMMMAAAwwwwAADDDDAAAMMMMAAAwwwwAADDDDAAAMMMMAAAwwwwAADDDDAAAMMMMAAAwwwwAADDDDAAAMMMMAAQxKGiYMnlvZWMMAAAwwwwAADDDDAAAMMMMAAAwwwwAADDDDAAAMMMMAAAwwwwAADDDDAAAMMMMAAAwwwwAADDDDAAAMMMMAAAwwwOA4YYHAcMPgD98b/7DjS9sLgOOyFwXHYC4PjsBcGGOyFAQZ7YYDBXhhggAEGGGCAAQYYYIABBhhggAEGGGCAAQYYYIABBhhggAEGGGCAAQYYYIABBhhggAGGIAxL7d/ZYcEAAwwwwAADDDDAAAMMMMAAAwy+GQYYfDMMMPhmGGDwzTDA4JthgME3wwCDb4YBBhhggAEGGGCAAQYYYIABBhhggAEGwQCD5mPwA3l7/UMAx2EvDI7DXhg8lr0weCx7YfBY9sLgseyFwWPZC4PHstdeGOy1FwZ77YXBXnthcBz2wuA47IXBcdgLg+OwFwbHYS8MjsNeGByHvTA4Dns7YZB+CgYJBgkGCQYJBgkGCQYJBgkGCQYJBgkGCQYJBgkGCQYJBgkGCQapRRtgf+K1MXmgtAAAAABJRU5ErkJggg==";

const PROBE_PROMPT = "اقرأ الأرقام المكتوبة في الصورة ورجّعها زي ما هي، من غير أي كلام تاني.";

/** Chunked: spreading a multi-megabyte photo into `String.fromCharCode` overflows the stack. */
function base64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

// ---------------------------------------------------------------- CLI

function flag(name: string, fallback = ""): string {
  const hit = Deno.args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

const FORCED_MODELS = flag("models").split(",").map((m) => m.trim()).filter(Boolean);
const PROBE_LIMIT = Math.max(1, Number(flag("probe-limit", "6")) || 6);
const IMAGE_PATH = flag("image");
const NO_PROBE = Deno.args.includes("--no-probe");
const OUT_PATH = flag("out");

// ------------------------------------------------------------- listing

type Model = {
  name: string;
  displayName?: string;
  description?: string;
  inputTokenLimit?: number;
  supportedGenerationMethods?: string[];
};

async function listModels(): Promise<Model[]> {
  const response = await fetch(`${GEMINI_REST}/models?pageSize=1000`, {
    headers: { "x-goog-api-key": GEMINI_KEY! },
  });
  if (!response.ok) {
    throw new Error(`ListModels answered HTTP ${response.status}.`);
  }
  const body = await response.json() as { models?: Model[] };
  return body.models ?? [];
}

function id(model: Model): string {
  return model.name.replace(/^models\//, "");
}

/** The ids T07 would reach for, in the order it would try them. */
function readingCandidates(models: Model[]): string[] {
  if (FORCED_MODELS.length > 0) return FORCED_MODELS;
  const callable = models
    .filter((m) => m.supportedGenerationMethods?.includes("generateContent"))
    .map(id)
    // Previews and experiments are not something a production reading leg
    // should depend on; they are listed in the report but not probed. Image
    // GENERATORS (`-image`, nano-banana) read nothing and answer 429 off their
    // own tiny bucket, which the 2026-11-09 run proved the noisy way.
    .filter((modelId) => !/preview|exp|thinking|tts|image|nano-banana/.test(modelId));
  // `-latest` ids are ALIASES: Google moves them without warning, which is the
  // one thing a production reading leg must not do. They are probed last and
  // flagged, so T07 ends up holding pinned ids.
  const alias = (modelId: string) => modelId.includes("latest");
  const lite = callable.filter((modelId) => modelId.includes("flash-lite") && !alias(modelId));
  const flash = callable.filter((modelId) =>
    modelId.includes("flash") && !modelId.includes("lite") && !alias(modelId)
  );
  const aliases = callable.filter((modelId) => alias(modelId) && modelId.includes("flash"));
  return [...lite, ...flash, ...aliases].slice(0, PROBE_LIMIT);
}

// -------------------------------------------------------------- probing

type Probe = {
  model: string;
  status: number;
  ok: boolean;
  elapsedMs: number;
  text: string;
  readDigits: boolean;
  error: string | null;
};

async function probeGemini(model: string, imageBase64: string, mime: string): Promise<Probe> {
  const started = Date.now();
  const body = {
    contents: [{
      role: "user",
      parts: [
        { text: PROBE_PROMPT },
        { inline_data: { mime_type: mime, data: imageBase64 } },
      ],
    }],
    // 256, not 64: a reasoning model can spend a small budget entirely on
    // thinking and answer 200 with no text, which would read here as a model
    // that cannot see (observed with gemini-3.5-flash on 2026-11-09).
    generationConfig: { temperature: 0, maxOutputTokens: 256 },
  };

  let status = 0;
  let raw = "";
  try {
    const response = await fetch(`${GEMINI_REST}/models/${model}:generateContent`, {
      method: "POST",
      headers: { "x-goog-api-key": GEMINI_KEY!, "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    status = response.status;
    raw = await response.text();
  } catch (error) {
    return {
      model,
      status,
      ok: false,
      elapsedMs: Date.now() - started,
      text: "",
      readDigits: false,
      error: `threw: ${error}`,
    };
  }

  const elapsedMs = Date.now() - started;
  if (status < 200 || status >= 300) {
    return {
      model,
      status,
      ok: false,
      elapsedMs,
      text: "",
      readDigits: false,
      error: raw.replace(/\s+/g, " ").slice(0, 200),
    };
  }

  let text = "";
  try {
    const json = JSON.parse(raw) as {
      candidates?: { content?: { parts?: { text?: string }[] } }[];
    };
    text = (json.candidates?.[0]?.content?.parts ?? [])
      .map((part) => part.text ?? "")
      .join("")
      .trim();
  } catch {
    return {
      model,
      status,
      ok: false,
      elapsedMs,
      text: "",
      readDigits: false,
      error: "answered 200 with a body this tool could not parse",
    };
  }

  // Arabic-Indic digits fold to ASCII before the comparison, exactly as the
  // grounding validators do.
  const folded = text.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660));
  return {
    model,
    status,
    ok: text.length > 0,
    elapsedMs,
    text,
    readDigits: folded.includes("123"),
    error: text.length > 0 ? null : "answered 200 with no text",
  };
}

// ------------------------------------------------------- Mistral /v1/ocr

type MistralProbe = { status: number; ok: boolean; note: string; text: string };

async function probeMistralOcr(imageBase64: string, mime: string): Promise<MistralProbe> {
  const body = {
    model: "mistral-ocr-latest",
    document: { type: "image_url", image_url: `data:${mime};base64,${imageBase64}` },
  };
  let status = 0;
  let raw = "";
  try {
    const response = await fetch(`${MISTRAL_REST}/ocr`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${MISTRAL_KEY}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    });
    status = response.status;
    raw = await response.text();
  } catch (error) {
    return { status, ok: false, note: `threw: ${error}`, text: "" };
  }

  if (status < 200 || status >= 300) {
    const note = status === 401
      ? "unauthorised — the key cannot call /v1/ocr"
      : status === 402 || status === 429
      ? "refused for quota or credit — D1's $4 OCR budget needs checking in the console"
      : raw.replace(/\s+/g, " ").slice(0, 200);
    return { status, ok: false, note, text: "" };
  }

  let text = "";
  try {
    const json = JSON.parse(raw) as { pages?: { markdown?: string }[] };
    text = (json.pages ?? []).map((page) => page.markdown ?? "").join("\n").trim();
  } catch {
    return { status, ok: false, note: "200 with a body this tool could not parse", text: "" };
  }
  return { status, ok: true, note: "the free plan CAN call /v1/ocr", text };
}

// ----------------------------------------------------------- the report

const lines: string[] = [];
const say = (line = "") => {
  lines.push(line);
  console.log(line);
};

async function main(): Promise<void> {
  if (!GEMINI_KEY) throw new Error("GEMINI_API_KEY is not set. Put it in supabase/.env first.");

  let imageBase64 = PROBE_PNG_BASE64;
  let mime = "image/png";
  let imageNote = 'the built-in 260x140 PNG of the digits "123"';
  if (IMAGE_PATH) {
    const bytes = await Deno.readFile(IMAGE_PATH);
    imageBase64 = base64(bytes);
    mime = IMAGE_PATH.toLowerCase().endsWith(".png") ? "image/png" : "image/jpeg";
    imageNote = `${IMAGE_PATH} (${(bytes.length / 1024).toFixed(0)} KiB)`;
  }

  say("# F36-T03 · The reading chain's real inputs");
  say();
  say(`Run at ${new Date().toISOString()} · probe image: ${imageNote}`);
  say();

  const models = await listModels();
  const callable = models.filter((m) => m.supportedGenerationMethods?.includes("generateContent"));
  say(
    `## Models this key can see: ${models.length}, of which ${callable.length} do \`generateContent\``,
  );
  say();
  for (const model of callable) {
    const limit = model.inputTokenLimit ? `${(model.inputTokenLimit / 1000).toFixed(0)}k in` : "";
    say(`- \`${id(model)}\` — ${model.displayName ?? ""}${limit ? ` · ${limit}` : ""}`);
  }
  say();

  const candidates = readingCandidates(models);
  say("## The reading legs");
  say();
  if (NO_PROBE) {
    say("`--no-probe`: listing only. Candidates, in the order T07 would try them:");
    say();
    for (const model of candidates) say(`- \`${model}\``);
  } else {
    say(
      "Listing a model is not reaching it, so each candidate gets one real image " +
        "call. **This is reachability and permission, not reading quality** — " +
        "quality is T18's benchmark against the real corpus.",
    );
    say();
    const probes: Probe[] = [];
    for (const model of candidates) {
      const probe = await probeGemini(model, imageBase64, mime);
      probes.push(probe);
      if (probe.ok) {
        say(
          `- \`${model}\`${
            model.includes("latest") ? " *(alias — moves without warning)*" : ""
          } → **HTTP ${probe.status}** in ${(probe.elapsedMs / 1000).toFixed(1)} s · ` +
            `${probe.readDigits ? "**read the digits**" : "answered, digits NOT read"} · ` +
            `“${probe.text.replace(/\s+/g, " ").slice(0, 60)}”`,
        );
      } else {
        say(`- \`${model}\` → **HTTP ${probe.status || "no response"}** — ${probe.error}`);
      }
    }
    say();
    // A pinned id beats an alias for either leg, however fast the alias was.
    // Pinned ids before aliases, then newest first. NOT by the latency printed
    // above: one call per model is a reachability check, and the spread between
    // two runs of the SAME model (0.7 s then 1.4 s on 2026-11-09) was wider than
    // the spread between models. Which leg is primary is T18's to settle.
    const version = (modelId: string) => Number(/(\d+(?:\.\d+)?)/.exec(modelId)?.[1] ?? 0);
    const reached = probes.filter((p) => p.ok && p.readDigits)
      .sort((a, b) =>
        Number(a.model.includes("latest")) - Number(b.model.includes("latest")) ||
        // Flash-Lite first: F34 wants the cheap readers, which carry their own
        // free buckets, with the heavier Flash models as the backstop.
        Number(!a.model.includes("lite")) - Number(!b.model.includes("lite")) ||
        version(b.model) - version(a.model)
      )
      .map((p) => p.model);
    say(
      reached.length >= 2
        ? `**T07's two legs, verified: \`${reached[0]}\` and \`${reached[1]}\`.** ` +
          "Both reached this key and read the image, newest first. Which one is " +
          "PRIMARY is T18's benchmark to settle — one call each is reachability, " +
          "not a latency race."
        : reached.length === 1
        ? `**Only one model read the image: \`${reached[0]}\`.** T07 needs a second ` +
          "leg — widen `--probe-limit`, or the second leg becomes Mistral OCR."
        : "**No model read the image.** Something is wrong with the key or the " +
          "probe; T07 cannot be specified from this run.",
    );
  }
  say();

  say("## Mistral `/v1/ocr` — D1's evidence");
  say();
  if (!MISTRAL_KEY) {
    say("`MISTRAL_API_KEY` is not set here, so the OCR leg was not probed.");
  } else if (NO_PROBE) {
    say("`--no-probe`: skipped.");
  } else {
    const probe = await probeMistralOcr(imageBase64, mime);
    say(
      `\`POST /v1/ocr\` (\`mistral-ocr-latest\`) → **HTTP ${
        probe.status || "no response"
      }** — ${probe.note}`,
    );
    if (probe.ok) {
      say();
      say("```");
      say(probe.text.slice(0, 300) || "(no text in the answer)");
      say("```");
      say();
      say(
        "D1 is confirmed by a real call, not by the console's wording. The $4 OCR " +
          "budget is ~1,000 pages a month: a fallback for exhausted Gemini " +
          "buckets, never a second engine (T08's header says so).",
      );
    }
  }
  say();

  say("## The daily limits, which only you can read");
  say();
  say(
    "No API reports them. From <https://aistudio.google.com/app/apikey> → this key's **rate limits**:",
  );
  say();
  say("1. The tier name.");
  say("2. For **each** model named as a reading leg above: RPM, TPM and **RPD**.");
  say("3. Whether the two legs share one bucket or have one each — this is the");
  say("   number F34's \"500 + 500\" assumed, and T07's failover depends on it.");
  say();
  say("---");
  say();
  say(
    "Paste this block back; the numbers go into `docs/features/F36-server-explain-document.md` under T03.",
  );

  if (OUT_PATH) {
    await Deno.writeTextFile(OUT_PATH, lines.join("\n"));
    console.log(`\n(report also written to ${OUT_PATH})`);
  }
}

if (import.meta.main) {
  await main();
}
