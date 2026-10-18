# F30 · Reading aloud — every failure handled, the delay gone, and mixed Arabic/English read properly

- **Branch:** `fix/reading-aloud`, based on `develop` (after PR #31 merged F27 Phase 4 + F29 into it) · **Milestone:** post-F29
- **Depends on:** F10 (the audio reader this fixes — the mini-player, the four reading modes, progress tracking), F11-T07 (the reading defaults in Settings, whose voice picker has since been removed), F21 (the result screen the mini-player lives in), F27-T12 (the global error handlers and the logger this reports through)
- **Progress:** 16 / 22
- **PR:** one PR into `develop` at the end

The owner reported three faults in the reader on 2026-10-17, from three
physical phones. Investigating them turned up six distinct root causes, four
of them confirmed in code and two of them crashes nobody had hit yet.

## What the owner saw

1. **An error snackbar when starting a reading** — «حصلت مشكلة. جرّب تاني.»
   appeared about three times in a row, then the reading worked. Online.
2. **On a Samsung phone, «الخلاصة» refused to work** while the other modes
   played — and what did play *"read only the English letters"* on a paper
   that was mostly Arabic. A Xiaomi phone was fine. The owner's Realme is
   fine except for the English.
3. **English inside an Arabic paper is read letter-by-letter**, as individual
   characters instead of words.
4. **A 1–3 second delay** between tapping play and hearing anything.

All of it on the **production build from the Store**.

## Root causes

Six, numbered as they were presented to the owner. Each task below says which
it closes.

### RC-1 · No Arabic voice → the app silently reads Arabic with an English voice

`StartReading._applyDefaultVoiceFor` treats "no matching voice installed" as
nothing to report — its own comment says the reading *"proceeds on whatever
voice the engine already had"*. Samsung phones default to **Samsung TTS**,
which in many regions ships **no Arabic voice at all**, so `getVoices()`
returns no `ar-*` entry, no voice is set, and the paper is read by an
**English** voice. Arabic script through an English voice produces nothing
audible; Latin characters get read. That is, literally, *"it read only the
English letters"*.

It also explains the «الخلاصة» anomaly with no extra assumption: that mode
reads `summary.short` — one short, essentially pure-Arabic sentence — which
yields nothing speakable, while the longer modes contain numbers and English
fragments and so produce *something*. Xiaomi and the Realme default to Google
Speech Services, which does ship Arabic, so both worked.

**The defect is the silent fallback.** For an app built for elderly Egyptian
users, "your device has no Arabic reading voice" has to be said out loud.

This is **not** an edge case. The «صوت القراءة» picker was removed from
Settings (see the locked decisions below), which left `SetDefaultReadingVoice`
with **zero call sites** — so `readVoice()` always returns `null`,
`preferredVoice` is always `null`, and `_applyDefaultVoiceFor` **always**
takes the `getVoices()` branch. Every device, every reading.

### RC-2 · Every engine error is treated as permanent, and the reason is thrown away

`FlutterTtsTextToSpeechService` registers
`..setErrorHandler((_) => _events.add(const TtsFailed()))` — the error payload
is **discarded**, and `TtsFailed` carries no fields. The cubit turns it into
`AudioReaderFailed` and both screens show the same generic «حصلت مشكلة. جرّب
تاني.».

Android reports distinct, *recoverable* conditions through that handler:
`ERROR_NOT_INSTALLED_YET` (voice data still downloading on first use),
`ERROR_NETWORK` and `ERROR_NETWORK_TIMEOUT` (Google's Arabic voices are
commonly network-synthesised — which fits "this happened online"). The app
cannot tell these from a real failure, so it gives up and makes the user
retry by hand. That is why the owner's third attempt succeeded.

Beyond the UX: because the code is discarded, **we are blind in production**.
`LogEvent` has no TTS field at all, so none of this reached F27's logging.

### RC-3 · `speak()`'s return value is ignored → a mini-player that pretends to read

`flutter_tts`'s Android `speak()` returns false in two cases: the native
`speak()` call fails — notably **text longer than
`TextToSpeech.getMaxSpeechInputLength()`, 4000 characters** — and when the
engine's service connection is unusable, in which case the plugin re-creates
the engine and returns false **emitting no event at all**.

Our wrapper ignores the result and returns `Ok`, so the cubit emits
`AudioReaderReading`: the bar appears, nothing is spoken, and because no
`TtsCompleted` ever arrives, **the bar never goes away**. Nothing in `lib/`
calls `getMaxSpeechInputLength`, so `readAll` on a long paper has no guard.

**Corrected in T09, from the plugin's own source (flutter_tts 4.2.5).** The
Android side does not return `false` in either case. Its private `speak()`
returns false, and `onMethodCall` then **parks the whole call** in
`pendingMethodCalls` and returns *without answering the channel at all*, to
re-run it the next time the engine initialises. So `await tts.speak(text)`
does not resolve false — it **never resolves**. Which is worse than the
description above, and differently shaped:

- **Service connection stale** — the plugin builds a new `TextToSpeech`, its
  `onInit` fires, the parked call re-runs and usually succeeds. Self-healing,
  typically in well under a second, and worth waiting out rather than
  failing.
- **Native `speak()` failed outright** (the >4000-character case) — the
  connection was fine, so no new engine is built, so **no `onInit` will ever
  fire** and the call is parked for the rest of the session. The reading hangs
  with no bar, no error and no recovery.

`0` *is* returned, but for other things: iOS answers `0` when a paused
synthesizer will not continue, and Android answers `0` when it is already
speaking in `QUEUE_FLUSH` mode — unreachable here, since that needs
`awaitSpeakCompletion`, which this app never turns on. `1` is the only
answer that means the utterance was taken.

T09 therefore does two things rather than one: it treats any answer but `1`
as a failure, and bounds the wait at 5 seconds so the second case above
becomes a reported failure instead of a reading that never starts. T15's
chunking removes that case's trigger; the bound stays as the floor under it.

### RC-4 · One voice for the whole utterance; no language segmentation

`SelectVoiceForReading` collapses the text to a single dominant script
(`arabic >= latin` → `ar`) and `StartReading` makes **one** `speak()` call. An
`ar-*` voice has no Latin grapheme rules, so it falls back to naming
characters one at a time — the owner's Realme symptom.

`setLanguage` and `isLanguageAvailable` are **never called anywhere** in
`lib/`. There is no language-segmentation code in the project.

### RC-5 · Two hard crashes in the number normalizer (latent; not the owner's trigger)

Confirmed by executing the real code:

```
THROW المبلغ 10500 جنيه   -> RangeError (length): Not in inclusive range 0..9: 10
THROW المبلغ 1000000 جنيه -> _TypeError: Null check operator used on a null value
```

In `normalize_spoken_numbers.dart`: `_ones[thousands]` is indexed under
`thousands <= 10` but `_ones` holds only 0–9, so **any amount 10,000–10,999**
beside `جنيه` / `ج.م` throws `RangeError`. And `_belowThousand` does
`_hundreds[hundredDigit]!` with no entry above 900, so **any amount ≥
1,000,000** throws. Tests covered only `1200` and `1500`.

In a Store build this throws before any `emit`, escapes an unawaited
callback, and dies in `PlatformDispatcher.onError` — so the symptom is
**silence**, with no snackbar. It is not what the owner hit (amounts "mostly
did not cause any issues"), but a 10,500 جنيه bill breaks every mode.

### RC-6 · The 1–3 second delay

Three compounding causes:

1. **Five sequential round-trips before any audio.** `start()` awaits, in
   order: `setSpeechRate` (channel) → `getDefaultReadingVoice` (**two**
   separate Drift reads, for a value that is always null) → `getVoices`
   (channel) → `setVoice` (channel) → `speak` (channel). Nothing is cached,
   nothing is parallel.
2. **`getVoices()` on every single reading** — it enumerates every voice from
   every installed engine across the platform channel, re-done on each tap.
3. **We pick a network-synthesised voice, blind.** The plugin exposes six
   fields per voice — `name`, `locale`, `quality`, `latency`,
   `network_required`, `features` — and our `_parseVoice` **keeps only `name`
   and `locale`**. `SelectVoiceForReading` then takes *the first* voice whose
   locale starts with `ar`, with no regard for latency or network. Google's
   Arabic voices are commonly network-synthesised, so we routinely choose a
   voice that must fetch audio over the network before it can speak. This is
   the bulk of the delay, and it is also the source of RC-2's transient
   `ERROR_NETWORK` failures.

### Secondary · a mode with no content, and an empty utterance

The options sheet offers all four modes **unconditionally**
(`_offeredModes`), but `BuildAnalysisResult` only includes the summary
section when `summary.short.trim().isNotEmpty`. So a blank `short` leaves
«الخلاصة فقط» on offer, `BuildReadingText` returns the empty string, and that
empty string reaches the engine — whose behaviour for an empty utterance is
engine-dependent. **Not** claimed as the Samsung cause (RC-1 explains that
without it), but offering a mode with no content and speaking an empty string
are defects either way.

## Locked decisions

Settled with the owner on 2026-10-17, in the three rounds of questions that
preceded this doc.

1. **Branch hygiene first.** `develop` was 26 commits behind
   `feature/android-release`, with no open PR — so a fix branch cut from
   `develop` would have been built on a version of the mini-player that
   F27-T21 had already fixed. The owner chose to merge first: PR #31 landed
   those 26 commits (F27 Phase 4 + F29) on `develop` as a merge commit
   (`eb11e7e`), and `fix/reading-aloud` was cut from the result.
2. **Option A for RC-4** — split the text into language runs, switch voice per
   run, and speak them as a **sequential queue**. The owner chose this over
   Option B (transliterate Latin runs into Arabic script and keep the
   single-utterance model) and over the hybrid.
3. **Transliteration survives as the *fallback inside* Option A** (T17). When
   a run's language has no installed voice, that run is transliterated into
   the script we *do* have a voice for, rather than being skipped or read
   letter-by-letter. This is what "completely handle all error cases"
   requires — it means building both approaches, and the owner approved that
   cost.
4. **No fallback exists for a missing Arabic voice.** Transliterating Arabic
   into Latin would be unusable. The only correct answer is to tell the user
   their device has no Arabic reading voice and offer the system TTS settings
   (T07).
5. **The «صوت القراءة» picker stays removed.** The owner removed it because
   *"most device voices are unsuitable for Arabic"*. So the dead
   `SetDefaultReadingVoice` plumbing is retired rather than revived (T04), and
   voice choice becomes fully automatic — which makes T05's offline/latency
   preference the only thing standing between the user and a bad voice.
6. **The queue is completion-event-driven**, not `QUEUE_ADD`. Android *may*
   honour a per-utterance voice when several are queued with `QUEUE_ADD`,
   which would remove the gap between runs — but whether the voice is
   captured at queue time is engine-dependent and is not asserted from docs.
   T12 spikes it on a real device and adopts it only if it holds. The
   trade-off accepted meanwhile: event-driven sequencing adds a small gap
   between language runs. **(T12 found both halves of this wrong — the voice
   is captured per utterance, and the gap is not small — and still did not
   adopt `QUEUE_ADD`. See its findings below.)**
7. **New Arabic copy is allowed**, for T07 and for T08/T16's permanent-failure
   message. The owner asked for drafts to approve. Per CLAUDE.md §7 the new
   strings name no provider and make no privacy claims, and go through
   `app_strings_test`'s table like every other key.
8. **Straight through, T01 → T20.** The owner chose sequential execution over
   front-loading the quickly-verifiable half (the error cases, the delay and
   the copy) ahead of the queue rework.
9. **The privacy screen is not touched.** Investigating RC-6 turned up
   something nobody had considered: a network-synthesised voice sends the
   text being read to the device's voice service to be turned into audio, so
   reading a paper aloud can put its text on the network — which the privacy
   copy covers for the analysis service but says nothing about for reading.
   Put to the owner on 2026-10-17 with three options. **Their decision:
   prefer offline voices (T05) as planned, and leave the privacy screen
   exactly as it is.** T05 is therefore a privacy improvement as well as a
   latency one, and no copy changes follow from it.
10. **The copy drafted for T07 and T08/T16 was approved as drafted** on
    2026-10-17 — see "The copy end" below for the approved wording. The
    auto-retry in T16 stays silent, with no string of its own.
11. **Two further reading bugs, found while testing T02, are in scope.** The
    owner asked for both to be added and fixed: the piastres word order
    (T21) and the clock reading (T22). They are run directly after T02
    rather than at the end, because they live in the file T02 had just
    rewritten.

## Tasks

| # | ID | Task | Closes | Status |
|---|---|---|---|---|
| 1 | F30-T01 | Feature doc, branch, index row | — | DONE 2026-10-17 |
| 2 | F30-T02 | Fix the normalizer's two crashes + tests (10k–10,999, ≥1M, the decimal part) | RC-5 | DONE 2026-10-17 |
| 3 | F30-T21 | The currency word belongs between the pounds and the piastres — «مئتين وخمسين جنيه وخمسين قرش», and a zero piastres part is dropped | found in T02 | DONE 2026-10-17 |
| 4 | F30-T22 | The clock: stop «الساعة» doubling when the text already says it, and read a 24-hour hour as a 12-hour one | found in T02 | DONE 2026-10-17 |
| 5 | F30-T03 | Extend `TtsVoice` with `quality`, `latency`, `networkRequired`; parse all six fields the plugin sends | RC-6 | DONE 2026-10-17 |
| 6 | F30-T04 | Cache the voice list; drop the always-null `getDefaultReadingVoice` from the hot path; retire the dead `SetDefaultReadingVoice` plumbing | RC-6 | DONE 2026-10-17 |
| 7 | F30-T05 | Voice selection prefers **offline, low-latency** voices over network ones | RC-6 | DONE 2026-10-17 |
| 8 | F30-T06 | Warm the engine when the result screen mounts, so the first tap is not the cold start | RC-6 | DONE 2026-10-17 |
| 9 | F30-T07 | Detect "no Arabic voice on this device", surface it as a real explained failure, route to system TTS settings | RC-1 | DONE 2026-10-17 |
| 10 | F30-T08 | Carry the engine's error code on `TtsFailed`; classify transient vs permanent | RC-2 | DONE 2026-10-17 |
| 11 | F30-T09 | Honour `speak()`'s return value → `Err` instead of a dead mini-player | RC-3 | DONE 2026-10-17 |
| 12 | F30-T10 | Language-run segmentation use case (Arabic / Latin / neutral runs) + tests | RC-4 | DONE 2026-10-17 |
| 13 | F30-T11 | The sequential utterance queue, completion-event-driven | RC-4 | DONE 2026-10-17 |
| 14 | F30-T12 | **Spike:** `QUEUE_ADD` with per-run voices on a real device; adopt only if the voice is honoured per utterance | RC-4 | DONE 2026-10-18 — not adopted; the voice *is* honoured per utterance, but pause loses the queue |
| 15 | F30-T13 | Rework progress to span the queue, preserving F10-T08's Android resume behaviour | RC-4 ⚠️ | DONE 2026-10-18 — no rework needed; the gap was the tests |
| 16 | F30-T14 | Rework pause/resume/stop across the queue, including mid-run | RC-4 ⚠️ | DONE 2026-10-18 — two holes the queue had left, closed; the listening pass rolls into T20 |
| 17 | F30-T15 | Chunk any run over `getMaxSpeechInputLength()` into queue items | RC-3 | TODO |
| 18 | F30-T16 | Per-chunk transient-error retry (once) before surfacing anything | RC-2 | TODO |
| 19 | F30-T17 | Latin→Arabic transliteration as the fallback when no `en-*` voice exists | RC-4 | TODO |
| 20 | F30-T18 | Copy: «التلخيص فقط» / «التلخيص وأهم المعلومات», both languages | owner request | TODO |
| 21 | F30-T19 | Only offer modes that have content; never speak an empty string | secondary | TODO |
| 22 | F30-T20 | Quality gate → `/flutter-code-review` → `@code-reviewer` → device pass → PR | — | TODO |

**T13 and T14 carry the highest regression risk** in the feature: today
`_totalLength` / `_peakProgress` measure a single utterance, including
F10-T08's deliberate high-water-mark logic for Android's "resume = fresh
utterance covering the remainder" behaviour. Both have to start spanning a
queue without losing that.

T02 is independent of everything and could land in any order. T03 → T04 → T05
is a chain (the fields must exist before they can be cached or preferred), and
T10 → T11 → T13 → T14 is the hard chain of the queue work.

**T10 built the segmenter and wired nothing to it yet.** `SegmentLanguageRuns`
and `LanguageRun` exist with their three guarantees under test — the runs
concatenate back to the reading exactly, none is empty, no two neighbours
share a language — which is what T11's queue and T13's progress will lean on.
Two choices worth recording: a neutral stretch (digits, spaces, punctuation)
binds to the run that **follows** it, because a number binds to the word after
it in both languages the app reads («15 March», «500 جنيه»), and splitting at
every digit would otherwise turn «المبلغ 500 جنيه» into three utterances with
two gaps. And `SelectVoiceForReading` now counts script through the same
`ReadingLanguage.ofCodeUnit` the segmenter classifies with, so the two cannot
disagree about where a language starts. Nothing calls the use case and it is
not in `get_it`: T11 registers it with the queue that consumes it.

**T11 put the queue behind `StartReading`, not inside the cubit.** `ReadingQueue`
(`domain/services/`) owns the sequencing: it segments the reading, assigns a
voice per run, speaks the first, and advances on the engine's completion. It
publishes a *reading-level* event stream that `WatchReadingEvents` now forwards
instead of the engine's own, which is what keeps the cubit out of it — a run
finishing mid-reading is swallowed, so the mini-player still closes on one
`TtsCompleted`, and `TtsProgressed`'s offsets are moved into whole-reading
coordinates, because a stream that claims to be about the reading cannot report
offsets into one utterance of it. `StartReading` is back to deciding only which
mode to read; `StartRawReading`, `StopReading` and `WatchReadingEvents` go
through the queue too, so **nothing speaks except through it** — a `speak`
behind its back would have its completion read as a run finishing and advance
someone else's reading.

Three things the plugin's own source (flutter_tts 4.2.5, `FlutterTtsPlugin.kt`)
settled, rather than being assumed:

- A flushed utterance fires `onStop(interrupted)` → `speak.onCancel`, **never**
  `onDone`. So a stale completion cannot advance the queue early — the only
  event an abandoned utterance produces is a cancel.
- That cancel arrives *after* the new reading is installed, so clearing the
  queue on every cancel would throw away the queue of the reading the user just
  asked for. The queue therefore clears on a cancel only when the engine had
  told it the current run began, which separates "a new reading flushed the old
  one" from "something outside the queue took the engine".
- `onDone` clears the plugin's `pauseText`, so speaking the next run is clean —
  no interference with Android's resume-the-remainder mechanism.

**Two invariants, asserted across the queue's tests.** The owner asked (same
day, after the first pass) for every gap the queue opened to be closed rather
than deferred, so pause and resume went through it as well:

1. *Either the reading is installed and playing, or nothing is installed and
   the engine is silent.* Every `speak` that answers with an `Err` — nothing to
   say, no Arabic voice, a first utterance the engine refuses — clears the
   queue and stops the engine before it answers. Before that, a new reading
   that failed before speaking left the **previous** one talking on under a
   screen that was about to show «حصلت مشكلة»; as one long utterance that was
   already true, and the queue would have made it last through every remaining
   run. A `speak` that another `speak` superseded is the one failure-shaped
   case that silences nothing: the newer reading is the one the user asked for.
2. *Nothing is spoken while the player is paused.* A pause landing in the
   **gap between two runs** pauses an engine that is not speaking, so it
   reports nothing then and has nothing to continue later: the next run used to
   start under a bar that said paused, and after that the reading could not be
   resumed at all, because the plugin had already cleared the text `resume`
   replays. The queue parks a run that comes due while paused — including one
   caught mid-hand-over, between the voice switch and the utterance — and
   `resume` either continues what the engine still holds or speaks the parked
   run itself.

A completion arriving while a hand-over is in flight is also ignored now:
nothing of the queue's is speaking between choosing an utterance and the engine
accepting it, so such a completion belongs to the reading being replaced, or to
an engine reporting one utterance twice — and acting on it would advance the
queue by two and skip a run. And a `TtsContinued` counts as the current run
speaking, the same as a start, because Android reports a continue rather than a
start for the first utterance after a pause.

**What this leaves T13 and T14.** Progress already spans the queue, and
F10-T08's high-water mark still does its job — Android's resume gives a fresh
utterance covering the remainder of the *run*, whose shifted offsets land below
the peak and are clamped exactly as before — so T13 looks closer to "verify and
test" than to rework. T14's substance landed here with the two invariants
above: `PauseReading`, `ResumeReading` and `StopReading` all go through the
queue, and pause/resume/stop are covered between runs, mid-run and
mid-hand-over. What is left for it is the device pass — the gap between runs,
and Android's resume-the-remainder behaviour, as heard rather than as unit
tested. The gap F30-T12 went on to measure is left as it is: see its
findings below for why `QUEUE_ADD` was not the way to close it.

**Accepted for now:** an English run on a device with no English voice is still
named letter-by-letter — it is spoken with whatever voice the engine had rather
than dropped, which is what T17's transliteration fallback is for. The
`NoArabicVoiceFailure` refusal stays a whole-reading decision, not a per-run
one: a mostly-English paper with one Arabic word in it still reads usefully in
an English voice, and refusing it over that word would be worse than mangling
it. RC-1 is the other case — a mostly-Arabic paper in an English voice makes no
sound at all. And `PreviewDefaultVoice` still speaks straight to the engine
rather than through the queue, because it previews one specific voice rather
than reading a paper; the cancel rule above is what keeps it from advancing
somebody else's reading.

**T13 changed no code, and the reason is worth recording.** T11's note
predicted it would be closer to "verify and test" than to rework, and that
held: progress is already measured against the whole reading, because the
queue shifts each utterance's offsets by the run's start and `speak` answers
with the whole reading's length rather than the first run's. F10-T08's
high-water mark goes on doing its job underneath that, and the queue has in
fact *improved* it — an Android resume hands back a fresh utterance covering
the remainder of the **run**, so the clamp freezes the bar only until the
next run overtakes the peak, where before the queue existed it froze for the
remainder of the whole reading.

What was missing was the coverage. Every progress test wrote before this one
read the invoice fixture, which is wholly Arabic and therefore reaches the
engine as a single utterance — so nothing exercised a run boundary
end-to-end, and the interaction this task was flagged ⚠️ for was the one
thing untested. Three tests close that: progress climbing across a run
boundary at the cubit level, the high-water mark holding through a resume
inside a *middle* run and then climbing again at the next one, and, at the
queue level, a resume inside a run still counting from that run's start
rather than from the top of the paper.

**T14 needed no rework either, but the audit it amounted to found two holes
— both on a failure path, both now closed.** T11's substance did hold:
pause, resume and stop all go through the queue, and between runs, mid-run
and mid-hand-over are each covered. What the two invariants had not been
read against was what happens when the *engine refuses* one of the three.

1. **A resume the engine refuses left the reading installed with nothing
   speaking.** Only the parked half of `resume` gave the reading up on
   failure; the half that asks the engine to continue the run it still holds
   handed the `Err` back raw. So the user is told «حصلت مشكلة», the bar goes,
   and the runs behind the one that would not continue stay in the queue
   waiting for a completion to advance them — and one can arrive, because the
   Settings voice preview is outside the queue and its completion would have
   started a run of a reading the user had already been told had failed. That
   is the first invariant, and now both halves of `resume` keep it.
2. **A pause the engine refuses kept reading under a bar that was no longer
   there.** The queue is right to leave the reading playing — a queue that
   fell silent on its own would stop at the end of the current run, which is
   what T11's note argues — but the cubit turned the refusal into
   `AudioReaderFailed`, and that state renders the mini-player as
   `SizedBox.shrink()`. The paper went on being read aloud with no pause and
   no stop to reach for, and leaving the page did not silence it either:
   `close()` only stops a reading the state still calls one. So the player now
   stops the reading before it reports the failure. The user asked for
   silence; a pause that cannot give it to them is closer to a stop than to
   talking on.

Closing the first of those put `resume` one rule short of `speak`, and the
review caught it: a refusal that arrives *after* a new reading has been
installed — the user taps resume, then starts a fresh reading from the
options sheet before the engine has answered — would have cleared the new
reading's queue and stopped it. So `resume` now stands down on a superseded
generation exactly as `speak` does: that refusal is neither reported nor
allowed to silence the reading the user actually asked for.

The queue's own behaviour on a refused pause is unchanged, and so is the
wrapper's: `pause()` reports `Ok` for anything the channel answers, because
iOS answers `0` for a `pauseSpeaking` on a synthesizer that is not speaking —
which is exactly the gap between two runs, where a pause is honest and the
parked run is what holds it. Reading that `0` as a failure the way T09 reads
`speak`'s would turn every between-runs pause on iOS into a stopped reading.

One test short of the mirror, as well: T11 had a pause landing inside a
hand-over and no stop landing there, so that is covered now too.

**What is left is a listening pass**, which no unit test answers: the gap
between runs as heard, and Android's resume-the-remainder on a mid-run pause
as heard. T12's instrumented run already measured the gap (0.4–1.5s per
language switch, warm engine to cold), so what the ear is for is whether a
resumed run picks up where it stopped rather than restarting or skipping. It
rolls into T20's device pass rather than being carried as a task of its own.

**T12's premise turned out to be wrong, and something else is in the way.**
Locked decision 6 held `QUEUE_ADD` back because "whether the voice is captured
at queue time is engine-dependent". It is not engine-dependent: the framework
decides it, above any engine. `TextToSpeech.setVoice` writes the voice name
into the instance's `mParams` (`TextToSpeech.java:1742`); `speak` hands
`getParams(…)` across the binder **with that one utterance**
(`TextToSpeech.java:1238`); and the service builds that item's
`SynthesisRequest` from the bundle right where the call lands, in the
constructor (`TextToSpeechService.java:949`, `:996`–`:998`), so the voice is
fixed when the utterance is *queued* — `playImpl` later just hands the
already-built request over. An engine never sees a queue at
all — it is given one `SynthesisRequest` at a time with a voice name already
in it. So the gate this task was written around is **passed**, on Samsung and
Google alike.

What stands in the way instead is pause, and it is the plugin and the
framework together rather than either alone:

- **A pause throws the rest of the queue away.** `flutter_tts`'s `"pause"`
  branch calls its own `stop()`, which is `TextToSpeech.stop()`, which
  "interrupts the current utterance and **discards other utterances in the
  queue**". Every run behind the current one would be gone, at a level the
  app cannot see it happen.
- **The plugin's resume bookkeeping describes one utterance only.**
  `pauseText` is set by the first `speak` and left alone by everything queued
  behind it, `lastProgress` counts into whichever utterance is speaking, and
  each `onDone` clears both. A pause during run 2 therefore has nothing to
  resume, and a pause before it resumes run 1's text truncated at an offset
  into run 2. Resuming the remainder — F10-T08's behaviour, which this doc
  already calls the feature's highest regression risk — could not be leaned
  on at all: the queue would have to rebuild it from its own progress
  offsets.
- **The events carry no utterance id.** `speak.onStart`, `onComplete`,
  `onCancel` and `onPause` are bare `true`s, so with several utterances in
  flight nothing but arrival order tells their events apart — and one `stop`
  or `pause` fires one of them *per discarded item*
  (`dispatchOnStop(…, isStarted())`), so a single tap arrives as a burst.

**Measured on the owner's RMX2001, 2026-10-18** — Google Speech Services,
473 voices, both the Arabic and the English one on-device.

The harness was an `integration_test` file run against the phone and **not
kept**: it needed the `integration_test` dev dependency, and a go/no-go
answered once did not justify carrying either in the repo. What it did, for
anyone who has to repeat it: speak four runs alternating Arabic/English,
each handed over with `setVoice` + `speak`, logging every engine callback
with a millisecond stamp, then read back how long each run spoke for and the
silence before it. Four runs rather than two because the question is about
the runs that are *still queued* when a later `setVoice` lands — with two,
the first run's voice is set immediately before it and proves nothing. The
four probes were: **A** sequential, as T11 speaks today; **B** all four
queued under `setQueueMode(1)`; **C** B, paused 1.5s into run 1 and resumed;
**D** sequential, but with each run's `setVoice` issued while the *previous*
run was still speaking.

| Run boundary | A · sequential, as T11 speaks today | D · next voice set ahead | B · `QUEUE_ADD` |
|---|---|---|---|
| 1 → 2 | 448ms | 170ms | 1ms |
| 2 → 3 | 689ms | 256ms | 4ms |
| 3 → 4 | 497ms | 18ms | 4ms |

(A first pass on a cold engine measured A at 1490 / 1153 / 396ms, so the gap
varies with how warm the engine is. D and B held across both passes.)

**The voice is honoured per utterance — confirmed twice over.** Under
`QUEUE_ADD` every run spoke for within 2% of its sequential length, run 3
included: it is Arabic, and the voice had been switched to English twice
behind it while it sat in the queue (6484ms queued, against 6482ms spoken on
its own). Had the voice been resolved at dequeue, run 3 would have been read
by an English voice and made almost no sound at all — RC-1's symptom, and
impossible to miss in a duration. Probe D says the same thing from the other
side.

**And `QUEUE_ADD` does close the gap completely** — roughly a second per
language switch, which is more than locked decision 6's "small gap" allowed
for.

**But pause under `QUEUE_ADD` fails worse than the source reading
predicted.** A single `pause()` produced **four** pause events, one per
discarded queue item, exactly as `dispatchOnStop(…, isStarted())` says it
would. The resume then spoke for 504ms and reported the reading finished: it
had lost about six seconds of run 1 *and* all of runs 2–4. The engine
synthesises ahead under `QUEUE_ADD`, so the plugin's `lastProgress` had run
far past what was actually being heard, and `pauseText.substring(lastProgress)`
resumed near the end of the run. Pause is not a corner of this feature — it
is one of T11's two invariants and the whole substance of T14.

**Decision: `QUEUE_ADD` is not adopted.** The gap it closes is real, but the
price is pause, resume and stop rebuilt on top of a plugin whose own pause
state is wrong underneath them — and a reading that silently skips to its end
is a worse fault than a silence between two sentences.

**What the spike found instead (probe D).** Because the voice is captured at
`speak()` time, the *next* run's voice can be set while the current one is
still speaking: it cannot reach the utterance already playing, and the
measured run lengths confirm it does not disturb it. That takes the awaited
`setVoice` round trip off the critical path and cuts the gap to 18–256ms with
no change to the queue's shape, to its two invariants, or to F10-T08's
resume. It is not part of T12, which was only ever a go/no-go, and is left
with the owner as a possible follow-up.

**T08 owes a deploy.** RC-2's "we are blind in production" half is closed by
giving each engine error its own log code (`TTS_NETWORK`,
`TTS_NOT_INSTALLED_YET`, …), and `report-error` only accepts codes listed in
`supabase/functions/_shared/reports/error-report-codes.ts`. Until that
function is redeployed the new codes are refused with a 400 the sink swallows
on purpose, so those reports would simply not arrive. Plain `TTS` is still
accepted throughout, so nothing regresses in the meantime.

## The copy end

Drafted and **approved as drafted** by the owner on 2026-10-17. Both
languages, plus a row each in `app_strings_test`'s accessor table. None names
a provider and none makes a privacy claim (§7).

**T07 — the device has no Arabic voice:**

| Key | Arabic |
|---|---|
| `audioReaderNoArabicVoiceTitle` | «الموبايل مفيهوش صوت عربي» |
| `audioReaderNoArabicVoiceMessage` | «علشان نقدر نقرأ لك الورقة بصوت، لازم يكون في صوت عربي مثبّت على الموبايل. تقدر تضيفه من إعدادات الموبايل، وبعدين ترجع تجرّب تاني.» |
| `audioReaderNoArabicVoiceAction` | «افتح إعدادات الموبايل» |
| `audioReaderNoArabicVoiceDismiss` | «مش دلوقتي» |

**T08/T16 — a permanent failure told apart from a retryable one:**

| Key | Arabic | When |
|---|---|---|
| `audioReaderFailedFeedback` *(existing, unchanged)* | «حصلت مشكلة. جرّب تاني.» | retryable, and the silent auto-retry has already failed once |
| `audioReaderEngineUnavailableFeedback` *(new)* | «القراءة بصوت مش متاحة على الموبايل دلوقتي.» | permanent engine failure |

**T18 — the two labels the owner asked to reword:**

| Key | From | To |
|---|---|---|
| `audioReaderModeSummary` | «الخلاصة فقط» | «التلخيص فقط» |
| `audioReaderModeSummaryAndKeyInformation` | «الخلاصة وأهم المعلومات» | «التلخيص وأهم المعلومات» |

The hamza in «وأهم» is kept, and the English strings are reworded to match.
