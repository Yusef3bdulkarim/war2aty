/**
 * F36-T02 — the Gemini Live GATE spike.
 *
 * Run this on YOUR machine: the dev sandboxes cannot reach Google, and question
 * 3 can only be read off your own AI Studio page. It answers the three
 * questions F36-T02 asks, and prints a Markdown block to paste back:
 *
 *   1. Does Live read a given explanation VERBATIM? (it is a conversational
 *      model, not a TTS endpoint — if it paraphrases, F37's whole shape is
 *      wrong and the voice has to come from somewhere else.)
 *   2. Is Live reachable on the FREE tier at all — both the WebSocket session
 *      and `auth_tokens` (the ephemeral token the phone would use, so the API
 *      key never ships inside the app)?
 *   3. What is the quota? Printed as instructions, because Google does not
 *      publish Live limits and no endpoint reports them.
 *
 *   deno run --allow-net --allow-env --env-file=supabase/.env \
 *     supabase/tools/live-spike.ts
 *
 * Optional flags:
 *   --attempts=3        verbatim reads per model (default 3; each is one session)
 *   --model=<id>        skip discovery and use this model id
 *   --out=<path>        also write the report to a file (needs --allow-write)
 *   --language=ar-XA    speech language code (default ar-XA; retries without it)
 *
 * Prints no key and no token. The read-aloud text below is invented, so nothing
 * from a real paper is ever sent.
 */

const KEY = Deno.env.get("GEMINI_API_KEY")?.trim();

const REST = "https://generativelanguage.googleapis.com";
const WS = "wss://generativelanguage.googleapis.com/ws";

/** The §33 school-letter example, as the result screen would hand it to the voice. */
const SOURCE_TEXT = [
  "دي ورقة من مدرسة النور لولي أمر الطالب أحمد محمود في الصف الرابع.",
  "المدرسة بتعزمك على اجتماع أولياء الأمور عشان يكلموك عن مستوى أحمد في نص السنة.",
  "روح الاجتماع بنفسك، وخد معاك بطاقتك الشخصية وكراسة الواجب بتاعة أحمد.",
  "الاجتماع يوم 20 نوفمبر الساعة 10 الصبح.",
  "لو مش هتقدر تروح، لازم تبلّغ المدرسة قبل الميعاد.",
].join(" ");

const READ_INSTRUCTION =
  "اقرأ النص التالي بالحرف، كلمة بكلمة، من غير أي إضافة أو تعليق أو ترحيب، " +
  "ومن غير ما تغيّر أي كلمة أو رقم أو تاريخ. متقولش حاجة غير النص نفسه.";

// ---------------------------------------------------------------- CLI

function flag(name: string, fallback = ""): string {
  const hit = Deno.args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

const ATTEMPTS = Math.max(1, Number(flag("attempts", "3")) || 3);
const FORCED_MODEL = flag("model");
const OUT_PATH = flag("out");
const LANGUAGE_CODE = flag("language", "ar-XA");

// ---------------------------------------------------------- Arabic text

/** Folds away everything a transcriber may legitimately render differently. */
export function normalise(text: string): string {
  return text
    .replace(/[ً-ْٰـ]/g, "") // diacritics + tatweel
    .replace(/[آأإا]/g, "ا")
    .replace(/[ىي]/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06F0))
    .replace(/[^\p{Letter}\p{Number}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function words(text: string): string[] {
  const folded = normalise(text);
  return folded.length === 0 ? [] : folded.split(" ");
}

export type Diff = { wer: number; dropped: string[]; added: string[] };

/** Word-level LCS. The lists are a few dozen words, so the square is free. */
export function diffWords(source: string[], heard: string[]): Diff {
  const rows = source.length;
  const cols = heard.length;
  const lcs: number[][] = Array.from({ length: rows + 1 }, () => new Array(cols + 1).fill(0));
  for (let i = rows - 1; i >= 0; i--) {
    for (let j = cols - 1; j >= 0; j--) {
      lcs[i][j] = source[i] === heard[j]
        ? lcs[i + 1][j + 1] + 1
        : Math.max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }
  const dropped: string[] = [];
  const added: string[] = [];
  let i = 0;
  let j = 0;
  while (i < rows && j < cols) {
    if (source[i] === heard[j]) {
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      dropped.push(source[i++]);
    } else {
      added.push(heard[j++]);
    }
  }
  while (i < rows) dropped.push(source[i++]);
  while (j < cols) added.push(heard[j++]);
  const wer = rows === 0 ? 1 : (dropped.length + added.length) / rows;
  return { wer, dropped, added };
}

// -------------------------------------------------------------- helpers

function hhmmss(ms: number): string {
  return `${(ms / 1000).toFixed(1)} s`;
}

async function readFrame(data: unknown): Promise<string> {
  if (typeof data === "string") return data;
  if (data instanceof Blob) return await data.text();
  if (data instanceof ArrayBuffer) return new TextDecoder().decode(data);
  if (data instanceof Uint8Array) return new TextDecoder().decode(data);
  return String(data);
}

// ------------------------------------------------- 1 · model discovery

type Model = { name: string; displayName?: string; supportedGenerationMethods?: string[] };

async function discoverLiveModels(): Promise<{ models: Model[]; note: string }> {
  const response = await fetch(`${REST}/v1beta/models?pageSize=1000`, {
    headers: { "x-goog-api-key": KEY! },
  });
  if (!response.ok) {
    return { models: [], note: `ListModels answered HTTP ${response.status}.` };
  }
  const body = await response.json() as { models?: Model[] };
  const live = (body.models ?? []).filter((m) =>
    m.supportedGenerationMethods?.includes("bidiGenerateContent")
  );
  return {
    models: live,
    note: `${
      (body.models ?? []).length
    } models visible, ${live.length} support bidiGenerateContent.`,
  };
}

function pickModel(models: Model[]): string | null {
  if (FORCED_MODEL) return FORCED_MODEL.replace(/^models\//, "");
  const ids = models.map((m) => m.name.replace(/^models\//, ""));
  return ids.find((id) => id.includes("native-audio")) ??
    ids.find((id) => id.includes("live")) ??
    ids[0] ??
    null;
}

// ------------------------------------------------- 2 · ephemeral tokens

type TokenProbe = {
  version: string;
  status: number;
  ok: boolean;
  token: string | null;
  body: string;
};

async function mintToken(version: string, model: string): Promise<TokenProbe> {
  const now = Date.now();
  const payload = {
    uses: 1,
    expireTime: new Date(now + 30 * 60_000).toISOString(),
    newSessionExpireTime: new Date(now + 2 * 60_000).toISOString(),
    liveConnectConstraints: {
      model: `models/${model}`,
      config: { responseModalities: ["AUDIO"], temperature: 0 },
    },
  };
  let status = 0;
  let text = "";
  try {
    const response = await fetch(`${REST}/${version}/auth_tokens`, {
      method: "POST",
      headers: { "x-goog-api-key": KEY!, "content-type": "application/json" },
      body: JSON.stringify(payload),
    });
    status = response.status;
    text = await response.text();
  } catch (error) {
    return { version, status, ok: false, token: null, body: `threw: ${error}` };
  }
  let token: string | null = null;
  try {
    token = (JSON.parse(text) as { name?: string }).name ?? null;
  } catch { /* keep the raw body for the report */ }
  return {
    version,
    status,
    ok: status >= 200 && status < 300 && token !== null,
    token,
    // Never print the token itself: its own name IS the credential.
    body: token ? "(a token came back; its value is not printed)" : text.slice(0, 400),
  };
}

// --------------------------------------------------- 3 · one Live read

type Read = {
  ok: boolean;
  via: "api-key" | "ephemeral-token";
  model: string;
  elapsedMs: number;
  audioBytes: number;
  transcript: string;
  diff: Diff | null;
  error: string | null;
  usedLanguageCode: boolean;
};

function wsUrl(auth: { kind: "api-key" } | { kind: "ephemeral-token"; token: string }): string {
  const base = `${WS}/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent`;
  return auth.kind === "api-key"
    ? `${base}?key=${encodeURIComponent(KEY!)}`
    : `${base}?access_token=${encodeURIComponent(auth.token)}`;
}

function readAloud(
  model: string,
  auth: { kind: "api-key" } | { kind: "ephemeral-token"; token: string },
  withLanguageCode: boolean,
): Promise<Read> {
  const started = Date.now();
  const result: Read = {
    ok: false,
    via: auth.kind,
    model,
    elapsedMs: 0,
    audioBytes: 0,
    transcript: "",
    diff: null,
    error: null,
    usedLanguageCode: withLanguageCode,
  };

  return new Promise<Read>((resolve) => {
    let settled = false;
    const socket = new WebSocket(wsUrl(auth));

    const finish = (error: string | null) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      result.elapsedMs = Date.now() - started;
      result.error = error;
      // Audio with no transcript means the session worked but this model does not
      // echo `outputAudioTranscription` — verbatim cannot be judged without an STT.
      if (error === null && result.transcript.trim().length === 0) {
        result.error = result.audioBytes > 0
          ? "spoke audio but returned no outputAudioTranscription — cannot judge verbatim here"
          : "the turn completed with neither audio nor transcription";
      }
      result.ok = result.error === null && result.transcript.trim().length > 0;
      if (result.transcript.trim().length > 0) {
        result.diff = diffWords(words(SOURCE_TEXT), words(result.transcript));
      }
      try {
        socket.close();
      } catch { /* already closing */ }
      resolve(result);
    };

    const timer = setTimeout(() => finish("timed out after 90 s"), 90_000);

    socket.onopen = () => {
      const setup: Record<string, unknown> = {
        model: `models/${model}`,
        generationConfig: { responseModalities: ["AUDIO"], temperature: 0 },
        systemInstruction: { parts: [{ text: READ_INSTRUCTION }] },
        outputAudioTranscription: {},
      };
      if (withLanguageCode) setup.speechConfig = { languageCode: LANGUAGE_CODE };
      socket.send(JSON.stringify({ setup }));
    };

    socket.onmessage = async (event) => {
      let frame: Record<string, unknown>;
      try {
        frame = JSON.parse(await readFrame(event.data));
      } catch {
        return; // a non-JSON frame is not something this spike needs
      }

      if (frame.setupComplete) {
        socket.send(JSON.stringify({
          clientContent: {
            turns: [{ role: "user", parts: [{ text: SOURCE_TEXT }] }],
            turnComplete: true,
          },
        }));
        return;
      }

      const server = frame.serverContent as Record<string, unknown> | undefined;
      if (server) {
        const transcription = server.outputTranscription as { text?: string } | undefined;
        if (transcription?.text) result.transcript += transcription.text;

        const turn = server.modelTurn as
          | { parts?: { inlineData?: { data?: string } }[] }
          | undefined;
        for (const part of turn?.parts ?? []) {
          const data = part.inlineData?.data;
          if (data) result.audioBytes += Math.floor(data.length * 0.75);
        }
        if (server.turnComplete || server.generationComplete) finish(null);
        return;
      }

      if (frame.error) finish(`server error frame: ${JSON.stringify(frame.error).slice(0, 300)}`);
    };

    socket.onerror = () => finish("websocket error (see the close code below it)");
    socket.onclose = (event) => {
      const reason = (event.reason ?? "").slice(0, 300);
      finish(settled ? null : `closed ${event.code}${reason ? `: ${reason}` : ""}`);
    };
  });
}

// ----------------------------------------------------------- the report

async function main(): Promise<void> {
  if (!KEY) throw new Error("GEMINI_API_KEY is not set. Put it in supabase/.env first.");

  const lines: string[] = [];
  const say = (line = "") => {
    lines.push(line);
    console.log(line);
  };

  say("# F36-T02 · Gemini Live spike — raw run");
  say();
  say(`Run at ${new Date().toISOString()} · attempts per model: ${ATTEMPTS}`);
  say();

  // --- question 2a: which models even offer a Live session
  const discovery = await discoverLiveModels();
  say("## Models offering `bidiGenerateContent`");
  say();
  say(discovery.note);
  say();
  if (discovery.models.length === 0) {
    say("**None.** Either this key has no Live access, or ListModels did not answer.");
  } else {
    for (const model of discovery.models) {
      say(`- \`${model.name.replace(/^models\//, "")}\` — ${model.displayName ?? ""}`);
    }
  }
  say();

  const model = pickModel(discovery.models);
  if (!model) {
    say("Nothing to spike: no Live model id. Answer to question 2 is **no** on this key.");
    if (OUT_PATH) await Deno.writeTextFile(OUT_PATH, lines.join("\n"));
    Deno.exit(1);
  }
  say(`Spiking **\`${model}\`**${FORCED_MODEL ? " (forced by --model)" : ""}.`);
  say();

  // --- question 2b: ephemeral tokens, the path the phone would use
  say("## 2 · Ephemeral tokens (`auth_tokens`)");
  say();
  const probes: TokenProbe[] = [];
  for (const version of ["v1alpha", "v1beta"]) {
    const probe = await mintToken(version, model);
    probes.push(probe);
    say(
      `- \`POST /${version}/auth_tokens\` → **HTTP ${
        probe.status || "no response"
      }** — ${probe.body}`,
    );
  }
  say();
  const minted = probes.find((p) => p.ok) ?? null;
  say(
    minted
      ? `Tokens work on **${minted.version}**. The phone can hold a short-lived token instead of the key.`
      : "**No token minted.** F37 would need a server relay, or the key on the device — which is not an option.",
  );
  say();

  // --- question 1: verbatim, over the key and then over a token
  say("## 1 · Does it read verbatim?");
  say();
  say(
    "The transcript below is Live's own `outputAudioTranscription` — a machine " +
      "listening to its own speech — so a small word error rate may be the " +
      "transcriber's, not the reader's. Read the dropped/added words before judging.",
  );
  say();

  const reads: Read[] = [];
  let withLanguageCode = true;
  for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
    let read = await readAloud(model, { kind: "api-key" }, withLanguageCode);
    if (
      !read.ok && withLanguageCode &&
      /language|speech_config|speechConfig|invalid/i.test(read.error ?? "")
    ) {
      say(`> attempt ${attempt}: retrying without \`speechConfig.languageCode\` (${read.error}).`);
      withLanguageCode = false;
      read = await readAloud(model, { kind: "api-key" }, false);
    }
    reads.push(read);
    say(`### Attempt ${attempt} — via API key`);
    say();
    if (!read.ok) {
      say(`**Failed** after ${hhmmss(read.elapsedMs)}: ${read.error}`);
    } else {
      const diff = read.diff!;
      say(`- took ${hhmmss(read.elapsedMs)}, ~${(read.audioBytes / 1024).toFixed(0)} KiB of audio`);
      say(`- word error rate **${(diff.wer * 100).toFixed(1)}%**`);
      say(`- dropped: ${diff.dropped.length === 0 ? "none" : diff.dropped.join(" · ")}`);
      say(`- added: ${diff.added.length === 0 ? "none" : diff.added.join(" · ")}`);
      say();
      say("```");
      say(read.transcript.trim());
      say("```");
    }
    say();
  }

  if (minted?.token) {
    const read = await readAloud(
      model,
      { kind: "ephemeral-token", token: minted.token },
      withLanguageCode,
    );
    reads.push(read);
    say("### Same read, but authenticated with the ephemeral token");
    say();
    say(
      read.ok
        ? `Worked in ${hhmmss(read.elapsedMs)}, WER ${
          (read.diff!.wer * 100).toFixed(1)
        }% — the client path is real.`
        : `**Failed**: ${read.error}`,
    );
    say();
  }

  // --- the verdict on question 1
  const good = reads.filter((r) => r.ok);
  const best = good.length === 0 ? null : Math.min(...good.map((r) => r.diff!.wer));
  say("### Verdict");
  say();
  if (good.length === 0) {
    say(
      "**No successful read.** Question 1 is unanswered and question 2 is a no — see the errors above.",
    );
  } else if (best! <= 0.05) {
    say(`**Verbatim** (best WER ${(best! * 100).toFixed(1)}%). F37 can proceed as designed.`);
  } else if (best! <= 0.15) {
    say(
      `**Near-verbatim** (best WER ${(best! * 100).toFixed(1)}%). Read the dropped/added words: ` +
        "if they are transcription noise it passes, if they are the model's own additions it does not.",
    );
  } else {
    say(
      `**Not verbatim** (best WER ${(best! * 100).toFixed(1)}%). It is paraphrasing or chatting. ` +
        "F37's shape has to be renegotiated before any client code.",
    );
  }
  say();

  // --- question 3: the quota, which only you can read
  say("## 3 · Quota");
  say();
  say("No endpoint reports Live limits, so this part is manual:");
  say();
  say("1. Open <https://aistudio.google.com/app/apikey> and click this key's **rate limits**.");
  say(`2. Find the row for \`${model}\` and write down **RPM, TPM and RPD**, plus the tier name.`);
  say("3. Note whether the row mentions sessions or concurrent connections at all.");
  say();
  const rateLimited = reads.filter((r) => /429|RESOURCE_EXHAUSTED|quota/i.test(r.error ?? ""));
  say(
    rateLimited.length === 0
      ? `Observed here: ${reads.length} session(s), no rate-limit error.`
      : `Observed here: ${rateLimited.length} of ${reads.length} session(s) hit a rate limit — ${
        rateLimited[0].error
      }`,
  );
  say();
  say("---");
  say();
  say("Paste this whole block back; it becomes `docs/features/F36-live-spike.md`.");

  if (OUT_PATH) {
    await Deno.writeTextFile(OUT_PATH, lines.join("\n"));
    console.log(`\n(report also written to ${OUT_PATH})`);
  }
}

if (import.meta.main) {
  await main();
}
