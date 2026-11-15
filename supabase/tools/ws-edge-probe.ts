/**
 * F37-T01 · Question (e): can a Supabase Edge Function sustain a WebSocket?
 *
 * This is a standalone Deno script that:
 *   1. Deploys a tiny echo Edge Function to the LOCAL Supabase stack
 *      (or tests against a running one),
 *   2. Opens a WebSocket to it,
 *   3. Measures how long the connection stays alive and whether frames
 *      round-trip correctly.
 *
 * It does NOT test against production — the answer there may differ
 * (Deno Deploy's hosted runtime may impose a shorter idle timeout than
 * the local emulator). The report says so explicitly.
 *
 * HOWEVER: if the owner has staging deployed, pass --url=<staging_url>
 * to test against hosted Supabase instead.
 *
 *   deno run --allow-net --allow-env --env-file=supabase/.env supabase/tools/ws-edge-probe.ts
 *   deno run --allow-net --allow-env supabase/tools/ws-edge-probe.ts \
 *     --url=wss://<project>.supabase.co/functions/v1/ws-echo --key=<anon-key>
 *
 * If no --url is given it tries ws://127.0.0.1:54321/functions/v1/ws-echo
 * and prints clear instructions if the function is not running.
 *
 * The B1 relay needs the Edge Function to hold TWO sockets (phone + Gemini)
 * for ~12 s and pipe ~3.6 MB of audio through. This probe tests:
 *   - WebSocket upgrade succeeds
 *   - Binary frames round-trip (simulating PCM chunks)
 *   - The connection survives for 15 s with periodic frames
 *   - Total bytes transferred in that window
 *
 * Does not deploy or modify anything — the ws-echo function must already
 * exist and be served. See the README block below for how to create it.
 */

/*
 * ┌─ README: the ws-echo function ──────────────────────────────────────┐
 * │                                                                     │
 * │  mkdir -p supabase/functions/ws-echo                                │
 * │  # then put this in supabase/functions/ws-echo/index.ts:            │
 * │                                                                     │
 * │  Deno.serve((req) => {                                              │
 * │    if (req.headers.get("upgrade") !== "websocket") {                │
 * │      return new Response("upgrade required", { status: 426 });      │
 * │    }                                                                │
 * │    const { socket, response } = Deno.upgradeWebSocket(req);         │
 * │    socket.onmessage = (e) => socket.send(e.data);                   │
 * │    return response;                                                  │
 * │  });                                                                │
 * │                                                                     │
 * │  Then: supabase functions serve ws-echo                             │
 * └─────────────────────────────────────────────────────────────────────┘
 */

function flag(name: string, fallback = ""): string {
  const hit = Deno.args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

const URL_ARG = flag("url");
// The local dev anon key is a well-known constant from `supabase init`.
const LOCAL_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." +
  "eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9." +
  "CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
const KEY_ARG = flag("key") || Deno.env.get("SUPABASE_ANON_KEY") || "";
const DURATION_S = Math.max(5, Number(flag("duration", "15")) || 15);
const CHUNK_SIZE = 4800; // 100 ms of 24 kHz 16-bit mono PCM
const CHUNK_INTERVAL_MS = 100;

/** What one paper's read costs the relay: ~3.6 MB generated in ~12 s. */
const RELAY_AUDIO_MB = 3.6;
const RELAY_SESSION_S = 12;

const LOCAL_URL = "ws://127.0.0.1:54321/functions/v1/ws-echo";
const BASE_URL = URL_ARG || LOCAL_URL;
const IS_LOCAL = !URL_ARG || BASE_URL.includes("127.0.0.1") || BASE_URL.includes("localhost");

// Supabase Edge Runtime requires auth — WebSocket API can't send headers,
// so the anon key goes as a query parameter.
const EFFECTIVE_KEY = KEY_ARG || (IS_LOCAL ? LOCAL_ANON_KEY : "");
function buildTarget(base: string, key: string): string {
  if (!key) return base;
  const sep = base.includes("?") ? "&" : "?";
  return `${base}${sep}apikey=${encodeURIComponent(key)}`;
}
const TARGET = buildTarget(BASE_URL, EFFECTIVE_KEY);

async function main(): Promise<void> {
  const lines: string[] = [];
  const say = (line = "") => {
    lines.push(line);
    console.log(line);
  };

  say("# F37-T01(e) · Edge Function WebSocket probe");
  say();
  say(`Target: \`${BASE_URL}\``);
  say(
    `Auth: ${
      EFFECTIVE_KEY
        ? "apikey query param" + (KEY_ARG ? "" : " (local default)")
        : "**none** (pass --key=<anon-key> or set SUPABASE_ANON_KEY)"
    }`,
  );
  say(
    `Test duration: ${DURATION_S} s, chunk size: ${CHUNK_SIZE} bytes every ${CHUNK_INTERVAL_MS} ms`,
  );
  say(`Environment: ${IS_LOCAL ? "**local emulator**" : "**hosted Supabase**"}`);
  say();

  // --- attempt the upgrade
  say("## 1 · WebSocket upgrade");
  say();

  let socket: WebSocket;
  try {
    socket = new WebSocket(TARGET);
  } catch (err) {
    say(`**Failed to create WebSocket:** ${err}`);
    if (IS_LOCAL) {
      say();
      say("The local stack may not be running, or ws-echo is not served.");
      say("Run: `supabase functions serve ws-echo`");
    }
    return;
  }

  const opened = await new Promise<boolean>((resolve) => {
    const timer = setTimeout(() => {
      say("**Upgrade timed out** after 10 s.");
      resolve(false);
    }, 10_000);

    socket.onopen = () => {
      clearTimeout(timer);
      resolve(true);
    };

    socket.onerror = () => {
      clearTimeout(timer);
      say("**WebSocket error** during upgrade.");
      if (!EFFECTIVE_KEY) {
        say(
          "No API key provided — Supabase Edge Runtime rejects unauthenticated WebSocket upgrades.",
        );
        say("Re-run with `--key=<anon-key>` or set SUPABASE_ANON_KEY.");
      }
      if (IS_LOCAL) {
        say("Ensure `supabase functions serve ws-echo` is running.");
      }
      resolve(false);
    };
  });

  if (!opened) {
    say();
    say("## Verdict");
    say();
    say("**Cannot test** — upgrade did not succeed.");
    return;
  }

  say("**Upgrade succeeded.** Connection is open.");
  say();

  // --- stream binary frames for DURATION_S seconds
  say(`## 2 · Streaming ${DURATION_S} s of simulated PCM`);
  say();

  let sentBytes = 0;
  let receivedBytes = 0;
  let sentFrames = 0;
  let receivedFrames = 0;
  let lastReceivedAt = Date.now();
  let connectionLost = false;
  let closingDeliberately = false;
  let closeCode: number | null = null;
  let closeReason = "";

  socket.binaryType = "arraybuffer";

  socket.onmessage = (event) => {
    if (event.data instanceof ArrayBuffer) {
      receivedBytes += event.data.byteLength;
    } else if (typeof event.data === "string") {
      receivedBytes += event.data.length;
    }
    receivedFrames++;
    lastReceivedAt = Date.now();
  };

  socket.onclose = (event) => {
    closeCode = event.code;
    closeReason = event.reason ?? "";
    // Our own goodbye is not a loss — only an unsolicited close is.
    if (!closingDeliberately) connectionLost = true;
  };

  socket.onerror = () => {
    connectionLost = true;
  };

  const started = Date.now();
  const chunk = new Uint8Array(CHUNK_SIZE);
  // Fill with non-zero to be a realistic PCM stand-in
  for (let i = 0; i < chunk.length; i++) chunk[i] = i & 0xFF;

  while (Date.now() - started < DURATION_S * 1000 && !connectionLost) {
    try {
      socket.send(chunk);
      sentBytes += CHUNK_SIZE;
      sentFrames++;
    } catch {
      connectionLost = true;
      break;
    }
    await new Promise((r) => setTimeout(r, CHUNK_INTERVAL_MS));
  }

  const elapsed = Date.now() - started;

  // Give the echo a moment to catch up
  if (!connectionLost) {
    await new Promise((r) => setTimeout(r, 1000));
  }

  say(`- Duration held: **${(elapsed / 1000).toFixed(1)} s**`);
  say(`- Sent: ${sentFrames} frames, ${(sentBytes / 1024).toFixed(0)} KiB`);
  say(`- Received: ${receivedFrames} frames, ${(receivedBytes / 1024).toFixed(0)} KiB`);
  say(
    `- Connection lost mid-stream: ${
      connectionLost
        ? `**yes** (code ${closeCode}${closeReason ? `: ${closeReason}` : ""})`
        : "**no**"
    }`,
  );
  const pacedEchoPct = sentBytes > 0 ? receivedBytes / sentBytes * 100 : 0;
  say(
    `- Round-trip: ${
      receivedFrames > 0 ? `${pacedEchoPct.toFixed(0)}% of bytes echoed` : "**nothing came back**"
    }`,
  );
  say();

  // --- the paced phase above proves the socket survives; this one finds the
  //     ceiling, because B1 needs a whole paper's audio inside one session.
  let burstKBps = 0;
  if (!connectionLost) {
    say("## 2b · Burst: one paper's worth of audio, unpaced");
    say();

    const burstBytes = Math.round(RELAY_AUDIO_MB * 1024 * 1024);
    const burstChunks = Math.ceil(burstBytes / CHUNK_SIZE);
    const beforeBurst = receivedBytes;
    const burstStarted = Date.now();

    for (let i = 0; i < burstChunks && !connectionLost; i++) {
      try {
        socket.send(chunk);
      } catch {
        connectionLost = true;
        break;
      }
      // Yield whenever the send buffer runs ahead, so this measures the
      // socket's throughput rather than how fast a loop can queue bytes.
      if (socket.bufferedAmount > CHUNK_SIZE * 64) {
        await new Promise((r) => setTimeout(r, 5));
      }
    }

    const burstDeadline = Date.now() + 30_000;
    while (
      receivedBytes - beforeBurst < burstChunks * CHUNK_SIZE &&
      !connectionLost && Date.now() < burstDeadline
    ) {
      await new Promise((r) => setTimeout(r, 25));
    }

    const burstElapsed = Date.now() - burstStarted;
    const burstEchoed = receivedBytes - beforeBurst;
    burstKBps = (burstEchoed / 1024) / (burstElapsed / 1000);

    say(
      `- Pushed ${(burstChunks * CHUNK_SIZE / 1024 / 1024).toFixed(1)} MB in ${burstChunks} frames`,
    );
    say(
      `- Echoed back ${(burstEchoed / 1024 / 1024).toFixed(1)} MB in **${
        (burstElapsed / 1000).toFixed(1)
      } s**`,
    );
    say(`- Round-trip throughput: **${burstKBps.toFixed(0)} KiB/s**`);
    say(
      `- Connection survived the burst: ${
        connectionLost ? `**no** (code ${closeCode})` : "**yes**"
      }`,
    );
    say();
  }

  // Close cleanly
  if (!connectionLost) {
    closingDeliberately = true;
    try {
      socket.close(1000, "probe done");
    } catch { /* already closing */ }
    await new Promise((r) => setTimeout(r, 500));
  }

  // --- extrapolate to the relay use case
  say("## 3 · What this means for B1 (relay)");
  say();

  const neededKBps = (RELAY_AUDIO_MB * 1024) / RELAY_SESSION_S;

  if (connectionLost) {
    say(
      `**B1 is NOT viable here.** The connection dropped (code ${closeCode}) after ` +
        `${(elapsed / 1000).toFixed(1)} s of the ~${RELAY_SESSION_S} s a Gemini session needs.`,
    );
  } else if (receivedBytes === 0) {
    say(
      "**Inconclusive.** The connection stayed open but no frames were echoed — " +
        "check the echo function's `onmessage` handler.",
    );
  } else {
    say(
      `**B1 looks viable.** The socket held ${(elapsed / 1000).toFixed(1)} s of paced ` +
        `streaming and survived a ${RELAY_AUDIO_MB} MB burst.`,
    );
    say(
      `One paper needs ~${neededKBps.toFixed(0)} KiB/s sustained for ~${RELAY_SESSION_S} s; ` +
        `the burst round-tripped at **${burstKBps.toFixed(0)} KiB/s** — ` +
        `${burstKBps >= neededKBps ? "above" : "**below**"} that bar.`,
    );
    say();
    say(
      "Note this echo doubles every byte: a real relay moves each byte once " +
        "(Gemini → function → phone), so the usable headroom is roughly twice the " +
        "figure above.",
    );
  }

  say();
  say("## Verdict");
  say();

  if (!connectionLost && receivedBytes > 0) {
    say(
      "Edge Function WebSocket **works** on this environment. " +
        `Held ${(elapsed / 1000).toFixed(1)} s, echoed ${pacedEchoPct.toFixed(0)}% of data, ` +
        `burst throughput ${burstKBps.toFixed(0)} KiB/s.`,
    );
  } else if (connectionLost) {
    say(
      `Edge Function WebSocket **dropped** after ${(elapsed / 1000).toFixed(1)} s ` +
        `(code ${closeCode}).`,
    );
  } else {
    say(
      "Edge Function WebSocket **upgraded but did not echo** — check the function's onmessage handler.",
    );
  }

  if (IS_LOCAL) {
    say();
    say(
      "**Local only.** This does not prove hosted Supabase sustains the same — " +
        "test staging before committing to B1.",
    );
    say();
    say(
      "⚠️ `supabase functions serve` starts the runtime with `--policy=oneshot`, " +
        "which kills the worker the moment the handler returns and so breaks every " +
        "WebSocket regardless of the function's code. A local run only means " +
        "something against a runtime started with `--policy=per_worker`.",
    );
  }

  const out = flag("out");
  if (out) {
    await Deno.writeTextFile(out, lines.join("\n") + "\n");
    console.log(`\n(report also written to ${out})`);
  }
}

if (import.meta.main) {
  await main();
}
