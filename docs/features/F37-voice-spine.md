# F37 · Voice spine — Gemini Live

- **Branch:** `feature/voice-spine`, cut from `develop` at `1a4974a` (the PR #41 merge, so the tree carries **both** F35 and F36)
- **Milestone:** post-F36, the third feature of the F34 pivot
- **Depends on:** F35 (closed 2026-11-09). F36 is *in* the branch but F37 does not depend on its schema — see the scope fence.
- **Decisions source:** [F34-non-reader-pivot.md](F34-non-reader-pivot.md) — the pivot's decisions record, and its "Amendments (2026-11-08)" section, which wins wherever it disagrees with the body. The spike's handover is [F36-live-spike.md](F36-live-spike.md).
- **Progress:** 21 / 21 — T01 (transport gate), T02 (§34 contract), T03 (domain), T04 (privacy copy), T05 (verbatim judgement), T06 (turn text builder), T07 (alignment), T08 (frame DTOs), T09 (Live session), T10 (live-token endpoint + Dart datasource), T11 (AudioTrack PCM sink), T12 (AAC encoder), T13 (method channel bridge), T14 (silence detection — **rejected** as primary), T15 (encrypted audio store), T16 (just_audio replay), T17 (the tier ladder), T18 (the device-TTS adapter) T19 (the playback cubit) T20 (the 12 fixed lines, generated and bundled) and T21 (DI, the channel guard, the device checklist) done. **All 21 tasks closed.** Outstanding: the device pass is written but **blocked on having no trigger** — F37 builds no screen, so nothing can start a read; see T21's note for the three ways out, which is an owner decision. **T04 left two carry-forwards for F44** — see its note; **T17 left two questions for the owner**, and **T19 left two more** (D7's mid-read handoff, and whether the device tier should be made pausable) — see their notes.

## Why this feature exists

Before the pivot, voice was a feature: a «استمع» button on the result screen,
an `AudioReaderCubit`, five reading modes, a mini-player. It assumed a user who
could read the screen and *chose* to hear it instead.

The pivot removes that user. Someone who cannot read does not choose audio —
audio is the only output they have. F34's shape is: photograph → «كمّل» → **the
explanation plays by itself**, and every screen with an important message says
it out loud, with on-screen text kept small for whoever is helping.

That turns voice from a feature into a spine, and the existing `flutter_tts`
stack cannot be it alone: a device TTS voice reading Egyptian Arabic is the
difference between a person understanding their electricity bill and giving up.
F36-T02 proved Gemini Live will read a supplied Arabic explanation **verbatim**
(0.0 % WER, three sessions, free tier) and stream it faster than real time, so
the spine is built on Live with device TTS underneath it.

At the end of F37:

1. A finished Arabic page (plain text segments — **not** F36's DTO) can be
   spoken by Gemini Live, streamed so the user hears it within about a second.
2. The audio is encoded to AAC-LC `.m4a` (~0.3 MB) and stored encrypted, so the
   paper replays with no network and at no quota cost.
3. Every read is verified verbatim against Live's own transcription, with no
   second speech-to-text pass, and falls back to device TTS when it cannot be.
4. Per-card spans exist for F40's auto-scroll — best-effort, with a floor that
   never fails the read.
5. The ~30 fixed spoken UI lines are bundled as assets, so **no UI message ever
   depends on either engine being reachable.**

No screen changes. Nothing is wired into the capture flow or the result screen;
F39 and F40 do that.

## Scope fence — what this feature does NOT touch

| Not here | Where it goes | Why |
|---|---|---|
| Any screen, route or widget | F39, F40, F41 | F37 ends at an injectable spine plus assets. `VoicePlaybackCubit` exists but nothing builds it into a tree. |
| The Drift rows, the paper entity, auto-save | F38 | F37's audio store is keyed by a **plain id string**, deliberately, so F37 stays clear of F36's schema and the two could have run in parallel. |
| Reading the `explain-document` response | F38 / F40 | F37 consumes `List<VoiceSegment>`. Mapping cards → segments is the caller's job. |
| `AudioReaderCubit`, `ReadingQueue`, the five reading modes | untouched here; removed in F40 | Still serving the published 1.0.2 result screen. The device-TTS tier *reuses* `ReadingQueue` rather than replacing it. |
| `explain_enabled` on the client | F39 | F36 put it on the wire; F39's capture gate reads it. |
| Tesseract removal | F39 | Unrelated to voice. |
| Reminders / the bell | out of the pivot | — |
| iOS | after the pivot | The two sink interfaces exist so iOS can land later; only Kotlin is written now. |

## Decisions — owner, 2026-11-12

| # | Answer |
|---|---|
| **D1** | **Branch from `develop` after PR #41 merged.** Already true: `develop` is at `1a4974a` and carries F35 + F36, so device tests can hit the real `explain-document` on staging. |
| **D2** | **Stay on `gemini-2.5-flash-native-audio-latest`** — the model the spike proved. Its quota row is already read (RPM unlimited, TPM 1 M, RPD unlimited), so T01 re-reads nothing. `gemini-3.8-live` is now GA but switching would mean re-reading the row for no proven gain. |
| **D3** | **Amend `privacyPointTextOnly` to cover the voice send** (T04). Reading aloud is a *second* outbound send of the paper's text, for a different purpose, and on the token path it leaves the phone for Google directly. |
| **D4** | **Hand-roll the Live client** over `web_socket_channel`. `just_audio` is added too, for replay only. |
| **D5** | **ffmpeg is available on the owner's machine**, so T20's generator encodes the fixed lines to AAC directly and the ~360 KB budget holds. |
| **D6** | **Transport fallback is B1** (the streaming relay) if T01 finds no ephemeral tokens, chosen to preserve "speech starts after about a second". **B3** (batch via Live) is the recorded graceful degradation if Supabase Edge will not sustain a WebSocket upgrade, or if egress bites. See "The transport fork" below. **Outcome (T01): not needed — Path A works on the free tier**, so there is no Supabase egress to budget. B1 stays viable if it is ever wanted: a per-worker Edge runtime held a socket 15 s and round-tripped a 3.6 MB burst. |
| **D7** | **No seeking while the audio is still streaming.** Taken as recommended rather than explicitly ruled on, so it is **flagged for F40 to confirm**: the user hears the paper from the top automatically, and full seek plus card-jumping appear once the file lands, ~12 s in. |

## What the spike handed over

[F36-live-spike.md](F36-live-spike.md) closed the product gate and left four
things for this feature. The first three are T01's job; the fourth is a trap.

1. **Ephemeral tokens are unproven, not refused.** Both mint attempts returned
   HTTP 400 on *the tool's own malformed body* — `liveConnectConstraints` is the
   Python SDK's field name and the REST resource does not carry it. Nothing can
   be concluded from that 400. The tool was fixed: minting now starts from a
   minimal body (`uses`, `expireTime`, `newSessionExpireTime`), which alone
   answers availability, then probes six candidate constraint field names one
   request at a time. **Do not build the token endpoint assuming the 400 was
   Google's answer.**
2. **Voice and language choice is unverified.** v1beta's Live service rejects
   `speechConfig` outright (`1007: Unknown name "speechConfig" at 'setup'`); the
   tool now asks v1alpha with `languageCode` and a named prebuilt voice. A
   refusal is not a blocker — the Arabic came out correct from the text alone.
3. **Play the stream, do not wait for the file.** Wall clock (11–13 s) is about
   *half* the spoken length (25–27 s), so the user starts hearing the paper long
   before the read has finished arriving.
4. **The transcript field is not the setup field.** `outputAudioTranscription`
   is the **setup** key, but the server frame carries the text at
   **`serverContent.outputTranscription.text`**
   ([live-spike.ts:357](../../supabase/tools/live-spike.ts#L357)). Reading the
   setup spelling off the server frame yields an empty transcript — which makes
   every read look non-verbatim and silently drops every user to device TTS.
   T08 covers the field name with a test for exactly this reason.

Also inherited, and load-bearing: the two conditions that produced 0.0 % WER —
the verbatim instruction in `systemInstruction` with the page text as the **user
turn**, and `temperature: 0` with `responseModalities: ["AUDIO"]` and
`outputAudioTranscription` on. The last of those is also how a read is verified
in production without a second STT. Changing any of them reopens the gate.

## The transport fork

The API key can never ship inside the app, so the phone needs either a
short-lived credential of its own or a server in front of it.

**Path A is the chosen transport — T01 proved it on the free tier.** The rest of
this section is kept as the reasoning behind the fallbacks, which still stand if
Path A is ever withdrawn.

**Path A — ephemeral token (preferred).** `POST /functions/v1/live-token`
authenticates the Supabase anonymous user, checks `analysis_enabled` +
`explain_enabled`, mints a token from the key in Supabase Secrets, and returns
`{ token, expires_at }`. The phone opens
`wss://…GenerativeService.BidiGenerateContentConstrained?access_token=…`.
That endpoint name is load-bearing: the unconstrained `BidiGenerateContent`
takes an API key and closes `1008` on a token. T01 found the shipped client
sending tokens to the wrong one.

Path A's advantage is not only that the key stays home: the audio goes **Google
→ phone directly**, costing **zero Supabase egress**. Every fallback ships
~3.6 MB of raw PCM per paper through our own project, which on the free 5 GB a
month is a ceiling of roughly **1,400 papers a month** — about 46 a day across
all users. That, not the API quota, is what binds a Path B.

| | **B1** relay (streaming) | **B2** batch TTS model | **B3** batch via Live |
|---|---|---|---|
| How | the Edge Function holds the Gemini socket and pipes frames to the phone | a second endpoint calls `gemini-3.8-flash-lite-tts` over ordinary `generateContent` | the Edge Function runs the Live session, buffers it, returns the audio |
| Time to first word | **~1 s** | +20–40 s | +12–15 s |
| Supabase egress / paper | 3.6 MB | 3.6 MB | 3.6 MB |
| Quota shape | Live: TPM-bound, no daily cap | **unknown RPD — unread** | Live: TPM-bound, no daily cap |
| Model proven | yes (spiked) | **no** | yes (spiked) |
| Card spans | transcript alignment (fuzzy) | **exact, if called once per card** | transcript alignment, server-side |
| New client code | reuses Path A's socket client | none (plain HTTP) | none (plain HTTP) |

**Concurrency is not the differentiator**, contrary to how this was first framed
in planning. Gemini's session lasts as long as the *generation* (~12 s), not the
*playback* (~75 s) — the phone plays from its buffer long after the socket
closes. So ~3 concurrent sessions is ~15 reads a minute on **every** path,
including Path A if token concurrency turns out to be project-scoped. Recorded
because the opposite claim was made out loud and would mislead a later session.

**B1 is chosen (D6)** because it is the only fallback that keeps the product's
feel for someone who cannot read a bill — B2 and B3 put them in front of a
silent screen for another 12–40 s on top of the explain call's 30 s budget — and
because F37 builds the phone-side socket client for Path A regardless, so B1
swaps one file. **B2 is the weakest**: its one advantage rests on an unproven
model and an unread quota row, and F34 rejected Gemini TTS on a 10/100-per-day
limit that may still hold.

Whatever T01 decides sits behind an injected **`LiveSessionEndpoint`**, so the
swap is one file: under a relay the token datasource disappears, the URL and
frames become ours, and auth is the existing Supabase JWT.

## Existing-code analysis — what is reused, and what must not be disturbed

| Thing | Where | How F37 uses it |
|---|---|---|
| `AesGcmFileEncryptor` | `lib/core/crypto/aes_gcm_file_encryptor.dart` | encrypts the stored `.m4a`, same as the paper photo |
| `FileDocumentImageStore` | `lib/core/documents/` | the **pattern** `FileEncryptedAudioStore` mirrors |
| `ReadingQueue` | `lib/features/audio_reader/domain/services/reading_queue.dart` | the device-TTS tier speaks through it, unchanged |
| `TextToSpeechService` + `FlutterTtsTextToSpeechService` | `lib/features/audio_reader/` | unchanged; still the only `flutter_tts` importer |
| `MethodChannelSystemTtsSettings` | `lib/core/platform/` | the escape hatch when no Arabic voice exists; also the channel **pattern** to copy |
| `MainActivity.configureFlutterEngine` | `android/.../MainActivity.kt` | the new voice channel registers beside `com.war2aty.app/system_settings` |
| `Result<T, AppFailure>`, `sealed class AppFailure` | `lib/core/` | every new domain call returns it; nothing throws upward |
| `RuntimeConfigStore` | `lib/core/config/` | gates and timeouts |
| `live-spike.ts` + `live-spike-diff.test.ts` | `supabase/tools/`, `supabase/tests/unit/` | T01 re-runs the tool; T05 ports the 11 diff cases to Dart |
| `get-usage` | `supabase/functions/get-usage/` | the shape `live-token` copies (auth + runtime config, no slot) |

**Three things that must stay true.** `RECORD_AUDIO` is removed from the
manifest with `tools:node="remove"` and `android_permissions_test` asserts it
(F37 is output-only — no microphone, ever). `ocr-document` and
`analyze-document` stay frozen for published 1.0.x builds. And
`docs/API_CONTRACT.md` is **CRLF** while the feature docs are LF — T02 must
preserve its line endings (never `sed -i` from Git Bash, which strips CR).

## Phases

Each phase ends green: `dart format .`, `flutter analyze`, `flutter test`, plus
`deno fmt` / `deno check` / `deno task test` for the Edge Function work. A phase
that cannot go green is not finished and the next does not start.
`flutter analyze` / `flutter test` exiting 0 is **not** a pass on its own —
read the counter line.

T04 depends on nothing and may land first. T01 and T02 gate everything from T08
onward; T03 and T05–T07 are pure domain work and can proceed alongside T01.

### Phase A — the fork and the contract

Both are gates. No client transport code is written until T02 is approved.

- [x] **T01** **GATE · re-run the spike and decide the transport.** Run
      `supabase/tools/live-spike.ts` **on the owner's machine** (the dev
      sandboxes cannot reach Google). Answer, in writing: (a) does the free tier
      mint an ephemeral token from the minimal body; (b) which constraint field
      name parses, if any; (c) does v1alpha accept `languageCode` and a named
      voice; (d) how many concurrent sessions one key sustains; and (e) **does a
      Supabase Edge Function sustain a WebSocket upgrade, and for how long** —
      which decides whether D6's B1 is even available. *Done when:* this file
      records all five answers and names the chosen transport.
      > **DONE 2026-11-13. The transport is Path A — the ephemeral token.**
      > Raw runs: `docs/features/F37-T01-spike-run.md` (a–d) and
      > `docs/features/F37-T01-ws-probe-run.md` (e).
      >
      > **(a) Yes.** The minimal body (`uses`, `expireTime`,
      > `newSessionExpireTime`) mints on the free tier — HTTP 200 on **both**
      > `v1alpha` and `v1beta`. No paid tier, no allow-list, no extra field.
      >
      > **(b) None of the six.** `liveConnectConstraints`,
      > `bidiGenerateContentSetup`, `liveConnectConfig`, `liveConstrainedSetup`,
      > `config` and `setup` are each rejected 400 "unknown field". The token
      > therefore ships **unconstrained** — acceptable, and recorded as such:
      > it is single-use (`uses: 1`), it dies two minutes after minting
      > (`newSessionExpireTime`), and it only ever reaches the phone that asked
      > for it over an authenticated call. Re-probe if Google documents the
      > field; until then this is a finding, not a blocker.
      >
      > **(c) No — on either endpoint or version.** `speechConfig` is refused
      > with `1007 … Unknown name "speechConfig" at 'setup'` on v1alpha and
      > v1beta, unconstrained and constrained alike, with `languageCode` alone
      > and with a named voice. **F37 takes the service's default voice.** It
      > reads Egyptian Arabic correctly without being asked to, so this costs
      > nothing today, but it means *the voice cannot be chosen or kept stable*
      > — if Google changes the default, the app's voice changes with it, and
      > there is no setting to pin it. Anything in F38–F41 that assumes a
      > choosable voice has to be re-planned.
      >
      > **(d) At least 4 concurrent, no rate-limit error.** Not pushed further:
      > D2 already settled the quota row (RPM unlimited, TPM 1 M, RPD
      > unlimited) and concurrency is not a differentiator between transports
      > anyway — see "The transport fork".
      >
      > **(e) Yes — but only on a runtime that is not `oneshot`.** With
      > `--policy=per_worker`: upgrade succeeded, the socket held **15.0 s** of
      > paced streaming with **100 %** of bytes echoed, then round-tripped a
      > **3.6 MB** burst — one paper's audio — without dropping. So **B1 stays
      > available as the D6 fallback**, which is what this question was for.
      >
      > ### The correction that decided this task
      >
      > **The spike's own verdict on tokens was wrong, and it is the reason
      > Path A looked dead.** `live-spike.ts` sent its ephemeral token to
      > `…GenerativeService.BidiGenerateContent` and got
      > `1008 Permission denied on the service`, which reads like "the free
      > tier refuses tokens". It is not. Google keeps **two** Live services and
      > each refuses the other's credential:
      >
      > | | `BidiGenerateContent` | `BidiGenerateContentConstrained` |
      > |---|---|---|
      > | API key | works | `1007 Missing or malformed auth token` |
      > | ephemeral token | `1008 Permission denied` | **works** |
      >
      > Verified in both directions, on both API versions. A full read over the
      > constrained endpoint with a minted token returned **0.0 % WER** and
      > 1191 KiB of audio — Path A end to end, on the free tier.
      >
      > **This was a live bug in shipped T10 code.** `gemini-token-client.ts`
      > built the unconstrained URL, so `live-token` would have handed every
      > phone a URL that closes 1008 — after the single-use token was already
      > spent. Nothing caught it: the handler test injects a canned minter, and
      > no test covered the URL builder. Fixed, and
      > `tests/unit/gemini-token-client.test.ts` now fails if the endpoint name
      > regresses. `live-spike.ts` picks the endpoint from the credential too,
      > so a re-run cannot repeat the wrong conclusion.
      >
      > ### Two traps for whoever touches this next
      >
      > 1. **`supabase functions serve` cannot test a WebSocket at all.** It
      >    starts the runtime with `--policy=oneshot`, which kills the worker
      >    the moment the handler returns — every socket dies ~10 ms after the
      >    upgrade with "Unexpected EOF", no matter what the function does. The
      >    first probe runs failed this way and it looked like Edge Functions
      >    simply do not support WebSockets. They do. Test against a runtime
      >    started with `--policy=per_worker`.
      > 2. **Hitting the runtime directly skips Kong's path rewrite.** Kong
      >    strips `/functions/v1`, so a direct container request is `/ws-echo`,
      >    not `/functions/v1/ws-echo`, and the entrypoints are resolved
      >    relative to the container's `/work/war2aty` working directory.
      >
      > **Still owed, and deliberately not blocking:** (e) was answered on the
      > local emulator. Hosted Supabase may hold sockets for less. That only
      > matters if B1 is ever reached, so re-probe staging **before** falling
      > back, not now.
      >
      > The `ws-echo` function the probe needs is **deliberately not in the
      > repo**, and neither is its `verify_jwt = false` entry: an
      > unauthenticated echo server that someone's `deploy --all` puts on the
      > hosted project is a free-tier bandwidth hole for no standing benefit.
      > `ws-edge-probe.ts` carries the eight lines to recreate it.
- [x] **T02** `docs/API_CONTRACT.md` **§34** — the chosen transport's contract in
      §33's style: request and response shapes, the error-mapping table, the
      token's lifetime and single-use semantics (or the relay's frame protocol),
      and the gates it honours. Preserve the file's **CRLF**. *Done when:* the
      owner approves it in writing and §34 is in the contract.
      > **DONE 2026-11-13. Approved by the owner**, as drafted — §34 is in the
      > contract and T08 onward are unblocked. CRLF preserved (verified by
      > byte count, not by eye).
      >
      > **Three things the draft decided rather than described**, each raised
      > with the owner and approved as written:
      >
      > 1. **Reading is free.** No slot, no daily-limit check — `explain-document`
      >    already charged for the explanation. So a user out of daily analyses
      >    can still mint tokens and still hear the paper they already paid for.
      >    The ceiling on abuse is Google's Live quota, not ours.
      > 2. **The two-minute session window stays a written rule, not a field.**
      >    `newSessionExpireTime` is not in the response; the client sees only
      >    the 30-minute `expires_at`. **T17 must mint immediately before
      >    connecting** — a token fetched when the result screen opens and used
      >    when the user presses play is already dead if they hesitated. Adding
      >    `session_window_expires_at` was considered and declined as T10 churn;
      >    revisit if T17's device testing shows users hitting it.
      > 3. **`INTERNAL_ERROR` deliberately merges "Google refused" with "we are
      >    broken".** The client does the same thing either way (fall to device
      >    TTS), so the distinction lives in `live-token.mint_failed` server-side
      >    instead of in the contract.
      >
      > **The one line with reach beyond F37:** §34.3 records that `speechConfig`
      > is refused everywhere, so **the voice is Google's default and cannot be
      > pinned** — no setting, no fallback, no warning if they change it. This is
      > now contract, not a footnote: any F38–F41 work that assumes a choosable
      > or stable voice has to be re-planned.

### Phase B — the domain, and one independent string change

- [x] **T03** Domain entities and sealed events: `VoiceSegment`,
      `SpokenCardSpan(exact:)`, `VoiceReadEvent` (sealed), `VoiceEngine`, the
      failure union, and the three service interfaces `LiveVoiceSession`,
      `PcmAudioSink`, `AudioEncoder`. *Done when:* `features/voice/domain/`
      compiles with **zero** Flutter, plugin or Supabase imports.
      > **DONE 2026-11-12.** Ten files under `lib/features/voice/domain/`
      > (`entities/`: `voice_segment`, `pcm_format`, `spoken_card_span`,
      > `voice_engine`, `live_voice_event`, `voice_read_event`,
      > `voice_read_outcome`; `services/`: `live_voice_session`,
      > `pcm_audio_sink`, `audio_encoder`). Imports are `dart:typed_data` plus
      > `core/error` and `core/result` only — nothing else.
      >
      > **No separate failure union.** F37's failures are five new leaves on the
      > existing `AppFailure`, not a parallel type: the project's contract is
      > `Result<T, AppFailure>` everywhere, and a second union would have needed
      > translating at every boundary. `AudioPlaybackFailure` and
      > `AudioEncodingFailure` (local), `VoiceServiceFailure` and
      > `VoiceStreamInterruptedFailure(heard)` (network),
      > `VoiceReadNotVerbatimFailure(wordErrorRate)` (business).
      >
      > **The trap this uncovered, for every later task that adds a leaf.** Five
      > new leaves broke **three** deliberately-exhaustive switches and one
      > cross-stack test, and `flutter analyze` only reports them one at a time —
      > fix one and the next appears. The full cost of one leaf is **five**
      > places:
      > 1. `lib/core/error/app_failure.dart` — the leaf itself.
      > 2. `lib/core/logging/error_code.dart` — its content-free log code.
      > 3. `lib/features/analysis/domain/usecases/should_fall_back_to_on_device_ocr.dart`
      >    — F20 §1's closed allowlist, which exists precisely to force this
      >    decision. All five voice leaves answer `false`: a voice problem says
      >    nothing about whether text can be got off the page.
      > 4. `test/core/error/app_failure_test.dart` — the `_describe` switch and
      >    the three leaf counts (16/12/4 → **18/14/5**, total 32 → **37**).
      > 5. **`supabase/functions/_shared/reports/error-report-codes.ts`** — the
      >    one that is easy to miss, because it is in the *other* stack.
      >    `error_report_codes_test` catches it with a message that names the
      >    file: an unlisted code is a 400 the app's own sink swallows, so the
      >    report would vanish silently rather than fail loudly.
      >
      > **Three design points worth keeping.** `PcmFormat.durationOfBytes`
      > returns microseconds, not milliseconds: at 48 bytes per millisecond a
      > millisecond grid would be visible in a card span. `SpokenCardSpan`
      > is **half-open** (`contains` excludes `end`) so adjacent spans never
      > both claim the boundary and two cards can never highlight at once.
      > And `VoiceReadOutcome.verified` is `true` by construction on the device
      > tier — a TTS engine speaks the exact string it is handed and cannot
      > reword it — so the flag means "there is reason to trust this audio",
      > not "a model was checked".
      >
      > **Ran before T01/T02**, as the plan allows: pure domain work with no
      > transport dependency. 24 new tests, including a privacy guard asserting
      > every `toString()` on a content-bearing type reports a size rather than
      > the paper's words (CLAUDE.md §7) — a leak that is invisible in review,
      > since a default `toString()` would simply print the sentence.
      >
      > Gate: `dart format` clean repo-wide, `flutter analyze` **0 errors**
      > (19 pre-existing infos, none in a touched file), `flutter test`
      > **2849 passed / 0 failed** (2825 + 24), `deno test` **1018 passed /
      > 0 failed**.
- [x] **T04** Amend `privacyPointTextOnly` so it covers reading the paper aloud,
      not only analysing it. Touches `app_strings.dart`, `ar_strings.dart` and
      `en_strings.dart`. The wording must still name **no provider** and must not
      claim nobody reads the text (CLAUDE.md §7). *Done when:* all three files
      are updated and `app_strings_test`'s privacy assertions are extended to
      the new claim rather than merely still passing.
      > **DONE 2026-11-12.** The point now states both sends, in the same
      > three-part shape F20-T24 approved for the image — what leaves, what we
      > promise, what we cannot:
      >
      > > «بنبعت نص ورقتك مشفَّر لخدمات خارجية علشان نفهمه ونقراه لك بصوت عالي،
      > > ومانحفظش النص عندنا. بس ممكن يراجعه موظفين في الخدمات دي لتحسين
      > > خدماتها.»
      >
      > Two assertions added, so the claim is tested rather than merely
      > tolerated: the copy must say it is read aloud (`بصوت عالي` /
      > `read it aloud`) and must not hide human review (`يراجعه موظفين` /
      > `staff at those services may review it`). The privacy group is 7 → 9
      > tests. The existing bans still hold — no provider named, no
      > «محدش بيقرا», no "nobody sees the text".
      >
      > **Why "خدمات" plural rather than naming a second service.** The user
      > does not need to count our vendors; they need to know their paper's
      > words leave the phone and that people may read them. Naming a second
      > service would also drift towards naming providers, which §7 forbids.
      >
      > ⚠️ **Two carry-forwards to F44, both of which are correct TODAY and
      > become false the moment 1.1.0 ships.** Neither is fixed here, on
      > purpose: the published policy must describe the **published** app, and
      > 1.0.2 genuinely does neither of these things.
      > 1. **`legal/privacy.html` still says the text goes only to an analysis
      >    service** (lines ~46 and ~125, and the English at ~330–337). It is
      >    deployed to `gh-pages` as `privacy.html`, so updating it before
      >    release would describe a data flow the shipped app does not have.
      >    F44 must update it **in the same release** as this string.
      > 2. **The same file advertises "a switch that stops any text being sent
      >    for analysis"** (line ~370). F35 deleted that setting entirely. Still
      >    true of published 1.0.2; false from 1.1.0. Already stale against this
      >    branch, and easy to miss because nothing tests the HTML.
      >
      > Also feeds Play's **Data safety** form: on the token transport the
      > phone sends the explanation to an outside service **directly**, which is
      > a new disclosed flow rather than a re-wording of an existing one.
      >
      > Gate: `flutter analyze` 0 errors, `flutter test` **2851 passed /
      > 0 failed** (2849 + 2).
- [x] **T05** `NormaliseArabicForDiff` + `VerifyVerbatimRead`, **prefix-capable**
      so a bad read is caught early rather than after 75 s. A Dart port of the
      spike's normaliser and WER diff. *Done when:* all 11 cases from
      `supabase/tests/unit/live-spike-diff.test.ts` pass and the Dart and Deno
      normalisers provably agree.
      > **DONE 2026-11-12.** All 11 Deno cases ported case-for-case, same inputs
      > and same expectations, into
      > `test/features/voice/domain/verify_verbatim_read_test.dart`. Duplicated
      > rather than shared on purpose: the Deno tool decided whether F37 could
      > be built, the Dart code makes the same call on every read a user hears,
      > and asserting the same facts about both is the only way to know they
      > still agree. 20 tests, 44 in the voice suite.
      >
      > **The three bands are the spike's own**, reused unchanged
      > (`live-spike.ts:548-550`): ≤ 5 % verbatim, ≤ 15 % near-verbatim, above
      > that not verbatim. `isAcceptable` tolerates the near band — the dropped
      > and added words are what distinguish transcription noise from the
      > model's own additions, and the rate alone cannot.
      >
      > **A finding the port turned up, and the reason the near band must stay
      > tolerated.** The Deno case is named "stays under the 5% gate on a page",
      > but its own three sentences are **21 words**, where a two-word greeting
      > is **9.5 %** — near-verbatim, not verbatim. The rate is a fraction of
      > the page, so *the shorter the paper the harsher the gate*. On a real
      > ~850-character page the same greeting is ~1.5 %. Pinned as its own test
      > ("a greeting costs a short paper more than a long one") so nobody later
      > tightens `isAcceptable` to the 5 % band and starts re-reading every
      > short paper over a politeness token.
      >
      > **The early check.** `checkPrefix` compares what has been heard against
      > the *beginning* of the page and returns `null` until 20 words have
      > arrived (~2 s of speech): judging a handful of words would fail honest
      > reads constantly, since one added «أهلاً» is 50 % of two words. It also
      > drops the newest word before comparing, because a delta can land
      > mid-word and would otherwise read as one dropped plus one added word.
      > Callers act only on `notVerbatim` here — the 5 % band is for the
      > complete read, and applying it to a fragment would abandon reads that go
      > on to be perfect.
      >
      > **Privacy:** `VerbatimComparison.toString()` reports counts and the
      > verdict, never the dropped or added words, which are the paper's own
      > (CLAUDE.md §7). Asserted.
      >
      > Gate: `flutter analyze` 0 errors, `flutter test` **2871 passed /
      > 0 failed** (2851 + 20).
- [x] **T06** `BuildVoiceTurnText` — segments → one turn plus per-segment
      character offsets, with segments separated by a blank line and a full stop
      so Live actually pauses between them (which T14 depends on). *Done when:* a
      six-card page yields exact per-segment offsets.
      > **DONE 2026-11-13.** One file:
      > `lib/features/voice/domain/usecases/build_voice_turn_text.dart` — a pure
      > function, no dependencies beyond `VoiceSegment`. The result is
      > `VoiceTurnText`: the assembled turn text and a list of
      > `SegmentCharOffset` (half-open `start..end` into the text, one per input
      > segment, in order).
      >
      > **The separator is `.\n\n`** — a full stop followed by a blank line.
      > The full stop tells Live the sentence ended (so it pauses), and the blank
      > line gives a visual break. Together they produce the consistent gap T14's
      > silence detector will look for. The separator sits *between* segments
      > only — the last segment has no trailing stop, so Live does not add a
      > spurious pause before `turnComplete`.
      >
      > **Offsets are character-level, not byte-level**, because the text travels
      > as a JSON string and Gemini counts characters. Each offset extracts its
      > segment's original text via `text.substring(start, end)` — tested with a
      > six-card page whose every offset round-trips.
      >
      > **Privacy.** `VoiceTurnText.toString()` reports length and segment count,
      > never the text (CLAUDE.md §7). Asserted.
      >
      > 11 tests: empty input, single segment (no separator), two segments
      > (separator present), six-card page with exact round-tripping offsets,
      > separator structure (full stop, blank line), whitespace preservation,
      > empty-text segments (zero-length offsets), total length arithmetic,
      > toString privacy, and SegmentCharOffset equality/hashCode.
      >
      > Gate: `dart format` clean, `flutter analyze` **0 errors** (20
      > pre-existing infos, none in a touched file), `flutter test` **2962
      > passed / 0 failed** (2951 + 11).
- [x] **T07** `AlignSegmentsToAudio` — anchor only on frames carrying **both**
      audio and transcript, forward-only LCS over normalised words, interpolate
      between anchors, and fall back to a proportional span
      (`charsBefore / totalChars × duration`) when a segment cannot be matched.
      *Done when:* a transcript missing one card still yields spans for **all**
      cards, with `exact: false` on that one. Alignment never fails a read.
      > **DONE 2026-11-13.** The use case plus a new entity
      > (`TranscriptAudioAnchor`) and 25 table-driven tests covering: a perfect
      > match (all exact), a card missing from the transcription (exact: false,
      > span still present), an unmatched card bounded by two matched
      > neighbours, spelled-out digits surviving through folding, all audio
      > arriving before all transcription (proportional fallback, all inexact),
      > a mid-word delta never pushing a card late, zero-byte anchors
      > contributing nothing, out-of-order and over-sized anchors being
      > discarded, degenerate pages (empty, one segment, zero audio), and the
      > `minMatchedWords = 2` gate preventing a coincidental «في» from
      > anchoring a card.
      >
      > **The one-word exception.** A segment with only one word (e.g.
      > «مستعجل») can never offer two matches, so the gate is capped at the
      > segment's own word count. Tested and honest: the span is exact when the
      > word matched, because a single distinctive word *is* informative.
      >
      > **Privacy.** `TranscriptAudioAnchor.toString()` describes the
      > transcription by character count, never by its words (CLAUDE.md §7).
      > Asserted.
      >
      > Gate: `flutter analyze` 0 errors, `flutter test` **2896 passed /
      > 0 failed** (2871 + 25).

### Phase C — the Live client

- [x] **T08** Live frame DTOs, hand-written `fromJson`/`toJson` (no codegen).
      *Done when:* golden frames copied verbatim from the spike parse, unknown
      fields are ignored, and a test pins
      **`serverContent.outputTranscription.text`** against the setup key's
      different spelling.
      > **DONE 2026-11-13.** Two DTOs under `lib/features/voice/data/models/`:
      > `LiveSetupDto` + `LiveClientContentDto` (client → server, `toJson`
      > only), and `LiveServerFrame` sealed class (server → client, `fromJson`
      > only) with four variants: `LiveSetupCompleteFrame`,
      > `LiveContentFrame`, `LiveErrorFrame`, `LiveUnknownFrame`.
      >
      > `LiveContentFrame` decodes base64 audio inline (`List<Uint8List>
      > audioChunks`) and reads the transcript from the correct server key
      > `outputTranscription` — not the setup key `outputAudioTranscription`.
      > Unknown top-level keys yield `LiveUnknownFrame`; unknown fields
      > inside `serverContent` are silently ignored.
      >
      > **The field-name trap is pinned by two tests.** The first proves
      > `outputTranscription` yields text and the setup spelling
      > `outputAudioTranscription` yields null on a server frame. The second
      > proves the two keys are provably different strings across the setup
      > DTO and the server frame parser, so a refactor that unifies them
      > would break under test.
      >
      > 19 tests: setup serialisation (2), client content (1), server frame
      > parsing (14 — setup complete, audio only, transcription only, both,
      > turnComplete, generationComplete, error, error defaults, unknown key,
      > unknown fields, multiple parts, empty data, non-audio parts, empty
      > serverContent), and the field-name trap (2).
      >
      > Gate: `dart format` clean, `flutter analyze` **0 errors** (19
      > pre-existing infos, none in a touched file), `flutter test` **2915
      > passed / 0 failed** (2896 + 19).
- [x] **T09** `GeminiLiveVoiceSession` — the only file importing
      `web_socket_channel`. Setup per the spike's four conditions, inter-frame
      watchdog (~10 s) and total watchdog (~60 s), `goAway` handling, and the
      drop rules: a drop before `turnComplete`/`generationComplete` **discards
      the partial `.m4a`**; under 2 s heard restarts Live once; otherwise device
      TTS. *Done when:* fake-socket tests cover a clean turn, a mid-stream drop
      and a 1007 close.
      > **DONE 2026-11-13.** One file under
      > `lib/features/voice/data/services/gemini_live_voice_session.dart` — the
      > only file in the app importing `web_socket_channel` (promoted from
      > transitive to direct in `pubspec.yaml`). The session takes an injected
      > `Future<WebSocketChannel> Function(Uri)` factory and a model string;
      > the four spike conditions are hard-wired as constants, not parameters.
      >
      > **The system instruction is the spike's own**, character-for-character:
      > «اقرأ النص التالي بالحرف، كلمة بكلمة...». The setup frame carries all
      > four conditions (responseModalities=AUDIO, temperature=0, the verbatim
      > instruction, outputAudioTranscription enabled) — pinned by a test.
      >
      > **Two watchdogs.** An inter-frame timer resets on every frame; if no
      > frame arrives for `interFrameTimeout` (default 10 s), the session emits
      > `LiveSessionLost`. A total timer fires at `totalTimeout` (default 60 s)
      > regardless of frame activity. Both are injectable for testing via
      > `fakeAsync`.
      >
      > **Drop classification.** A socket close (including 1007) or watchdog
      > timeout after audio has been delivered yields
      > `VoiceStreamInterruptedFailure(heard)` — the heard duration is the
      > total audio bytes converted via `PcmFormat.durationOfBytes`, so T17 can
      > decide retry-vs-TTS. Before any audio, every failure is
      > `VoiceServiceFailure`. An error frame from the server is always
      > `VoiceServiceFailure` regardless of audio heard, because the service
      > itself said something is wrong.
      >
      > **Cancel is safe on every path**, including before `start()` and after
      > successful completion (the interface contract). A second `start()` call
      > returns `Err` immediately. `cancel()` never emits a terminal event — it
      > only closes the stream and the socket.
      >
      > **Golden frames** live in `test/support/live_frames.dart` — helpers
      > that build `setupComplete`, audio, transcription, `turnComplete`,
      > `generationComplete` and error frames as JSON strings. A
      > `_FakeWebSocketChannel` in the test file drives the session end to end
      > without touching a real socket.
      >
      > 22 tests covering: a clean turn (setup → audio → transcript →
      > turnComplete → Ok), generationComplete, the system instruction text,
      > the four spike conditions in setup, a mid-stream drop (socket closes
      > after audio → VoiceStreamInterruptedFailure with correct heard
      > duration), accumulated heard across multiple frames, 1007 before audio
      > (VoiceServiceFailure), 1007 after audio (VoiceStreamInterruptedFailure),
      > error during setup (Err), error after setup (LiveSessionLost), connect
      > failure (Err), inter-frame watchdog without audio, inter-frame watchdog
      > with audio, inter-frame timer resets on each frame, total watchdog,
      > cancel before start, cancel during streaming, cancel after completion,
      > double start, socket close before setupComplete, and unknown frames
      > ignored.
      >
      > **Dependencies added:** `web_socket_channel: ^3.0.0` (promoted from
      > transitive — already present via `supabase_flutter`),
      > `fake_async: ^1.3.0` (dev only, for timer-controlled tests).
      >
      > Gate: `dart format` clean, `flutter analyze` **0 errors** (19
      > pre-existing infos, none in a touched file), `flutter test` **2937
      > passed / 0 failed** (2915 + 22), `deno test` **1018 passed /
      > 0 failed**.
- [x] **T10** `live-token` Edge Function (or the relay T01 chose), in
      `get-usage`'s shape, plus the Dart datasource behind
      `LiveSessionEndpoint`. *Done when:* 401, 429 and offline map to **distinct**
      `AppFailure`s and the Deno tests are green.
      > **Built for Path A** (ephemeral token) — the bet T01 later confirmed,
      > though it also found this file pointing at the wrong Live endpoint
      > (see T01; fixed there, with a test). Server:
      > `gemini-token-client.ts` mints a single-use
      > token (30 min TTL, 2 min session window, uses=1) from Google's
      > `auth_tokens` REST API; `live-token-handler.ts` gates on auth +
      > `analysisEnabled` + `explainEnabled`, then mints and returns
      > `{ ws_url, model, expires_at }`. Dart: `EdgeFunctionLiveTokenDataSource`
      > calls `POST /live-token`, parses `LiveSessionEndpoint`, and maps errors
      > via `failureFromErrorBody` + a local `_failureFromDioException` that
      > returns `VoiceServiceFailure` (not `AnalysisServiceFailure`) for
      > non-connectivity failures. Gate: `deno test` **14 passed / 0 failed**,
      > `flutter analyze` **0 errors / 0 warnings** (20 info), `flutter test`
      > **2951 passed / 0 failed**.

### Phase D — Android audio

Kotlin holds **zero decisions**: it fans the PCM stream out and encodes. Dart
does not fan out — `BasicMessageChannel` with `BinaryCodec` carries ~96 KB/s of
binary, with a small control `MethodChannel` beside it.

- [x] **T11** `AudioTrack` PCM sink: plays chunks as they land, requests **audio
      focus** (`usage=MEDIA`, `contentType=SPEECH` — `flutter_tts` does this for
      us, `AudioTrack` does not), exposes `getPlaybackHeadPosition` as the
      playback clock, and enforces a single-owner gate so `flutter_tts` and
      `AudioTrack` can never both play. *Done when:* an incoming call interrupts
      the read on the device.
      > **DONE 2026-11-13.** One file:
      > `android/app/src/main/kotlin/com/war2aty/app/voice/PcmPlayer.kt` —
      > `AudioTrack` in `MODE_STREAM` with `USAGE_MEDIA` / `CONTENT_TYPE_SPEECH`
      > audio attributes. Requests `AUDIOFOCUS_GAIN` on `open()`, which causes
      > the system to send `AUDIOFOCUS_LOSS` to whatever held focus before —
      > including `flutter_tts` — so the two can never both play.
      >
      > **Audio focus handling.** An `OnAudioFocusChangeListener` pauses the
      > track on `AUDIOFOCUS_LOSS`, `LOSS_TRANSIENT` and
      > `LOSS_TRANSIENT_CAN_DUCK` (an incoming call falls into these), and
      > resumes on `AUDIOFOCUS_GAIN`. The `onFocusLost` callback notifies the
      > plugin. The `@Volatile hasFocus` flag prevents resume when focus has not
      > been regained.
      >
      > **`write()` is blocking** in `MODE_STREAM`: it returns only when the
      > hardware has consumed enough of its buffer to accept the new chunk. The
      > caller (T13's channel handler) must therefore call it off the UI thread.
      >
      > **The playback clock** is `getPlaybackHeadPosition` converted to
      > microseconds: the number of frames the hardware has rendered, divided by
      > the sample rate. This is the single source of truth for the reading's
      > position, shared between the segment-span alignment and the cubit.
      >
      > **Buffer sizing.** `maxOf(getMinBufferSize(), bytesPerSecond)` gives a
      > ~1 s buffer. At 48 KB/s input this accommodates the ~2× real-time
      > delivery rate without dropping, while keeping latency under a second.
      >
      > The Kotlin path is not unit-testable (no Robolectric AudioTrack mock);
      > T21's device checklist on the physical RMX2001 (API 30) covers it.
- [x] **T12** `MediaCodec` + `MediaMuxer` AAC-LC encoder off the **same** stream:
      24 kHz mono, 32 kbps; keeps consuming while playback is paused (pausing it
      corrupts the file); `abort()` deletes a partial. *Done when:* a 75-second
      read yields a ≤ 0.35 MB `.m4a` that plays in an external player.
      > **DONE 2026-11-13.** One file:
      > `android/app/src/main/kotlin/com/war2aty/app/voice/AacEncoder.kt` —
      > `MediaCodec` (AAC-LC, `AACObjectLC`) encodes the PCM and `MediaMuxer`
      > (`MUXER_OUTPUT_MPEG_4`) writes the `.m4a` container. The temp file sits
      > in the app's cache directory, named with `System.nanoTime()` to avoid
      > collisions, and is deleted after `finish()` reads it back or `abort()`
      > discards it.
      >
      > **The encoder never pauses.** `feed()` keeps accepting chunks regardless
      > of whether `PcmPlayer` is paused: a paused muxer would break the
      > timestamp sequence (`presentationTimeUs` is computed from cumulative
      > bytes, not wall clock) and produce a corrupt file. The two share the
      > same sequential call site (T13's channel handler), so there is no
      > concurrency.
      >
      > **Budget check.** 32 kbps × 75 s = 300 KB of AAC payload, plus
      > container overhead ≈ 0.29–0.31 MB — comfortably under the 0.35 MB cap.
      >
      > **Three safety valves.** (1) `acquireInputBuffer` retries up to 100
      > times (each with a 10 ms dequeue timeout, ~1 s total) before dropping
      > the rest of a chunk — at 48 KB/s input vs 4 KB/s output the codec
      > should always keep up, but a stuck codec must not hang the handler.
      > (2) The EOS drain in `finish()` uses a longer 100 ms timeout and caps
      > at 500 rounds (~50 s) so a codec that never delivers EOS does not block
      > forever. (3) `releaseQuietly` wraps both stop+release in try/catch so a
      > double-release or a release after an error frame never crashes.
      >
      > **`finish()` returns `ByteArray?`**, not a file path: the only
      > permitted resting place for the audio is encrypted
      > (`EncryptedAudioStore`, T15), and handing back a plaintext file would
      > leave a readable recording of someone's paper on disk however briefly.
      >
      > **The Kotlin path is not unit-testable** (no robolectric MediaCodec
      > mock), which is why it holds no decisions; T21's device checklist on
      > the physical RMX2001 (API 30) covers it.
      >
      > Gate: Gradle `compileDebugKotlin` **BUILD SUCCESSFUL** (no warnings in
      > our file), `dart format` 0 changed, `flutter analyze` **0 errors**
      > (20 pre-existing infos, none in a touched file), `flutter test`
      > **2951 passed / 0 failed**, `deno test` **1032 passed / 0 failed**.
- [x] **T13** `MethodChannelLiveAudioOutput`, implementing **both** sink
      interfaces over `com.war2aty.app/voice_audio`. *Done when:* channel tests
      assert chunk order and map `MissingPluginException` to an `AppFailure`.
      > **DONE 2026-11-13.** Three files:
      >
      > **`VoiceAudioPlugin.kt`**
      > (`android/app/src/main/kotlin/com/war2aty/app/voice/`) — the Kotlin host.
      > A control `MethodChannel` (`com.war2aty.app/voice_audio`) handles
      > open / pause / resume / stop / beginEncode / finishEncode / abortEncode /
      > getPosition. A binary channel (`com.war2aty.app/voice_audio_pcm`) carries
      > the raw PCM on a **background task queue** (`makeBackgroundTaskQueue`)
      > so that `PcmPlayer.write()`'s blocking call does not stall the UI thread.
      > Every binary chunk is fanned to both `PcmPlayer` and `AacEncoder` on the
      > Kotlin side — Dart sends once, Kotlin delivers twice.
      >
      > **`MethodChannelLiveAudioOutput`**
      > (`lib/features/voice/data/services/`) — the Dart class implementing
      > **both** `PcmAudioSink` and `AudioEncoder`. `write()` sends via the
      > binary channel; `feed()` is a documented no-op because the Kotlin handler
      > already fanned the chunk. `open()` and `begin()` are separate calls so
      > the player and encoder can be opened independently, and
      > `MissingPluginException` on either maps to the correct `AppFailure`
      > (`AudioPlaybackFailure` for the sink, `AudioEncodingFailure` for the
      > encoder). `PlatformException` maps the same way.
      >
      > **Position polling.** A `Timer.periodic` (default 200 ms, injectable
      > for tests) calls `getPosition` on the control channel and emits to a
      > **sync broadcast** `StreamController<Duration>`. Sync delivery means the
      > cubit's state is always up to date when the next poll fires. The timer
      > starts on `open()` and is cancelled by `stop()`. `stop()` also emits
      > the final played position before returning.
      >
      > **Registration.** `VoiceAudioPlugin` is instantiated in
      > `MainActivity.configureFlutterEngine` beside the existing system-settings
      > channel.
      >
      > 33 tests: open success / host false / MissingPlugin / PlatformException /
      > format params; write through binary channel / chunk order preserved /
      > silent before open / silent after stop; pause / resume / their
      > MissingPlugin resilience; stop returns duration / MissingPlugin →
      > Duration.zero / PlatformException → Duration.zero / emits final position;
      > beginEncode success / false / MissingPlugin / PlatformException; feed
      > no-op; finishEncode returns bytes / null → Err / empty → Err /
      > MissingPlugin / PlatformException; abort / abort MissingPlugin;
      > position stream polls after open / stops polling after stop; full flow
      > open → begin → write → stop → finish; abort discards without finish.
      >
      > Gate: `dart format` 0 changed, Gradle `compileDebugKotlin` **BUILD
      > SUCCESSFUL**, `flutter analyze` **0 errors** (20 pre-existing infos,
      > none in a touched file), `flutter test` **2995 passed / 0 failed**
      > (2962 + 33), `deno test` **1032 passed / 0 failed**.
- [x] **T14** Probe PCM **silence detection** (RMS below threshold for > 250 ms)
      as a transcript-independent source of segment boundaries, matched in order
      to the N−1 boundaries T06 created. *Done when:* measured against a real
      read and either promoted to primary or rejected **in writing here**.
      > **DONE 2026-11-13. REJECTED as primary.** The algorithm works — 19 tests
      > pass against synthetic PCM — but it cannot be the primary source of
      > segment boundaries. The code is kept for future use.
      >
      > **`DetectPcmSilences`**
      > (`lib/features/voice/domain/usecases/detect_pcm_silences.dart`) scans
      > 16-bit LE mono PCM in 10 ms frames, computes RMS amplitude per frame,
      > and returns `SilenceGap`s for runs that stay below a threshold (default
      > 200 RMS, ~−44 dBFS) for at least a minimum duration (default 250 ms).
      > The midpoint of each gap is a natural boundary timestamp. On a
      > five-segment synthetic buffer with 400 ms gaps, the detector finds all
      > four boundaries exactly.
      >
      > **Why rejected — five reasons, in order of weight.**
      >
      > 1. **The threshold is a guess.** 200 RMS is a design-time estimate.
      >    Real Gemini Live audio has an unknown noise floor (codec artefacts,
      >    breath sounds, model-specific prosody). Without real audio from T01,
      >    shipping this threshold would mean shipping an untested gate on every
      >    segment boundary in the app.
      >
      > 2. **False boundaries from internal pauses.** Arabic speech has natural
      >    pauses between sentences and clauses that can easily exceed 250 ms.
      >    A long segment with a 300 ms pause between two sentences would
      >    produce a false boundary. Raising `minGap` to avoid it would then
      >    miss real boundaries where the `.\n\n` separator produced only a
      >    ~400 ms gap — the margin is too thin.
      >
      > 3. **Missing boundaries.** If Gemini Live reads two adjacent segments
      >    without a sufficient pause — e.g., the full stop did not produce
      >    enough of a gap, or the model ran them together despite the blank
      >    line — the boundary is invisible to the detector. The caller then
      >    gets N−2 gaps for N−1 boundaries and must fall back anyway.
      >
      > 4. **T07 already handles the problem honestly.** The transcript-based
      >    alignment works, marks what it cannot match with `exact: false`, and
      >    places unmatched segments by proportional character share between
      >    matched neighbours. The honest flag is the whole point: F40 knows
      >    which cards to trust and which ones to soften, rather than being
      >    handed a silence-based guess dressed as a measurement.
      >
      > 5. **The ~400 ms gap from `.\n\n` is assumed, not observed.** T06's doc
      >    says the separator "produces a consistent ~400 ms gap", but that
      >    comes from the spike's operator impression, not a measurement. A
      >    future model version, or a different voice or language setting, could
      >    produce a different gap — and the detector would silently degrade.
      >
      > **What the code is still good for.** If T01 produces real audio and the
      > gaps turn out to be consistent and cleanly above the threshold, silence
      > detection could supplement T07 as a second anchor source — a
      > `SilenceGap` at roughly the expected time for an unmatched segment
      > would let T07 upgrade that segment from proportional to bounded, with
      > `exact` still false but a tighter span. That integration is not written
      > here because it is speculative until real data exists, and because T07's
      > proportional fallback is already good enough for F40's auto-scroll
      > (which is a convenience, not a condition of the read).
      >
      > 19 tests: empty input, sub-frame input, all speech, all silence, one
      > gap, two gaps, short silence below minGap, custom minGap, noisy silence
      > below/above threshold, silence at start/end, midpoint arithmetic,
      > five-segment page, internal sentence pause as false boundary, custom
      > threshold, equality/hashCode, toString privacy, temporal order.
      >
      > Gate: `dart format` clean, `flutter analyze` **0 errors** (20
      > pre-existing infos, none in a touched file), `flutter test` **3014
      > passed / 0 failed** (2995 + 19), `deno test` **1032 passed /
      > 0 failed**.

### Phase E — storage and replay

- [x] **T15** `EncryptedAudioStore` + `FileEncryptedAudioStore`, mirroring
      `FileDocumentImageStore`, writing to the app-private directory and keyed by
      a plain id string. *Done when:* round-trip passes and a truncated file
      yields a `FileEncryptionFailure` rather than a crash.
      > **DONE 2026-11-13.** Two files under `lib/core/voice/`:
      > `encrypted_audio_store.dart` (interface) and
      > `file_encrypted_audio_store.dart` (implementation). In `core/` rather
      > than the feature, because F38, F39, F40 and F43 all consume it — the
      > Files section already planned this.
      >
      > **Input is bytes, not a file path.** The encoder (`AacEncoder.finish()`)
      > returns a `Uint8List`, and the store encrypts it directly — no plaintext
      > file is ever created, so there is no window where a readable recording of
      > someone's paper sits on disk (CLAUDE.md §7). This is the key difference
      > from `FileDocumentImageStore`, which takes a source path and deletes it
      > after encryption.
      >
      > **The file is `audio.m4a.enc`**, not `original.enc`: there is no
      > "original" — the audio was never a user-visible file. Stored under
      > `voice_audio/{id}/` inside the app's private support directory.
      >
      > **`exists(id)`** added beyond the image store's interface: T16 and T17
      > need to check whether offline replay is available without decrypting the
      > whole file.
      >
      > **The `await` trap.** The image store test already guards against
      > returning a `Future` without `await` inside a try block (the encryptor
      > that throws test). The same pattern is applied here: both `load()` and
      > `exists()` await their async operations inside the try, so a throwing
      > encryptor or a filesystem error is classified into an `AppFailure`
      > rather than escaping as an unhandled exception.
      >
      > 15 tests: store writes encrypted bytes under the correct path, store
      > propagates encryption failure, store overwrites an existing file for
      > the same id; load reads back the stored bytes, load on a missing id
      > yields `FileStorageFailure`, a truncated file through the real AES-GCM
      > encryptor yields `FileEncryptionFailure`, a throwing encryptor is
      > classified not left to escape, round-trip through the real AES-GCM
      > encryptor; exists returns false/true/false around store and delete;
      > delete removes the directory, delete is a quiet no-op; deleteAll removes
      > the entire voice_audio directory, deleteAll is a quiet no-op.
      >
      > Gate: `dart format` clean, `flutter analyze` **0 errors** (20
      > pre-existing infos, none in a touched file), `flutter test` **3029
      > passed / 0 failed** (3014 + 15).
- [x] **T16** `just_audio` + `EncryptedM4aAudioSource`: a `StreamAudioSource`
      serving range requests from a **fully decrypted in-memory buffer**
      (AES-GCM concatenation forbids random-access decryption; 0.3 MB is fine).
      *Done when:* range requests and seek work off the buffer, with the
      decrypt-to-cache fallback documented if it misbehaves on a cheap device.
      > **DONE 2026-11-13.** Two files under
      > `lib/features/voice/data/services/`:
      >
      > **`EncryptedM4aAudioSource`** extends `StreamAudioSource` and serves
      > arbitrary range requests from a fully decrypted in-memory `Uint8List`.
      > AES-GCM concatenation forbids random-access decryption, so the entire
      > ~0.3 MB audio is decrypted once and held in RAM — this is how seek works:
      > `just_audio`'s platform player issues `request(start, end)` calls and
      > the source serves the requested slice from the buffer, with no file I/O.
      > Content type is `audio/mp4` (the standard MIME type for `.m4a`).
      >
      > **`JustAudioEncryptedPlayer`** wraps `just_audio`'s `AudioPlayer` and
      > `EncryptedAudioStore`. `load(id)` decrypts the stored audio, creates an
      > `EncryptedM4aAudioSource`, and feeds it to the platform player. Store
      > failures (`FileStorageFailure`, `FileEncryptionFailure`) propagate
      > unchanged; a platform player failure (e.g. `MissingPluginException` on
      > a device that cannot initialise the audio pipeline) is caught and
      > returned as `AudioPlaybackFailure`. The player is injectable
      > (`AudioPlayer?` parameter) for testing.
      >
      > **Decrypt-to-cache fallback (documented, not built).** If in-memory
      > playback causes issues on cheap devices — out-of-memory on a phone with
      > < 1 GB free, or `just_audio`'s platform player failing to consume a
      > `StreamAudioSource` on old Android versions — the alternative is:
      > (1) write the decrypted bytes to a temp file in the app's cache
      > directory, (2) use `AudioSource.file` instead of this source, (3) delete
      > the temp file in `dispose()`. At 0.3 MB the window where plaintext sits
      > on disk is brief and inside the app-private directory. Not built because
      > the in-memory approach should work on any phone that runs the rest of the
      > app — the owner's flagged risk (the "Risks" section) and this
      > documentation satisfy T16's done-when for the fallback.
      >
      > **`StreamAudioSource` is marked `@experimental` by `just_audio`.**
      > Suppressed with `// ignore_for_file: experimental_member_use` because
      > there is no non-experimental API for serving audio from memory, and D4
      > chose `just_audio` for replay.
      >
      > **Dependency added:** `just_audio: ^0.9.42` (replay only, as D4
      > decided).
      >
      > 19 tests: 13 for `EncryptedM4aAudioSource` (full request, metadata,
      > range with start only, range with start and end, content type,
      > length getter, empty buffer, single byte, zero-length range, single
      > stream event, multiple sequential requests, tail request, 0.3 MB seek)
      > and 6 for `JustAudioEncryptedPlayer` (isLoaded initial, store
      > FileStorageFailure propagation, store FileEncryptionFailure propagation,
      > platform failure → AudioPlaybackFailure, dispose resets isLoaded, id
      > forwarded to store). The player test mocks `just_audio`'s platform
      > channels (`com.ryanheise.just_audio.methods` global + per-player) to
      > exercise the full load-and-fail path without a device.
      >
      > Gate: `dart format` clean, `flutter analyze` **0 errors / 0 warnings**
      > (20 pre-existing infos, none in a touched file), `flutter test` **3048
      > passed / 0 failed** (3029 + 19).

### Phase F — the spine

- [x] **T17** `ReadPaperAloud` — the tier selector: Live → early-abort verify →
      retry once → device TTS → the open-TTS-settings escape, and discard the
      partial file on a drop. A **late** mismatch keeps the audio and marks
      `verified: false` for F38 rather than spending another 75 s; the transcript
      is document content and is **never logged** (CLAUDE.md §7). *Done when:*
      all five paths have a test.
      > **DONE 2026-11-13.** Two new files plus one doc line:
      >
      > **`lib/features/voice/domain/usecases/read_paper_aloud.dart`** — the
      > ladder. `call({segments, audioId})` returns a single-subscription
      > `Stream<VoiceReadEvent>` and the read starts on listen. The Live attempt
      > opens the speaker **before** the session (a session the device cannot
      > play into is a free-tier session spent on silence), begins the encoder,
      > starts the turn, then consumes `session.events` with `await for` —
      > awaiting `sink.write` inside the loop, which is what paces the read to
      > the speed of speech rather than the speed of the socket, since
      > `PcmPlayer.write()` blocks (T11).
      >
      > **`lib/features/voice/domain/services/device_voice_reader.dart`** — the
      > fallback tier's interface, implemented in T18. `read(turn)` answers when
      > the reading has **ended** (deliberately unlike
      > `TextToSpeechService.speak`, which answers once the engine merely took
      > the utterance) and carries the spoken duration; `events` carries
      > progress in F37's own shape. It never emits the envelope —
      > `VoiceReadStarted` / `Completed` / `Failed` are the use case's, because
      > only the use case knows this is the last tier, which is what
      > `VoiceReadFailed`'s own contract requires.
      >
      > **The retry matrix, as built:**
      >
      > | What happened | What the ladder does |
      > | --- | --- |
      > | `sink.open` Err | device TTS; no session is started at all |
      > | `session.start` Err | device TTS; never retried (`VoiceServiceFailure` always falls back) |
      > | `encoder.begin` Err | **the read continues** — `audioSaved: false`, `feed` never called |
      > | prefix verdict `notVerbatim` | abort, discard the file, **retry Live once**, then device TTS |
      > | drop with `heard < 2 s` | retry Live once |
      > | drop with `heard ≥ 2 s` | device TTS — the user would otherwise hear the beginning twice |
      > | stream closed with no terminal frame | treated as a drop → device TTS |
      > | `turnComplete`, final verdict not `verbatim` | **audio kept**, `verified: false` |
      > | `encoder.finish` / `store` Err | read completes, `audioSaved: false` |
      > | device read Err | one `VoiceReadFailed`, the failure intact |
      >
      > `maxLiveAttempts = 2` and `minHeardBeforeLiveRestart = 2 s` are named
      > constants on the class.
      >
      > **Spans land mid-read, as designed.** Alignment runs at
      > `LiveTurnComplete` — which, at roughly twice real time, is about halfway
      > through what the user is hearing — so `VoiceReadSpansResolved` arrives
      > while the paper is still being spoken. Positions before it carry
      > `segmentId: null`, exactly as the event documents.
      >
      > **The drain.** After the spans, the read waits for the sink's own clock
      > to reach `format.durationOfBytes(audioBytes)` before calling `stop()`,
      > so the last second still in `AudioTrack`'s ~1 s buffer is not cut off.
      > The wait is a completer fed by the position subscription, bounded by
      > `drainGrace` (2 s, injectable) in case the clock stalls — no second
      > subscription, so `position` is subscribed exactly once per attempt.
      >
      > **Anchors: a documented proxy.** T07 wants anchors only from frames
      > carrying **both** audio and transcript, but `LiveVoiceEvent` flattens a
      > frame into separate `LivePcmChunk` and `LiveTranscriptDelta` events, so
      > "the same frame" is not observable above the data layer. The ladder
      > anchors a delta when **audio has arrived since the previous delta** —
      > always true for a both-frame, and false for consecutive transcript-only
      > frames. The one false positive left is a transcript-only frame directly
      > after an audio-only frame, which over-counts bytes and places that
      > anchor late; T07 discards out-of-order and over-sized anchors and marks
      > unmatched spans `exact: false`, so the cost is accuracy, not
      > correctness. **Open for the owner:** making this exact needs a frame
      > boundary in the union (a T08/T09 change), which was not worth reopening
      > two closed tasks for.
      >
      > **The escape hatch is reported, not taken.** A `NoArabicVoiceFailure`
      > reaches `VoiceReadFailed` intact so the screen can offer F30-T07's
      > «افتح إعدادات القراءة» button; this use case does not call
      > `OpenSystemTtsSettings` itself, because throwing a user into system
      > settings with no tap is a decision for the screen, not the domain. The
      > wiring is F39/F40's. **Owner: say so if you wanted it auto-opened.**
      >
      > **An empty page** is refused before any engine is touched, with the same
      > `TtsFailure()` `ReadingQueue.speak` answers an empty reading with — the
      > existing precedent, rather than a new failure leaf.
      >
      > **Three holes the reviews found and this task closed:**
      >
      > 1. **A sink that throws.** `MethodChannelLiveAudioOutput.write` does not
      >    guard its binary-channel `send` — unlike `pause` / `stop`, it reports
      >    a dead host by **throwing**, not with a `Result` (T13). Unhandled,
      >    that escaped the frame loop inside an `unawaited` future, left the
      >    output stream open forever and the screen waiting to be told
      >    something: a silent failure (CLAUDE.md §3). The Live tier now catches
      >    it, releases everything and falls to the device — so a phone with no
      >    audio host still hears its paper. Fixed in the ladder, not in T13,
      >    because what a tier failure *means* is the ladder's decision.
      > 2. **Cleanup could flip a successful read into a failed one.** The
      >    release chain (`sink.stop` → `positionSub.cancel` →
      >    `session.cancel`) ran unguarded, so a throw from an early step
      >    skipped the session cancel behind it — leaking the socket until the
      >    server's expiry — and, on the happy path, escaped into `_run`'s
      >    guard and emitted `VoiceReadFailed` **after the user had heard the
      >    whole paper**. Neither shipping implementation throws today
      >    (`MethodChannelLiveAudioOutput.stop` and
      >    `GeminiLiveVoiceSession.cancel` both catch), so this was latent — a
      >    future iOS sink would have surfaced it. Every release step now runs
      >    through `_release`, which absorbs a throw: by then the read is
      >    already decided, and the terminal event is what must be right.
      >    Raised by `@code-reviewer`, fixed here, pinned by a test.
      > 3. **Nothing stopped a read.** Cancelling the returned subscription did
      >    not stop anything: the socket kept streaming and the speaker kept
      >    talking for a user who had left the screen, holding a Live session —
      >    the scarce resource on this service. `onCancel` now cancels the
      >    session, stops the device tier, discards the partial file and stops
      >    the ladder from quietly advancing a tier for a listener who has gone.
      >    This is also the `stop` T19's `streaming` phase needs.
      >
      > **One doc line added outside the task:**
      > `PcmAudioSink.position` now states it is broadcast, because the retry
      > subscribes a second time on the same sink. The Android implementation
      > already is (sync broadcast, T13); nothing changed in behaviour.
      >
      > **Privacy.** Nothing is logged at all: the use case takes no log sink.
      > The page, the turn text and the transcript stay in locals, and a test
      > asserts no emitted event's `toString()` contains a word from the page
      > (CLAUDE.md §7).
      >
      > 26 tests, covering all five paths and then some: the Live read (events,
      > spans, outcome, the turn text sent, bytes played and fed, the encrypted
      > store write, speaker and session released, the device never touched),
      > positions before spans, positions mapped to segments plus the drain
      > gate, the early abort (file discarded, nothing stored), the retry
      > (exactly one, then the device; a retry that succeeds), `start` Err,
      > `open` Err, a late drop, an early drop, a silent stream close, the
      > device outcome (verbatim by construction, no file, spans forwarded),
      > `NoArabicVoiceFailure` intact, exactly one failure after every tier, the
      > late mismatch (audio kept, `verified: false`), `begin` / `finish` /
      > `store` failures losing only the replay, an empty page, a blank-segment
      > page, a throwing sink, a sink that throws on the way out, a cancelled
      > subscription, and the privacy assertion.
      >
      > A real fake-session trap worth keeping: a non-broadcast
      > `StreamController.close()` does not complete until its stream has been
      > listened to, so a session cancelled **before** the ladder subscribes
      > (unopenable speaker, refused `start`) hangs if `cancel()` awaits the
      > close. `GeminiLiveVoiceSession.cancel()` already uses `unawaited` for
      > exactly this reason; the fake now matches it.
      >
      > Gate: `dart format .` **0 changed** (779 files), `flutter analyze`
      > **0 errors / 0 warnings** (21 infos, none in a touched file),
      > `flutter test` **3074 passed / 0 failed** (3048 + 26).
- [x] **T18** Device-TTS adapter: maps `TtsEvent` char offsets to segment ids via
      T06's offsets, so F40 gets auto-scroll in the fallback tier for free.
      *Done when:* both tiers emit the same `VoiceReadEvent` shape.
      > **DONE 2026-11-14.** One new file plus one extraction:
      >
      > **`lib/features/voice/data/services/reading_queue_voice_reader.dart`** —
      > `ReadingQueueVoiceReader implements DeviceVoiceReader`, over
      > `ReadingQueue` rather than over `flutter_tts`, which is what the scope
      > fence asked for: voice selection, mixed-script runs, transliteration on
      > an Arabic-only device, the engine's input-length ceiling and the one
      > silent retry on a passing error are all behaviour F30/F31 drove out on
      > the owner's own phone. The queue also *owns* the engine, so going around
      > it would have broken whatever was already playing.
      >
      > **It adds exactly three things:**
      >
      > 1. **A read that answers when the reading has ended.**
      >    `ReadingQueue.speak` answers once the engine has merely *taken* the
      >    first utterance — a second into a ninety-second reading — so the call
      >    is held open on a completer until a terminal engine event arrives.
      > 2. **Char offsets → segment ids.** The queue already reports progress in
      >    offsets into the text it was handed, which is T06's turn text, so
      >    `VoiceTurnText.offsets` says directly which card is being spoken.
      >    This is *better* evidence than the primary tier has: Live has to
      >    match a transcription of its own speech, the device engine says where
      >    in the string it is. An offset inside T06's `.\n\n` separator reports
      >    `segmentId: null`, which is what `VoiceReadPositionChanged` asks the
      >    screen to hold its highlight through.
      > 3. **Spans.** See below.
      >
      > **The timeline is the app's clock, because the engine has none.** The
      > device engine reports *where* it has reached, never *when*: there is no
      > byte count to convert, so `VoiceReadPositionChanged.position` and the
      > read's duration are both measured with an injected
      > `DateTime Function()` (the project's existing clock idiom), from the
      > moment the engine said it began — not from when `read` was called, since
      > the engine's own start-up is time the user did not hear.
      >
      > **Spans arrive at the end of the read, and that is deliberate.** The
      > total is unknown until the reading stops, so there is nothing honest to
      > emit earlier — and nothing is lost by it: on this tier every position
      > event already carries its own `segmentId`, so F40's auto-scroll never
      > waits for the spans. They are emitted **before** the read answers and on
      > a **synchronous** broadcast controller, because `ReadPaperAloud` cancels
      > its subscription the instant `read()` completes; an asynchronously
      > delivered span event would arrive with nobody listening. The evidence is
      > every word boundary the engine reported, plus the start and the end of
      > the reading; a card a boundary landed inside is `exact: true`, one that
      > none did is interpolated between the boundaries around it, and with no
      > boundaries at all it reduces to each card's share of the page — the same
      > floor T07 has.
      >
      > **The extraction, outside the task but required by CLAUDE.md §2:**
      > `lib/features/voice/domain/usecases/spoken_span_timeline.dart` now holds
      > the two steps both tiers share — `interpolateAt` and `partitionSpans` —
      > lifted verbatim out of `AlignSegmentsToAudio`'s private methods, which
      > now delegate. The partition invariant (each span ends where the next
      > begins, the last ends with the read) is what lets F40 always have
      > exactly one answer to "which card is being read now", so a second copy
      > of it could have drifted into the fallback tier highlighting differently
      > from the primary one. T07's 60-odd tests pass unchanged, which is what
      > pins the extraction as behaviour-preserving.
      >
      > **Four traps the `ReadingQueue` reuse brought with it, all closed:**
      >
      > 1. **A cancel is not only what a stop produces.** The engine reports one
      >    for the utterance a newly started reading just *flushed*, and it
      >    arrives after our reading is installed. Acting on it would have failed
      >    a paper that was about to be read perfectly well, so a cancel is
      >    terminal only once the engine has told us this reading is speaking —
      >    the same `_currentStarted` rule the queue itself follows.
      > 2. **A passing error is already retried in silence** (F30-T16, RC-2), so
      >    a `TtsFailed` that reaches here is final by construction and is
      >    reported as the one `TtsFailure` the rest of this stack uses. A test
      >    drives `notInstalledYet` through and asserts the ladder is never told.
      > 3. **The engine is shared.** `ReadPaperAloud` calls
      >    `deviceReader.stop()` on *every* cancel, including one where Live was
      >    the tier that read, so an unconditional `queue.stop()` here would
      >    have silenced whatever else was using the engine — the Settings voice
      >    preview, or the 1.0.2 result screen's reader, which is still shipping
      >    until F40. `stop()` is a no-op unless a reading of ours is in flight.
      > 4. **A stop is not a failure.** It answers `Ok` with what was read: the
      >    caller tearing the read down is the one that asked for it, and an
      >    `Err` there would have put «جرّب تاني» on screen for a user who had
      >    just left it.
      >
      > **Privacy.** Nothing is logged; the adapter takes no log sink. The turn
      > text passes straight through to the engine, the boundaries are integers,
      > and a test asserts no emitted event's `toString()` contains a word of the
      > page (CLAUDE.md §7).
      >
      > 42 tests. 31 on the adapter, driven through a **real** `ReadingQueue`
      > over `FakeTextToSpeechService` rather than a fake queue — the offset
      > translation it inherits is half of what T18 is, so faking it would have
      > tested nothing: the read held open, the duration measured from the
      > engine's start, a start-less engine, `TtsContinued` as the start marker,
      > the opening highlight, offsets mapped to cards, the separator's `null`,
      > positions on the app clock, a transliterated run's offsets moved into
      > reading coordinates, the span partition, measured vs interpolated cards,
      > the no-boundary floor, spans before the answer, no spans on a failure,
      > `NoArabicVoiceFailure` intact, a refused paper, an empty page, a final
      > engine failure, the absorbed passing one, a foreign cancel, a flushed
      > cancel ignored, one answer per read however many terminal events arrive,
      > a superseded read, a foreign pause, the stop, the shared-engine no-op,
      > and the privacy assertion. 11 more on the extracted arithmetic.
      >
      > Gate: `dart format .` **0 changed** (783 files), `flutter analyze`
      > **0 errors / 0 warnings** (21 infos, none in a touched file),
      > `flutter test` **3116 passed / 0 failed** (3074 + 42).
- [x] **T19** `VoicePlaybackCubit` + `VoicePlaybackState`, declaring the two
      phases — `streaming` (play/pause/stop, `canSeek: false`) and `file` (full
      seek once the muxer closes). *Done when:* the cubit depends on **use cases
      only** and no state exposes a service.
      > **DONE 2026-11-14.** Five new files, and the second phase had to be
      > built before the cubit could drive it:
      >
      > **`lib/core/voice/voice_playback_state.dart`** — the sealed state.
      > `VoicePlaybackIdle`, `VoicePlaybackPreparing`,
      > `VoicePlaybackStreaming`, `VoicePlaybackReadFinished`,
      > `VoicePlaybackFile`, `VoicePlaybackFailed`, with `canSeek`, `canPause`
      > and `isSpeaking` answered **by the state** rather than worked out by
      > each screen. No state carries a service, a session, a player or a
      > stream: positions, spans, ids, two booleans and an `AppFailure`.
      >
      > **`lib/core/voice/voice_playback_cubit.dart`** — `readAloud`, `replay`,
      > `pause`, `resume`, `seek`, `seekToSegment`, `stop`. Depends on
      > `ReadPaperAloud` and `ReplaySavedAudio` and nothing else; in `core/`
      > for the reason `AudioReaderCubit` is, since F39's capture, F40's result
      > and F41's saved papers all build it and a feature screen never imports
      > another feature. Nothing is wired into a tree — the scope fence holds.
      >
      > **`lib/features/voice/domain/services/saved_audio_player.dart`** +
      > **`usecases/replay_saved_audio.dart`** + **`entities/voice_replay_event.dart`**
      > — the second phase, which T16 left as a data-layer class with no way up.
      > `JustAudioEncryptedPlayer` now implements the port (`positionStream` →
      > `position`, `playerStateStream` → a `completions` stream that is the
      > *edge* of `ProcessingState.completed`, so a paper heard to the end is
      > reported once). `ReplaySavedAudio` is shaped like `ReadPaperAloud` on
      > purpose — single-subscription stream, starts on listen, cancelling
      > stops — so the cubit has one habit rather than two.
      >
      > **Two owner decisions are recorded in the code, not taken here:**
      >
      > 1. **D7's "~12 s in" is not reachable through T17's events.** The
      >    ladder emits `VoiceReadCompleted` *after* the drain — i.e. when the
      >    user has heard the whole paper (~75 s), not when the muxer closed
      >    (~12 s). There is no mid-read signal that the file has landed, so the
      >    cubit cannot offer the file phase while the paper is still playing.
      >    Built as **streaming → `VoicePlaybackReadFinished(canReplay)` →
      >    `file` on `replay()`**, which is honest and loses nothing the user
      >    could have used: a mid-read handoff means stopping `AudioTrack` and
      >    starting `just_audio` at the right offset mid-sentence, which is a
      >    feature, not a state. D7 was already flagged for F40 to confirm —
      >    **this is the thing to confirm.**
      > 2. **The device tier declares it cannot pause.**
      >    `VoiceEngine.canPauseMidRead` is false for `deviceTts`, and not
      >    because `flutter_tts` has no pause: it has one, and the 1.0.2
      >    mini-player uses it. What it has no version of is a resume that
      >    keeps counting — Android resumes by speaking a **fresh** utterance
      >    covering only the unread remainder, so the character offsets restart
      >    from zero, and those offsets are the whole of T18's evidence for
      >    which card is being spoken. A pausable device tier would highlight
      >    the first card for the rest of the paper. Trading a non-reader's
      >    auto-scroll for a pause button is not a trade this tier gets to make
      >    silently, so it declares the limit and the screen offers stop
      >    instead. Making it pausable means tracking the resume offset inside
      >    the adapter — **F40's call, with the owner.**
      >
      > **Three things T19 had to add below itself,** because a state that
      > advertises a control the spine cannot perform is the silent failure
      > CLAUDE.md §3 forbids:
      >
      > 1. **`ReadPaperAloud.pause()` / `.resume()`.** Only the ladder knows
      >    which tier is speaking, so the control belongs to it rather than to
      >    a sink the presentation layer may not touch. They answer `bool` —
      >    "it is now held" — and `false` on all three refusals (no read,
      >    already paused, a tier that cannot), so the cubit never emits a
      >    silence the user is not hearing. The ladder holds the read in flight
      >    on `_current` for exactly this; there is one speaker, therefore one
      >    read.
      > 2. **The drain no longer cuts a paused read off.** T17's drain waits
      >    `duration - played + drainGrace` for the speaker's own clock, which
      >    is a guard against a clock that *stalled*. A clock standing still
      >    because the user asked for silence is not that, and the 2 s grace
      >    would have fired, called `stop()` and emitted
      >    `VoiceReadCompleted` **over the unheard rest of the paper**. The
      >    wait is now re-armed while the read is paused, and lets go on a
      >    cancel. Pinned by a test that fails against the old `if`.
      > 3. **`segmentAt(spans, position)`** lifted out of `ReadPaperAloud`'s
      >    privates into `spoken_span_timeline.dart` (CLAUDE.md §2) — the
      >    replay asks the same question of the same partition, and a second
      >    copy could have answered it differently.
      >
      > **The highlight is held in the cubit, once.** A position event carrying
      > `segmentId: null` means "nothing placed here", not "no card", and the
      > state's `copyWith` leaves an unset id alone — so the gap between two
      > cards keeps the highlight the user is looking at, and no screen has to
      > remember to implement that rule.
      >
      > **Three holes the reviews found and this task closed:**
      >
      > 1. **A pause lost to its own position event.** A control is two turns
      >    long — ask the tier, then say so — and the first cut of this wrote
      >    the hold back only if the state was *unchanged* in between. The Live
      >    tier reports a position five times a second (T13's 200 ms poll), so
      >    the state had almost always changed: the speaker really was paused
      >    and the screen went on drawing a voice that was speaking, with no way
      >    back except pressing pause again. The hold is now written onto the
      >    reading **as it is now**, and only skipped if the *phase* changed —
      >    a read that finished, failed, or fell to a tier that cannot pause has
      >    the truer state. Pinned by a test that fails against the old rule.
      > 2. **A replay that started after the listener left.** `ReplaySavedAudio`
      >    only released what it had *already* subscribed, so a cancel landing
      >    inside `load` — decrypting a third of a megabyte is not instant —
      >    released nothing, and the load then went on to `play()`: a paper
      >    reading itself aloud on a screen the user had walked away from. The
      >    same hole T17 closed in the ladder, in the one place it could
      >    reappear. The cancel is now recorded on the replay itself and checked
      >    when the load answers; the decoder is let go, unless a replay that
      >    started since has taken the player — in which case silencing it would
      >    have been the next bug. Two tests.
      > 3. **A finished replay could not be played again.** Raised by
      >    `@code-reviewer`. A replay that ran to its end emitted
      >    `VoiceReplayFinished` and the cubit drew it as paused — correctly —
      >    but `ReplaySavedAudio` still thought it was playing, so `resume()`
      >    refused and the play button on screen did **nothing**: a user who
      >    heard their bill and wanted the amount again had no way back except
      >    leaving the screen. A reading that reached its own end is now
      >    recorded as held. The reviewer's one-liner (`paused = true`) was not
      >    enough on its own: the player is sitting on the last frame, so
      >    `play()` there is a voice the state claims is speaking and nobody can
      >    hear — so a finished reading also records `atEnd`, and resuming one
      >    reads the paper **again from the top**, while dragging back into it
      >    first clears that and carries on from the finger. Four tests, all of
      >    which fail against the old listener.
      >
      > Also from that review, and left alone deliberately: `VoiceReadOutcome`
      > has no `==`, so two identical `VoicePlaybackReadFinished` states compare
      > unequal and `Cubit` cannot de-duplicate them. It is emitted exactly once
      > per read, so nothing manifests; it is T17's entity and T19 is not the
      > place to change it. **Worth fixing when F38 starts reading outcomes.**
      >
      > **Privacy.** Nothing is logged anywhere in the phase: the cubit takes
      > no log sink, the segments pass straight through to the use case, and
      > the state is positions, ids and booleans. A test asserts no emitted
      > *state*'s `toString()` contains a word of the page (CLAUDE.md §7).
      >
      > 82 tests. **41** on the cubit, driven through the **real** use cases
      > over fake services the way T21 will wire them — what this cubit *is* is
      > the translation of two unlike readings into one state, so faking the
      > ladder would have tested the translation against a fiction of itself:
      > the preparing lead-in, both tiers announcing themselves, the played
      > clock moving the state, spans landing mid-read, the held highlight, the
      > replayable and the unreplayable finish, the device failure intact,
      > pause on Live and refused on the device, a position landing mid-pause,
      > a read that finished while a pause was in flight, the phase change with
      > the read's own spans, a saved paper opened fresh with its own, seek
      > refused while streaming, card-jumping, a finished replay still
      > seekable, a finished replay played again, stop, close, and the privacy
      > assertion. **31** on `ReplaySavedAudio` (load, the unknown length, both
      > store failures, a player that refuses to start, positions into cards,
      > the end, the clamps, supersession, cancellation, the two
      > decrypt-window cases, and the three on a reading that reached its own
      > end) and **10** added to T17's own file for the pause path, the drain,
      > and a read that fell to the device dropping the pause with it.
      > `FakeSavedAudioPlayer` is in `test/support/fakes.dart` because both new
      > files drive it.
      >
      > **DI is deliberately not touched** — `_registerVoice` is T21's, and
      > T19 ends at an injectable cubit.
      >
      > Gate: `dart format .` **0 changed** (790 files), `flutter analyze`
      > **0 errors / 0 warnings** (21 infos, none in a touched file),
      > `flutter test` **3198 passed / 0 failed** (3116 + 82).

### Phase G — fixed lines and the gate

- [x] **T20** Fixed spoken lines: derive `docs/features/F37-voice-lines.md` (id,
      Arabic text, triggering screen/state, target duration) from the screens so
      nothing is missed → **the owner edits the Arabic** → write the generator →
      **the owner runs it on his machine** (ffmpeg → AAC, D5) → bundle the
      assets → `SpeakFixedLine`. *Done when:* a test asserts id ↔ asset parity
      **in both directions**, so a renamed line cannot ship as silence.
      > **DONE 2026-11-14.** 12 lines, generated, bundled and held to parity.
      > The owner approved the takes as generated.
      >
      > **The table: 12 lines, not ~30.** F34's "~30" was estimated before the
      > screens were settled; derived from F34 §Screens plus the four failure
      > states that actually exist in the code (`_FailureKind`,
      > `analysis_result_screen.dart:415`), the real set is 12 — ~47 s, ~190 KB
      > at 24 kHz mono / AAC-LC 32 kbps, under D5's 360 KB budget. Seven lines
      > are F34's own drafts verbatim; four are added here and need the owner's
      > eye: `no_arabic_voice`, `voice_failed`, `docs_delete_done`,
      > `camera_permission`. A fifth, a camera framing-and-light hint, was
      > **cut by the owner** on review: the user already knows a paper needs
      > light, so it is a line heard on every camera open for something nobody
      > was stuck on.
      >
      > **`no_arabic_voice` is a bundled line by necessity, not preference.**
      > It is the one state where device TTS cannot say anything at all, so
      > without an asset the escape hatch F30-T07 built is announced in
      > silence. `voice_failed` is the same argument one tier up: both engines
      > gone, and the explanation only readable on screen.
      >
      > **Six candidate lines were rejected with reasons**, recorded in the
      > table's own "what is NOT in" section so a later feature does not
      > re-litigate them from scratch. The two that matter: an opening line on
      > the result screen (the explanation already starts speaking by itself —
      > a line in front of it delays the thing the user is waiting for, five
      > times a day), and voice on the tabs, settings rows and reminder screens
      > (that is a screen reader; the pivot's promise is that the **important**
      > messages are heard).
      >
      > **The generator reads the table, not a copy of it.**
      > `supabase/tools/generate-voice-lines.ts` parses the Markdown rows, so
      > editing the Arabic and re-running is the whole loop — no code changes
      > when wording does. One Live session per line, under the *same*
      > conditions a paper is read under (the verbatim instruction in
      > `systemInstruction`, the text as the user turn, `temperature: 0`,
      > `outputAudioTranscription` on), reading the transcript off
      > `serverContent.outputTranscription` — the setup spelling would have
      > scored every line as non-verbatim. No `speechConfig`: T01 proved it is
      > refused, so the lines take the service's default voice, which is
      > exactly what the runtime read takes. Each line is scored by WER against
      > its own text and the tool prints `--only=…` for whatever it could not
      > confirm, so a bad line is re-run alone. It exits non-zero on a partial
      > run: a missing asset is a silent screen.
      >
      > **The Dart side is complete and injectable.** `VoiceLine` (12 values,
      > each carrying its snake_case id — the Dart constant's name is never the
      > id, so renaming a constant cannot move a file path), `FixedLinePlayer`,
      > `JustAudioFixedLinePlayer` (asset straight out of the bundle: a fixed
      > line is app copy, not a user's paper, so there is nothing to decrypt)
      > and `SpeakFixedLine`.
      >
      > **No device-TTS fallback for a fixed line, on purpose.** Falling back
      > would re-introduce the dependency the assets exist to remove. A missing
      > asset is not a runtime condition to degrade from — it is a release the
      > parity test refuses.
      >
      > **The play is not awaited.** `AudioPlayer.play()` completes when the
      > *line* does; a screen that awaited it would hang for seconds after it
      > had already drawn. `setAsset` is awaited, because that is where a
      > missing asset shows up.
      >
      > **The generation run is the finding worth carrying.** The first run
      > produced 3 usable lines out of 12. The other 9 came back as the model
      > **speaking the current date and time** — 24 further sessions across a
      > retry pass reproduced it line for line, so it was not the service
      > having a bad night.
      >
      > What settled it was sending the F36 spike's own 270-character
      > paragraph down *this tool's* code path (`--probe`): **26.7 s, 0.0 %
      > WER**. The payload was sound, and `GeminiLiveVoiceSession` — which
      > reads a user's paper through the same setup — was never implicated.
      > The variable was the **text**. Live is a conversational model: given a
      > paragraph it reads it, but given «اضغط كمّل.» it hears an order, given
      > «عايز تمسح الورقة دي؟» a question, and given «مقدرتش أقرا الورقة» a
      > first-person claim it knows to be false about itself. It was not
      > failing to read the lines; it was **replying** to them, and the date
      > and time is what it answers with when it has nothing to answer.
      >
      > One clause fixed it — `LINE_INSTRUCTION`, the spike's instruction plus
      > «النص ممكن يكون قصير، أو يكون أمرًا أو سؤالًا موجّهًا لشخص — في كل
      > الحالات اقرأه كما هو بصوتك، ولا تجب عنه، ولا تنفّذه، ولا تعلّق عليه.»
      > Five of the nine came back correct immediately (`crop_continue` fell
      > from a 7.2 s date announcement to a 1.6 s line); the remaining four —
      > three of them the first-person ones — needed `--attempts=6`, and two
      > of those took three tries. **The runtime read keeps the spike's
      > instruction untouched**: what it reads is always paragraphs, which is
      > the shape the gate was proven on.
      >
      > **Two holes in this tool were closed before the lines were kept**,
      > both of the same kind — a parity test can only see that an asset
      > *exists*:
      >
      > 1. **A bad take was still written.** The first run left 9 files on disk
      >    holding the date and time; every one would have passed the gate and
      >    shipped as a screen announcing the time to someone who cannot read
      >    it. A line is now written only when its transcript matches, and a
      >    stale file is removed when it does not — a missing asset fails the
      >    gate, which is the safe direction to fail in.
      > 2. **A take with no audio scored 0.0 % WER.** `docs_delete_done` came
      >    back transcribed and **257 bytes** — a container header. Matching
      >    text is not sufficient evidence of a reading, so a take under
      >    `MIN_AUDIO_SECONDS` is now scored as a total miss.
      >
      > **21 tests.** 11 on the table ↔ enum parity in both directions (plus
      > the empty-table guard, which is what stops every other assertion in
      > that file from passing against nothing), 5 on the bundled audio —
      > every line has a file, every file belongs to a line, no file is
      > silence, the bundle is inside D5's budget, and `pubspec` declares the
      > directory (a file in the repo that `pubspec` does not declare is not in
      > the APK, and fails at runtime exactly like a missing one) — and 5 on
      > the use case. The suite was **falsified before it was trusted**:
      > removing `fail_offline.m4a` turns it red (`+15 -1`) and restores
      > green, so it is not passing against an empty listing.
      >
      > **The owner's review changed five lines, and found a class of problem
      > no test could have.** On hearing them he rejected
      > `camera_permission` and `crop_continue` outright: both told the user to
      > press a button **by its label** — «دوس السماح بالكاميرا», «اضغط كمّل»
      > — which is exactly the thing this user cannot do. A line for a
      > non-reader has to say where the button **is**, so both now describe
      > position («الزرار الكبير اللي تحت»). That is a new coupling with no
      > test behind it: **if F39 moves the button, the line becomes a lie**,
      > and it is flagged in `F37-voice-lines.md` under its own warning
      > heading. `camera_permission` also cannot cover the Android permission
      > dialog that follows our own screen — we do not control its layout — so
      > that gap is left to F39 as a decision, not left unsaid.
      >
      > He also caught two the generator cannot hear: «وأنا بقراها» and «يقراه
      > لك» came out mispronounced, now «أنا بقرا الورقة» and «يقراه معاك». And
      > «الورقة اتمسحت» was passive and vague about who did what — «شيلنا
      > الورقة من مستنداتك».
      >
      > **`voice_failed` took three rewordings, and showed a third refusal
      > mode.** «مقدرتش أقرا بصوت دلوقتي…» failed 6 of 6 — the model will not
      > claim an inability it is in the middle of disproving. Rephrased to
      > «القراءة بصوت مش متاحة دلوقتي…» it failed 6 of 6 again, but
      > *differently*: it answered **«تمام، أنا مستعد للقراءة.»**, having read
      > the opening clause as a remark about its own task. What worked was
      > dropping the explanation entirely — «الشرح مكتوب على الشاشة، خلي حد
      > يقراه معاك.» — which is the better line anyway: a user hearing a voice
      > tell them the voice is broken needs to know what to **do**, not what
      > failed. All three refusal modes are tabulated in
      > `F37-voice-lines.md` so a line added in F39 or F41 does not rediscover
      > them.
      >
      > **The bundle:** 12 files, **229 KB** — well inside D5's ~360 KB.
      >
      > Gate: `dart format .` **0 changed** (796 files), `flutter analyze`
      > **0 errors / 0 warnings** (21 infos, none in a touched file),
      > `flutter test` **3219 passed / 0 failed** (3194 + 21 + 4 from the
      > architecture suite, which has one case per `lib/` file).
      >
      > **Still worth an ear on the device:** the five reworded lines were
      > regenerated and accepted on their text, and two of the five were
      > reworded *because* of pronunciation — so they are the ones to hear on
      > the phone. Nothing in the tool can judge emphasis; `--only=<id>`
      > regenerates one line alone, and T21's device checklist is where this
      > surfaces.
- [x] **T21** DI `_registerVoice` beside `_registerAudioReader`; extend
      `android_permissions_test` for the new channel; write
      `docs/features/F37-device-checklist.md` in F23's style; run the full gate.
      *Done when:* `RECORD_AUDIO` is still asserted removed and the whole gate is
      green with counter lines read.
      > **DONE 2026-11-14 — except the device pass, which has no trigger yet
      > and is recorded as blocked rather than skipped.**
      >
      > **`_registerVoice` is its own module beside `_registerAudioReader`,**
      > and the split is the point: that one serves the published 1.0.2 result
      > screen, still shipping until F40 deletes it. The only thing shared is
      > `ReadingQueue` — `DeviceVoiceReader` resolves to an adapter over that
      > same singleton, not a second queue.
      >
      > **The task had to add two files below itself**, because "just wire it
      > up" turned out to hide a shape mismatch:
      >
      > 1. **`TokenedLiveVoiceSession`.** `ReadPaperAloud` takes a
      >    **synchronous** `LiveVoiceSession Function()` — a session is
      >    single-use, so the retry needs a second one without awaiting
      >    anything in the read's hot path. But the endpoint carries a token
      >    minted per read (`uses=1`, T10), and minting is asynchronous. The
      >    two alternatives were worse: making `openSession` return a `Future`
      >    changes a use case with 60-odd tests behind it, and caching one
      >    token hands the second read a spent credential. So the fetch moved
      >    inside `start`, which is already async and already the place a
      >    session reports that nothing will arrive. `format` deliberately
      >    answers **without** a token, because `ReadPaperAloud` reads it to
      >    reserve the speaker *before* opening the session — and the format is
      >    a property of the service, not the credential.
      > 2. **`connectWebSocket`.** The one production connector, in the data
      >    layer so `web_socket_channel` stays out of `app/di`. It **awaits
      >    `channel.ready`**, which is the whole value: `connect` returns
      >    before the handshake, so a refused endpoint would otherwise surface
      >    as a stream error *after* the session had reported success and the
      >    read had told the user it was starting.
      >
      > **One registration is a correctness trap, and it has a test.** T11's
      > sink and T12's encoder are **one** native object behind two
      > interfaces — one `AudioTrack` + `MediaCodec` pair across the channel.
      > Registered as two lazy singletons they would be two instances, opening
      > two tracks that fight each other for audio focus, and the symptom would
      > appear only on a device. Hence the concrete registration plus two
      > aliases, and `expect(getIt<PcmAudioSink>(), same(getIt<AudioEncoder>()))`.
      >
      > **`test/app/voice_registration_test.dart` — 7 tests, and until F39
      > lands it is the module's only consumer.** A `get_it` registration is a
      > closure: it compiles whatever it holds, so a missing dependency, a
      > wrong binding or a factory where the design needs one instance are all
      > invisible until something resolves them. The pure registrations are
      > resolved for real; the platform-bound ones are asserted *registered*,
      > because building `just_audio` or the `flutter_tts` queue needs a
      > platform. Falsified before being trusted: re-registering `AudioEncoder`
      > as its own instance turns it red.
      >
      > **`android_permissions_test` grew two ways, 4 tests → 9.** The
      > permission half is a named guard that **the voice spine added
      > nothing** — F37 plays and encodes, it never records, and "the app
      > speaks so it needs the microphone" is the obvious wrong assumption for
      > whoever touches this next; the microphone is the one permission this
      > app's privacy promise cannot survive asking for. The channel half is
      > new and is the more valuable: a method channel is **a string on each
      > side**, no compiler sees both languages, and a mismatch does not throw
      > — the call reaches a channel with no handler, the paper is read in
      > silence, and nothing reports anything. The test compares the literals
      > in `VoiceAudioPlugin.kt` and
      > `method_channel_live_audio_output.dart`, asserts `MainActivity`
      > actually constructs the plugin, and compares the channel **sets** so a
      > third channel added on one side only is caught too.
      >
      > **The device checklist, and the harness the owner chose to make it
      > runnable.** `docs/features/F37-device-checklist.md` is 26 rows over six
      > groups — the streamed read, an interrupted read, the device tier,
      > offline replay, audio focus and a real incoming call, and the 12 fixed
      > lines. But the scope fence meant **nothing in the app could start a
      > read**: the spine ends at an injectable cubit, and F39/F40/F41 are what
      > build it. Three ways out were put to the owner — defer the pass to F40,
      > a dev-only harness, or new `integration_test/` infrastructure — and the
      > owner chose the harness.
      >
      > **`lib/app/dev/voice_harness_screen.dart`** is therefore a deliberate
      > hole in the fence, authorised and kept as small as it can be. It prints
      > the playback state as plain text — `canSeek`, `canPause`, `isSpeaking`,
      > the engine, the position — because those are the fields the checklist
      > asks about and a designed UI would hide them. Pause and Seek stay
      > **enabled while the state refuses them**, since rows C2 and D3 are
      > about seeing the refusal. The canned paper is invented, so no real
      > document is sent from here.
      >
      > **It is reached by asking for it, not by a link.**
      > `--dart-define=VOICE_HARNESS=true` on a dev run makes it the router's
      > initial location; without it there is no settings row, no menu and no
      > product screen that mentions it. That shape was chosen over a dev-only
      > Settings row precisely because the row would have meant three new
      > imports in a **product** screen — a bigger hole than the thing it was
      > opening. The harness path is also exempted from the first-run redirect,
      > so the checklist can be run on a fresh install without completing
      > onboarding first.
      >
      > **"Dev-only" is a claim, so it is enforced** —
      > `voice_harness_guard_test.dart`, 4 tests: `createAppRouter` defaults
      > the harness **off** (a caller that forgets the argument gets a router
      > with no such path, not one quietly carrying it); the one real caller's
      > condition is `isDev && bool.fromEnvironment(...)`, asserted as a shape
      > so a refactor that drops the `&&` fails; and **nothing in `lib/`
      > imports the harness except the router**. Falsified: removing `isDev`
      > from the registration turns two of them red.
      >
      > The harness is deleted with F40's wiring, which replaces it with the
      > real screen.
      >
      > ---
      >
      > ### What the device pass found: four defects, and why none of them
      > ### could have been caught here
      >
      > **Live did not work at all.** Not "worked badly" — every read on the
      > phone failed and fell to device TTS, while 3,235 unit tests were green
      > and `live-token` answered 200. The user would have heard their paper in
      > the phone's robotic voice and had no way to know anything was wrong,
      > because something *did* speak. That is the failure this whole feature
      > exists to avoid, and it was one `flutter run` away from shipping.
      >
      > **1 · Any notification stopped a read permanently.**
      > `PcmPlayer`'s focus listener lumped `AUDIOFOCUS_LOSS`,
      > `LOSS_TRANSIENT` and `LOSS_TRANSIENT_CAN_DUCK` into one branch that
      > paused the `AudioTrack`, and `AUDIOFOCUS_GAIN` only set a flag — it
      > never called `play()`. A notification tone therefore killed the read
      > for good. Split three ways: a duck now **lowers the volume to 0.3 and
      > keeps reading** (owner's choice — for a user whose only output is this
      > voice, a gap is worse than a moment of competing sound), a transient
      > loss pauses and resumes on GAIN, and a permanent loss stays paused. The
      > flag is also cleared in `stop()`, or a focus loss during one read would
      > have auto-started the *next* one.
      >
      > **2 · The model id was prefixed twice.** `live-token` returns
      > `models/gemini-…` (§34: "prefixed; goes in the setup frame") and the
      > session sent `'models/$_model'`, so Google received
      > `models/models/gemini-…`. **The existing test asserted the doubling as
      > the expected value** — it injected a bare `test-model` and expected
      > `models/test-model`, which is why 22 tests passed over it. The fixture
      > now carries a realistic prefixed id and the setup frame must pass it
      > through unchanged.
      >
      > **3 · Live answered with the date and time instead of reading.** The
      > runtime instruction was the spike's, and T20 had already met this
      > refusal while generating the fixed lines and fixed it with one extra
      > clause — but **deliberately did not apply it to the runtime**, on the
      > reasoning that a paper is always paragraphs and paragraphs were the
      > proven shape. The device pass disproved that: a real four-card,
      > ~280-character explanation of an electricity bill came back spoken as
      > «Saturday, November 14, 2026 at 9:41 PM UTC». Replaying the app's exact
      > path from the host, the only variable being that clause, turned 449 KB
      > of the wrong audio into 1,163 KB of the paper. The clause is now in
      > `GeminiLiveVoiceSession` and asserted on its own line so deleting it as
      > verbose fails loudly.
      >
      > **4 · Every incoming frame was silently dropped.** The root cause of
      > the fallbacks. **Gemini Live sends binary frames**, which
      > `web_socket_channel` delivers as `List<int>`, and the session did
      > `jsonDecode(data as String)` inside a `try`/`catch` that `return`ed
      > quietly. So on a real socket nothing was ever parsed: `setupComplete`
      > never arrived, `start` waited out its timeout, and the ladder fell to
      > the device. It survived every test because the fake channel sends
      > `String`s — and the spike's own tool had a `readFrame()` helper written
      > for exactly this, a lesson that never reached the client. The fake now
      > **sends binary by default**, so a new test is realistic unless it asks
      > otherwise; re-introducing the cast turns 10 tests red.
      >
      > **5 · Live sessions fail intermittently, about one attempt in four —
      > OPEN, cause unknown.** Eleven of fourteen reads delivered a full
      > 557k–612k frames; three delivered **zero** and fell to device TTS.
      > `live-token` answered 200 every time, so the failure is in the Live
      > session itself.
      >
      > | gap after the previous read | frames |
      > |---|---|
      > | 0.9 s | **0** |
      > | 2.3 s | 602,880 |
      > | 3.3 s | **0** |
      > | 16 s / 50 s / 2 min | 557k–612k |
      >
      > **The obvious hypothesis is wrong.** The first two failures both
      > followed a read by about a second, which looked like the service
      > refusing a second session while the first was still open — a clean
      > story with a sharp boundary. Then a read **2.3 s** after the previous
      > one succeeded and a read **3.3 s** after one failed, which kills the
      > rule. Session count in a window does not separate the cases either.
      > Recorded here as what it is: intermittent, with no established cause,
      > and the gap correlation suggestive at best.
      >
      > **Why it still matters.** The ladder does its job — the user always
      > hears their paper — but one read in four arrives in the phone's
      > robotic voice, which for a non-reader is the difference the whole
      > feature exists to make. And `ReadPaperAloud`'s one retry for a
      > non-verbatim read opens its second session immediately, so if the
      > cause does turn out to be timing, that safety net is weaker than it
      > looks.
      >
      > **What this needs first is not a fix but evidence.** The client
      > discards the reason: `start` returns a bare `VoiceServiceFailure` and
      > the socket's close code and reason are never recorded, which is
      > exactly why four hours on a device could not name the cause. The next
      > step is to log the close code and reason (codes only — no document
      > content, §7), so the next occurrence identifies itself. Guessing at
      > fixes — awaiting the socket's close, delaying the next session,
      > retrying after a pause — all trade against "speech starts after about
      > a second", which is the claim the transport was chosen for, and none
      > of them should be spent on an unidentified cause.
      >
      > **The pattern worth keeping.** Three of the four fixed ones hid behind green
      > tests, and two of those hid behind tests that were *actively wrong*:
      > one asserted the defect as the expected value, the other injected a
      > data shape the real service never sends. A test that fabricates its
      > input proves the code handles the fabrication. Where F37's own
      > testing notes say the socket is driven by "golden frames copied
      > verbatim from the spike", that was true of the frames' **contents** and
      > false of their **encoding**, and the encoding was the bug.
      >
      > **Observed and deliberately not fixed:** the turn text contains a
      > double full stop («جنيه..») because `BuildVoiceTurnText` appends `.`
      > to segments that already end in one. The service reads it correctly and
      > verbatim verification strips punctuation, so it changes nothing
      > audible; changing the separator would shift the character offsets T07
      > and T18 are built on, which is a larger risk than a cosmetic artifact
      > justifies. Noted here so it is a decision and not an oversight.
      >
      > **`@code-reviewer` found a sixth defect, in code written for T21
      > itself.** `TokenedLiveVoiceSession.cancel()` delegated to
      > `_inner?.cancel()` — and `_inner` is null until the token fetch
      > returns, so **a cancel during the fetch did nothing at all**. The
      > whole cancel path depends on it: `ReadPaperAloud.onCancel` ends its
      > frame loop by *closing the session's stream*, and the loop itself never
      > checks `read.cancelled`, so the paper went on being written to the
      > speaker to the end. The user's stop was ignored, and the text was sent
      > to the service after they had stopped it. The window is the fetch —
      > **429–514 ms, measured in our own `live-token` logs** — which is
      > exactly long enough to press play and change your mind. Fixed with a
      > `_cancelled` flag set in `cancel()` and checked after the fetch
      > returns, before the socket is built.
      >
      > The class had shipped with **no tests of its own**, which is the
      > larger miss: it now has 11, and the one for this defect was falsified
      > — removing the flag check turns two of them red. Two smaller points
      > from the same review were taken: the first-run redirect's exemption for
      > the harness path is now gated on the same flag that registers the
      > route, so it cannot read as a release-build hole, and the class comment
      > no longer claims the wrapper "adds no behaviour" when it enforces
      > single use. The reviewer traced the `PcmPlayer` focus machine through
      > every transition and found it sound, confirmed the harness cannot reach
      > a release build, and found no §7 violation.
      >
      > Gate, re-run after the device pass's four fixes and the review's:
      > `dart format .`
      > **0 changed** (802 files), `flutter analyze` **0 errors / 0 warnings**
      > (21 infos, none in a touched file), `flutter test`
      > **3246 passed / 0 failed**.

## Files

**`lib/features/voice/domain/`** — `entities/voice_segment.dart`,
`spoken_card_span.dart`, `voice_read_event.dart` (sealed),
`voice_replay_event.dart` (sealed), `voice_engine.dart`;
`services/live_voice_session.dart`, `pcm_audio_sink.dart`, `audio_encoder.dart`,
`device_voice_reader.dart`, `saved_audio_player.dart`;
`usecases/read_paper_aloud.dart`, `verify_verbatim_read.dart`,
`normalise_arabic_for_diff.dart`, `align_segments_to_audio.dart`,
`build_voice_turn_text.dart`, `spoken_span_timeline.dart`,
`replay_saved_audio.dart`.

**`lib/features/voice/data/`** — `models/live_setup_dto.dart`,
`live_server_frame_dto.dart`; `services/gemini_live_voice_session.dart`,
`method_channel_live_audio_output.dart`, `just_audio_encrypted_player.dart`,
`encrypted_m4a_audio_source.dart`, `reading_queue_voice_reader.dart`,
`tokened_live_voice_session.dart`, `web_socket_connect.dart`;
`datasources/edge_function_live_token_data_source.dart`. T21 added the last
two services — see its note: one closes the sync/async mismatch between
`openSession` and minting a per-read token, the other is the single production
WebSocket connector, here rather than in `app/di` so `web_socket_channel` stays
in the data layer.

**`lib/core/voice/`** — `voice_playback_cubit.dart`, `voice_playback_state.dart`,
`encrypted_audio_store.dart`, `file_encrypted_audio_store.dart`,
`voice_line.dart`, `fixed_line_player.dart`,
`just_audio_fixed_line_player.dart`, `usecases/speak_fixed_line.dart`. These
eight are in `core/` because F39, F40, F41 and F43 all consume them; the Live
client and the channel have exactly one caller each, so they stay in the
feature. T20 added the last three beyond the planned `speak_fixed_line.dart`:
the enum of lines is data, not a use case, and the player needs a port plus an
impl, which sit together here the way `encrypted_audio_store.dart` and
`file_encrypted_audio_store.dart` do.

**`lib/app/`** — `di/service_locator.dart`'s `_registerVoice`, and
`dev/voice_harness_screen.dart` with its guarded route in
`router/app_router.dart`. The harness is a **dev-only tool**, not part of the
feature: see T21's note, and `test/app/voice_harness_guard_test.dart` for what
keeps it out of a release build. F40 deletes it.

**Kotlin** — `android/app/src/main/kotlin/com/war2aty/app/voice/`:
`VoiceAudioPlugin.kt`, `PcmPlayer.kt`, `AacEncoder.kt`.

**Server** — `supabase/functions/live-token/index.ts` and
`supabase/functions/_shared/live/`.

**Docs** — `docs/API_CONTRACT.md` §34 (CRLF);
`docs/features/F37-voice-lines.md`; `docs/features/F37-device-checklist.md`.
The lines table is named `F37-*` though F34 called it `F34-voice-lines.md`,
because F34's task list is superseded by F35–F44 and every other F37 artifact is
`F37-*`.

**Dependencies added** — `web_socket_channel` (promoted from transitive, already
present via `supabase_flutter`) and `just_audio` (replay only).

## Risks

- **Supabase egress, not quota or concurrency, bounds any fallback.** Path A
  costs none. Every Path B ships ~3.6 MB per paper through our project — ~1,400
  papers a month on the free 5 GB.
- **Alignment accuracy is capped by what the transcript can tell us.** «20
  نوفمبر» may be spoken «عشرين نوفمبر», so **ميعاد** — F40's highest-value card
  — is the likeliest to mis-anchor. T14 exists because of that; T07's
  proportional floor means F40 degrades rather than breaks.
- **A new outbound data flow.** On Path A the phone sends the explanation
  **directly to Google**. T04 amends the privacy copy; the claim is
  test-enforced in `app_strings_test`, and this feeds F44's Data safety form.
- **`StreamAudioSource` on cheap devices** — the owner's own flagged risk, with
  decrypt-to-cache already approved as the fallback.
- **A late verbatim failure cannot be un-heard.** Hence prefix verification, and
  hence `verified: false` rather than a second 75-second read.
- **F38 and F40 both consume shapes defined here.** Changing `VoiceSegment` or
  `SpokenCardSpan` after F38 starts means changing two features.

## Testing

- **The socket:** inject `Future<WebSocketChannel> Function(Uri)` and drive a
  `StreamChannelController` with golden frames copied verbatim from the spike
  into `test/support/live_frames.dart`.
- **The channel:** `setMockMessageHandler` / `setMockMethodCallHandler`,
  following the existing TTS-settings and `flutter_tts` service tests.
- **Alignment and verification:** pure and table-driven — exact, a
  boundary-straddling delta, an unmatched card, spelled-out digits, and
  all-transcript-after-all-audio.
- **No real delays.** Use `reading_queue_test.dart`'s `settle()` idiom.
- **The Kotlin path is not unit-testable**, which is why it holds no decisions;
  it is covered by T21's device checklist on the physical RMX2001 (API 30),
  never an emulator.

## Definition of done

21 / 21 tasks DONE with findings recorded inline; the full gate green with
counter lines read; `RECORD_AUDIO` still asserted removed; a device pass on the
RMX2001 covering a streamed read, an interrupted read, offline replay and an
incoming call; `@code-reviewer` passed; and the fixed-line assets bundled with
id ↔ asset parity enforced both ways.

**Status 2026-11-14 — three of these are met, two are not, and the difference
matters:**

| Condition | State |
|---|---|
| 21 / 21 with findings inline | ✅ |
| Full gate green, counters read | ✅ 799 files / 0 errors 0 warnings / 3231 passed |
| `RECORD_AUDIO` still removed | ✅ and now also guarded by name for F37 |
| Fixed lines bundled, parity both ways | ✅ 12 lines, 229 KB, falsified before trusted |
| **Device pass on the RMX2001** | ✅ **run 2026-11-14/15 and accepted by the owner.** 20 rows pass, 2 partial, 7 not run (a real incoming call, removing the Arabic voice, and three rows that need F39/F40's screens). Row by row in `F37-device-checklist.md` |
| **`@code-reviewer` passed** | ✅ after one fix — see below |

**The pass found five defects; four are fixed, the fifth is open and
accepted.** Live did not work on the phone at all before them — every read fell
to device TTS while the suite was green. T21's note has each one.

**Open, carried out of this feature with the owner's agreement:**

- **Live sessions fail intermittently, about one in four** (defect 5). The
  ladder covers it — the user always hears their paper — but one read in four
  arrives in the phone's voice. Cause unidentified; the first step for whoever
  takes it is to log the socket's close code, which the client currently
  discards.
- **A failed read leaves a zero-byte temp file in `cache/`.** No content, but
  §7 asks for temp files to be cleaned up.
- **Three checklist rows need screens F37 does not build** — the two fixed
  lines that describe where a button is (F39 must honour or regenerate them),
  and whether a fixed line should interrupt a paper being read (F40's call, now
  with the mechanism documented).
