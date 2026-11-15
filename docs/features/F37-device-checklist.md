# F37 · Device Test Checklist (T21)

The owner tests on the phone; Claude prepares the backend and switches the
server-side conditions between scenarios. Every row says who does what, how the
condition is produced, and what must be **heard** — this is the first checklist
in the project where the pass criterion is sound, not pixels.

- **Device:** physical RMX2001 (Android 11), over USB with `adb reverse`. Never
  an emulator: emulators fake audio focus, and three of the scenarios below are
  about what happens when focus is taken away.
- **Build:** `--flavor dev -t lib/main_dev.dart`, branch `feature/voice-spine`.
- **Headphones:** not used. Two scenarios depend on the phone's own speaker
  losing focus to a call.

## How to open it — the harness

**Owner's decision, 2026-11-14: option B.** A dev-only harness screen was
built, so every row below is runnable now.

```
flutter run -d <RMX2001> --flavor dev -t lib/main_dev.dart \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=VOICE_HARNESS=true
```

The app **opens straight on the harness**. Drop `VOICE_HARNESS` and it is an
ordinary dev run with no trace of it — no settings row, no menu, no link from
any product screen.

It shows the playback state as plain text (`canSeek`, `canPause`, `isSpeaking`,
the engine, the position), a button per control, and a button per fixed line.
The state is printed rather than styled on purpose: the rows below ask about
exactly those fields, and a designed UI would hide the thing under test.

Pause and Seek stay **enabled even when the state refuses them** — rows C2 and
D3 are about seeing the refusal, and a greyed-out button would hide it.

Two guarantees, both test-enforced in `voice_harness_guard_test.dart`:

- `createAppRouter` defaults the harness **off**, so a caller that forgets the
  argument gets a router with no such path at all.
- The one real caller requires `isDev` **and** the dart-define, so no define
  can conjure it in a release build.

The harness is deleted with F40's wiring, which replaces it with the real
screen.

## Why it was needed — the original problem

F37's scope fence is explicit: **no screen, route or widget**. The spine ends at
an injectable `VoicePlaybackCubit` and a `SpeakFixedLine`, and F39/F40/F41 are
what build them into a tree. So as this branch stands, **nothing in the app can
start a read**, and every scenario below is unrunnable — not because the code is
unfinished, but because it has no caller.

Three ways out, for the owner to choose:

| Option | What it costs | What it gives |
|---|---|---|
| **A · Run this checklist inside F40** | Nothing now; T21 closes on the gate alone and the device pass moves to F40, where the result screen is the trigger | The real thing, tested the way users meet it — but the Kotlin path stays unexercised on a device for two more features, and a bug found there is a bug found far from the code that caused it |
| **B · A dev-flavor-only harness screen** | ~half a task. Three buttons: read a canned paper, replay it, speak a fixed line. Registered only when `env.isDev`, so it cannot reach a release build | The pass happens now, against the code just written. Costs a deliberate hole in the scope fence |
| **C · A device integration test** (`integration_test/`, run with `flutter test -d <device>`) | More than B: the project has no `integration_test/` set-up at all, so this is new infrastructure | Repeatable and automatic afterwards; but it drives the spine, not a user, so the incoming-call and audio-focus rows below still need a human |

**B was chosen.** The four scenarios this checklist exists for — a streamed
read, an interrupted read, offline replay, an incoming call — are all about the
**native** layer, the one part of F37 with no unit test behind it by
construction. Deferring them to F40 would mean the first time `AudioTrack`,
`MediaCodec` and audio focus run on a real phone, they run underneath a new
screen, and any failure is ambiguous between the two. The harness keeps the
variables separate.

## 0 · Setup (Claude)

| Step | What | State |
|---|---|---|
| 0.1 | Docker + `supabase start` | |
| 0.2 | `supabase functions serve --env-file supabase/.env` — **required**: the local stack serves no Edge Functions without it, and `live-token` is one | |
| 0.3 | `adb reverse tcp:54321 tcp:54321` | |
| 0.4 | Local DB: `analysis_enabled = true`, `explain_enabled = true` | |
| 0.5 | `GEMINI_API_KEY` present in `supabase/.env` — the token endpoint mints from it | |
| 0.6 | `flutter run -d <RMX2001> --flavor dev -t lib/main_dev.dart --dart-define=SUPABASE_URL=http://127.0.0.1:54321` | |
| 0.7 | Owner: an Arabic TTS voice **installed** on the phone (needed by C and D) | |

## A · A streamed read (Gemini Live)

**Condition:** everything up. The paper is a canned Arabic explanation of
several paragraphs.

| ID | Do | Expect |
|---|---|---|
| A1 | Start the read | Speech begins within **about a second**, not after the whole file has arrived. This is the spike's central claim and the reason the transport is what it is |
| A2 | Listen to the end | The whole paper is spoken, in Egyptian Arabic, with a clear pause between cards (the `.\n\n` separator) |
| A3 | Listen for additions | **Nothing** is spoken that is not in the text: no greeting, no "sure", no commentary. A single added word means the verbatim conditions have drifted |
| A4 | Watch the reported positions | They advance smoothly and reach the end of the audio, not of the text |
| A5 | After it finishes | The audio file exists and the read reports `verified: true` |

## B · An interrupted read

| ID | Do | Expect |
|---|---|---|
| B1 | Cut the network **2 seconds** in (aeroplane mode) | The read restarts from word one on Live, or falls to the device — either is correct; what must **not** happen is silence or a frozen position |
| B2 | Cut the network **30 seconds** in | The read does **not** restart from the top: hearing the first third of your paper twice is worse than finishing in a flatter voice. It continues on device TTS |
| B3 | Cut it and restore it immediately | One read, not two overlapping voices |
| B4 | Press stop mid-read | Speech stops **at once**, and no further audio arrives after it |

## C · The device tier (device TTS)

**Condition (Claude):** `explain_enabled = false`, or block the token endpoint,
so Live cannot be reached at all.

| ID | Do | Expect |
|---|---|---|
| C1 | Start the read | It is read by the phone's own voice, and it starts — no dead end |
| C2 | Look for a pause control | **Pause is not offered** on this tier (`canPauseMidRead == false`). The screen offers stop instead. A pause button that appeared here would lose the card positions for the rest of the paper |
| C3 | Uninstall / disable every Arabic voice, then read | The bundled «الموبايل مفيهوش صوت عربي» line is **heard** — this is the whole reason the fixed lines are assets |
| C4 | After a device-tier read | **No** audio file is saved for it; replay re-runs TTS |

## D · Offline replay

| ID | Do | Expect |
|---|---|---|
| D1 | Read a paper on Live, then go fully offline and replay it | It plays from the encrypted file, with no network |
| D2 | Seek while it replays | Seeking works in this phase (`canSeek == true` on the file phase) |
| D3 | Seek **while the first read is still streaming** | Seeking is **refused** — D7's decision. The file does not exist yet |
| D4 | Replay on a cheap-feeling moment (app cold, device busy) | No stutter. `StreamAudioSource` on low-end devices is the owner's own flagged risk; if it stutters, the approved fallback is decrypt-to-cache |
| D5 | Check the app's private storage | The `.m4a` on disk is **encrypted** — not playable by a file manager |

## E · Audio focus and the phone being a phone

The reason this checklist cannot be replaced by tests.

| ID | Do | Expect |
|---|---|---|
| E1 | Receive a real incoming call mid-read | The read **pauses or stops** — it does not keep speaking under the ringtone |
| E2 | End the call | Nothing resumes speaking on its own into a silent room, or if it does resume it does so from the right place, not the top |
| E3 | Start the read, then start the old result screen's reader (or the Settings voice preview) | They never speak **together**. `AudioTrack` requests `AUDIOFOCUS_GAIN`, which takes focus from `flutter_tts` |
| E1b | **While a read is playing, have someone send you a WhatsApp** (or any notification with a tone) | The read **lowers its volume and keeps going**, then returns to full. It must not stop. Added by the device pass: before it, the first notification paused the track and nothing ever resumed it |
| E4 | Play music, then start a read | The music stops; the read is audible |
| E5 | Lock the screen mid-read | Audio behaves predictably (continues or stops), and the app is not killed |

## F · The fixed lines

| ID | Do | Expect |
|---|---|---|
| F1 | Trigger each of the 12 lines | Each is heard, in the same voice family as a paper read |
| F2 | `waiting_reading` and `voice_failed` specifically | Pronounced cleanly. Both were **reworded because of pronunciation**, and the generator cannot hear emphasis — this row is the only check on that |
| F3 | `crop_continue` and `camera_permission` | They describe where a button **is**. Confirm the description matches the screen; if F39 has moved it, the line is a lie and must be regenerated |
| F4 | Fully offline, airplane mode | Every line still speaks. They are assets; if one is silent, it is missing from the bundle |
| F5 | Speak a line while a paper is being read | They do not talk over each other in a way that makes both unintelligible. **Note:** F37 does not coordinate this — `SpeakFixedLine` owns only its own player, and which one wins is F39/F40's call. Record what happens so that call is made from evidence |

## Results

Run on the RMX2001 (Android 11) on 2026-11-14/15, against the local stack.
**Accepted by the owner at this state.** Every row below says what was actually
observed; rows that were not run say so rather than borrowing a pass from a
neighbour.

Most rows are evidenced by frame counts from `logcat` — our own process
delivering N frames to `AudioTrack` at 24 kHz, so N/24000 is the seconds of
audio the speaker actually rendered. A device-TTS read shows up as frames from
the TTS engine's process instead, which is how "it fell back" is told apart
from "it read" without having to ask.

| ID | ✅ / ❌ | Notes |
|---|---|---|
| A1 | ✅ | 30 s wall clock for 23.4 s of audio — the read was playing while still arriving, not waiting for the file |
| A2 | ✅ | Owner's ear, several full reads |
| A3 | ✅ | `verified true` on **every** Live read — the app's own comparison of the service's transcript with the text it sent |
| A4 | ✅ | `position 24071 ms / duration 24064 ms` — reached the end of the audio |
| A5 | ✅ | `engine geminiLive · verified true · audioSaved true · canReplay true` |
| B1 | ✅ | Wi-Fi cut 4 s in: Live failed, device tier read the paper in full. No silence, no dead end |
| B2 | ✅ | Wi-Fi cut 19 s in: the read delivered its full 612,480 frames and did **not** restart. Live streams faster than real time, so the audio was already in hand — a late cut is invisible |
| B3 | — | Not run (cut and immediately restored) |
| B4 | ✅ | Stop → `VoicePlaybackIdle` at once |
| C1 | ✅ | With `explain_enabled = false`: `engine deviceTts`, paper read in full |
| C2 | ✅ | `canPause false` on this tier, as designed |
| C3 | — | **Not run**: needs the Arabic voice removed from the phone. The bundled `no_arabic_voice` line itself was played and heard (F1) |
| C4 | ✅ | `audioSaved false · canReplay false` — a device read saves no file |
| D1 | ✅ | Wi-Fi **off**: replay delivered 612,352 frames from the encrypted file |
| D2 | ✅ | `canSeek true` in the file phase |
| D3 | — | Not measurable this way: `uiautomator` cannot dump while the state card is updating. Covered by T19's unit tests, and the button reads «Seek 10s (refused)» whenever `canSeek` is false |
| D4 | ✅ | No stutter observed across ~14 reads and replays. Not a rigorous low-end test |
| D5 | ✅ | `files/voice_audio/dev-harness-paper/audio.m4a.enc` — random first bytes, no `ftyp` header. Genuinely encrypted |
| E1 | — | **Not run**: needs a real incoming call |
| E1b | ✅ | **Three** notification tones during one read: the volume ducked and the read finished all 580,800 frames. This is the row the pass was extended for |
| E2 | — | **Not run** (follows E1) |
| E3 | — | Not reachable: the harness is the only route in a `VOICE_HARNESS` run, so Settings' voice preview cannot be opened beside it. Partly evidenced anyway — `just_audio` was seen losing focus to `PcmPlayer` and `PcmPlayer` losing it to `just_audio`, which is the single-owner gate working both ways. **F40 should confirm it with the real screens** |
| E4 | — | Not run as its own row |
| E5 | ◐ | Screen locked mid-read: the app survived and was still foreground after unlocking. Audio behaviour *during* the lock was not measured — and the harness rebuilds its cubit on an activity recreation, which is a harness artifact, not a spine one |
| F1 | ✅ | The owner played the lines and accepted them |
| F2 | ✅ | Owner's ear, accepted. `waiting_reading` and `voice_failed` were the two reworded **for** pronunciation |
| F3 | — | Cannot be judged yet: `crop_continue` and `camera_permission` describe where a button is, and F39 has not built those screens. **See the warning in `F37-voice-lines.md`** |
| F4 | ✅ | Wi-Fi **off**: fixed lines played (106,496 and 109,568 frames) |
| F5 | ◐ | Not a pass or a fail, a **finding**: a fixed line plays through `just_audio`, whose focus request sends `AUDIOFOCUS_LOSS` — a *permanent* loss — to `PcmPlayer`, so speaking a line while a paper is being read stops that read for good. F37 does not coordinate the two by design; **F39/F40 now have the mechanism in hand to decide what should happen** |

## What this pass found

Five defects, plus a sixth that `@code-reviewer` found afterwards in T21's own
new code. Five are fixed on this branch and recorded in F37-T21's note in
`F37-voice-spine.md`; one is open and accepted:

1. Any notification stopped a read permanently — **fixed**
2. The model id was prefixed twice (`models/models/…`) — **fixed**
3. Live answered with the date and time instead of reading — **fixed**
4. Every incoming WebSocket frame was silently dropped (binary vs text) — **fixed**
5. Live sessions fail intermittently, ~1 in 4 — **OPEN, accepted by the owner**
6. `TokenedLiveVoiceSession.cancel()` did nothing while the token was in
   flight, so a stop pressed in the first ~half-second was ignored and the
   paper read to the end over it — **fixed** (found by `@code-reviewer`, not by
   the device pass)

Before the fixes, **Live did not work on the phone at all**: every read fell to
device TTS while the whole test suite was green. Three of the five hid behind
passing tests, and two of those tests were actively wrong — one asserted the
defect as its expected value, the other fed the client a data shape the real
service never sends.

Two smaller observations, neither fixed:

- A **failed** read leaves a zero-byte temp file in `cache/` (three had
  accumulated). Successful reads clean up after themselves. No content leaks —
  the files are empty — but §7 asks for temp files to be removed.
- The turn text carries a double full stop («جنيه..»), harmless and explained
  in T21's note.

**The first thing anyone picking up defect 5 should do is log the socket's
close code and reason.** The client currently discards both — `start` returns a
bare `VoiceServiceFailure` — which is precisely why hours on a device could not
name the cause.
