# F37-T01(e) · Edge Function WebSocket probe

Target: `ws://127.0.0.1:54330/ws-echo`
Auth: apikey query param (local default)
Test duration: 15 s, chunk size: 4800 bytes every 100 ms
Environment: **local emulator**

## 1 · WebSocket upgrade

**Upgrade succeeded.** Connection is open.

## 2 · Streaming 15 s of simulated PCM

- Duration held: **15.1 s**
- Sent: 139 frames, 652 KiB
- Received: 139 frames, 652 KiB
- Connection lost mid-stream: **no**
- Round-trip: 100% of bytes echoed

## 2b · Burst: one paper's worth of audio, unpaced

- Pushed 3.6 MB in 787 frames
- Echoed back 3.6 MB in **0.4 s**
- Round-trip throughput: **9632 KiB/s**
- Connection survived the burst: **yes**

## 3 · What this means for B1 (relay)

**B1 looks viable.** The socket held 15.1 s of paced streaming and survived a 3.6 MB burst.
One paper needs ~307 KiB/s sustained for ~12 s; the burst round-tripped at **9632 KiB/s** — above that bar.

Note this echo doubles every byte: a real relay moves each byte once (Gemini → function → phone), so the usable headroom is roughly twice the figure above.

## Verdict

Edge Function WebSocket **works** on this environment. Held 15.1 s, echoed 100% of data, burst throughput 9632 KiB/s.

**Local only.** This does not prove hosted Supabase sustains the same — test staging before committing to B1.

⚠️ `supabase functions serve` starts the runtime with `--policy=oneshot`, which kills the worker the moment the handler returns and so breaks every WebSocket regardless of the function's code. A local run only means something against a runtime started with `--policy=per_worker`.
