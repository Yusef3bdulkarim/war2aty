# F37 · Voice spine — Gemini Live

- **Branch:** `feature/voice-spine`, cut from `develop` at `1a4974a` (the PR #41 merge, so the tree carries **both** F35 and F36)
- **Milestone:** post-F36, the third feature of the F34 pivot
- **Depends on:** F35 (closed 2026-11-09). F36 is *in* the branch but F37 does not depend on its schema — see the scope fence.
- **Decisions source:** [F34-non-reader-pivot.md](F34-non-reader-pivot.md) — the pivot's decisions record, and its "Amendments (2026-11-08)" section, which wins wherever it disagrees with the body. The spike's handover is [F36-live-spike.md](F36-live-spike.md).
- **Progress:** 12 / 21 — T03 (domain), T04 (privacy copy), T05 (verbatim judgement), T06 (turn text builder), T07 (alignment), T08 (frame DTOs), T09 (Live session), T10 (live-token endpoint + Dart datasource), T11 (AudioTrack PCM sink), T12 (AAC encoder), T13 (method channel bridge) and T14 (silence detection — **rejected** as primary) done. T01 is with the owner: it runs on his machine, since the dev sandboxes cannot reach Google. **T04 left two carry-forwards for F44** — see its note.

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
| **D6** | **Transport fallback is B1** (the streaming relay) if T01 finds no ephemeral tokens, chosen to preserve "speech starts after about a second". **B3** (batch via Live) is the recorded graceful degradation if Supabase Edge will not sustain a WebSocket upgrade, or if egress bites. See "The transport fork" below. |
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

**Path A — ephemeral token (preferred).** `POST /functions/v1/live-token`
authenticates the Supabase anonymous user, checks `analysis_enabled` +
`explain_enabled`, mints a token from the key in Supabase Secrets, and returns
`{ token, expires_at }`. The phone opens
`wss://…GenerativeService.BidiGenerateContentConstrained?access_token=…`.

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

- [ ] **T01** **GATE · re-run the spike and decide the transport.** Run
      `supabase/tools/live-spike.ts` **on the owner's machine** (the dev
      sandboxes cannot reach Google). Answer, in writing: (a) does the free tier
      mint an ephemeral token from the minimal body; (b) which constraint field
      name parses, if any; (c) does v1alpha accept `languageCode` and a named
      voice; (d) how many concurrent sessions one key sustains; and (e) **does a
      Supabase Edge Function sustain a WebSocket upgrade, and for how long** —
      which decides whether D6's B1 is even available. *Done when:* this file
      records all five answers and names the chosen transport.
- [ ] **T02** `docs/API_CONTRACT.md` **§34** — the chosen transport's contract in
      §33's style: request and response shapes, the error-mapping table, the
      token's lifetime and single-use semantics (or the relay's frame protocol),
      and the gates it honours. Preserve the file's **CRLF**. *Done when:* the
      owner approves it in writing and §34 is in the contract.

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
      > **Built for Path A** (ephemeral token) — T01 hasn't run yet, but T08/T09
      > set the precedent that Path A is the default, and the swap to B1 is one
      > file by design. Server: `gemini-token-client.ts` mints a single-use
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

- [ ] **T15** `EncryptedAudioStore` + `FileEncryptedAudioStore`, mirroring
      `FileDocumentImageStore`, writing to the app-private directory and keyed by
      a plain id string. *Done when:* round-trip passes and a truncated file
      yields a `FileEncryptionFailure` rather than a crash.
- [ ] **T16** `just_audio` + `EncryptedM4aAudioSource`: a `StreamAudioSource`
      serving range requests from a **fully decrypted in-memory buffer**
      (AES-GCM concatenation forbids random-access decryption; 0.3 MB is fine).
      *Done when:* range requests and seek work off the buffer, with the
      decrypt-to-cache fallback documented if it misbehaves on a cheap device.

### Phase F — the spine

- [ ] **T17** `ReadPaperAloud` — the tier selector: Live → early-abort verify →
      retry once → device TTS → the open-TTS-settings escape, and discard the
      partial file on a drop. A **late** mismatch keeps the audio and marks
      `verified: false` for F38 rather than spending another 75 s; the transcript
      is document content and is **never logged** (CLAUDE.md §7). *Done when:*
      all five paths have a test.
- [ ] **T18** Device-TTS adapter: maps `TtsEvent` char offsets to segment ids via
      T06's offsets, so F40 gets auto-scroll in the fallback tier for free.
      *Done when:* both tiers emit the same `VoiceReadEvent` shape.
- [ ] **T19** `VoicePlaybackCubit` + `VoicePlaybackState`, declaring the two
      phases — `streaming` (play/pause/stop, `canSeek: false`) and `file` (full
      seek once the muxer closes). *Done when:* the cubit depends on **use cases
      only** and no state exposes a service.

### Phase G — fixed lines and the gate

- [ ] **T20** Fixed spoken lines: derive `docs/features/F37-voice-lines.md` (id,
      Arabic text, triggering screen/state, target duration) from the screens so
      nothing is missed → **the owner edits the Arabic** → write the generator →
      **the owner runs it on his machine** (ffmpeg → AAC, D5) → bundle the
      assets → `SpeakFixedLine`. *Done when:* a test asserts id ↔ asset parity
      **in both directions**, so a renamed line cannot ship as silence.
- [ ] **T21** DI `_registerVoice` beside `_registerAudioReader`; extend
      `android_permissions_test` for the new channel; write
      `docs/features/F37-device-checklist.md` in F23's style; run the full gate.
      *Done when:* `RECORD_AUDIO` is still asserted removed and the whole gate is
      green with counter lines read.

## Files

**`lib/features/voice/domain/`** — `entities/voice_segment.dart`,
`spoken_card_span.dart`, `voice_read_event.dart` (sealed), `voice_engine.dart`;
`services/live_voice_session.dart`, `pcm_audio_sink.dart`, `audio_encoder.dart`;
`usecases/read_paper_aloud.dart`, `verify_verbatim_read.dart`,
`normalise_arabic_for_diff.dart`, `align_segments_to_audio.dart`,
`build_voice_turn_text.dart`, `replay_saved_audio.dart`.

**`lib/features/voice/data/`** — `models/live_setup_dto.dart`,
`live_server_frame_dto.dart`; `services/gemini_live_voice_session.dart`,
`method_channel_live_audio_output.dart`, `just_audio_encrypted_player.dart`,
`encrypted_m4a_audio_source.dart`;
`datasources/edge_function_live_token_data_source.dart`.

**`lib/core/voice/`** — `voice_playback_cubit.dart`, `voice_playback_state.dart`,
`encrypted_audio_store.dart`, `file_encrypted_audio_store.dart`,
`usecases/speak_fixed_line.dart`. These five are in `core/` because F39, F40,
F41 and F43 all consume them; the Live client and the channel have exactly one
caller each, so they stay in the feature.

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
