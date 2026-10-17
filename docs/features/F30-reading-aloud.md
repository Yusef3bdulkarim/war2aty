# F30 · Reading aloud — every failure handled, the delay gone, and mixed Arabic/English read properly

- **Branch:** `fix/reading-aloud`, based on `develop` (after PR #31 merged F27 Phase 4 + F29 into it) · **Milestone:** post-F29
- **Depends on:** F10 (the audio reader this fixes — the mini-player, the four reading modes, progress tracking), F11-T07 (the reading defaults in Settings, whose voice picker has since been removed), F21 (the result screen the mini-player lives in), F27-T12 (the global error handlers and the logger this reports through)
- **Progress:** 4 / 22
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
   between language runs.
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
| 5 | F30-T03 | Extend `TtsVoice` with `quality`, `latency`, `networkRequired`; parse all six fields the plugin sends | RC-6 | TODO |
| 4 | F30-T04 | Cache the voice list; drop the always-null `getDefaultReadingVoice` from the hot path; retire the dead `SetDefaultReadingVoice` plumbing | RC-6 | TODO |
| 5 | F30-T05 | Voice selection prefers **offline, low-latency** voices over network ones | RC-6 | TODO |
| 6 | F30-T06 | Warm the engine when the result screen mounts, so the first tap is not the cold start | RC-6 | TODO |
| 7 | F30-T07 | Detect "no Arabic voice on this device", surface it as a real explained failure, route to system TTS settings | RC-1 | TODO |
| 8 | F30-T08 | Carry the engine's error code on `TtsFailed`; classify transient vs permanent | RC-2 | TODO |
| 9 | F30-T09 | Honour `speak()`'s return value → `Err` instead of a dead mini-player | RC-3 | TODO |
| 10 | F30-T10 | Language-run segmentation use case (Arabic / Latin / neutral runs) + tests | RC-4 | TODO |
| 11 | F30-T11 | The sequential utterance queue, completion-event-driven | RC-4 | TODO |
| 12 | F30-T12 | **Spike:** `QUEUE_ADD` with per-run voices on a real device; adopt only if the voice is honoured per utterance | RC-4 | TODO |
| 13 | F30-T13 | Rework progress to span the queue, preserving F10-T08's Android resume behaviour | RC-4 ⚠️ | TODO |
| 14 | F30-T14 | Rework pause/resume/stop across the queue, including mid-run | RC-4 ⚠️ | TODO |
| 15 | F30-T15 | Chunk any run over `getMaxSpeechInputLength()` into queue items | RC-3 | TODO |
| 16 | F30-T16 | Per-chunk transient-error retry (once) before surfacing anything | RC-2 | TODO |
| 17 | F30-T17 | Latin→Arabic transliteration as the fallback when no `en-*` voice exists | RC-4 | TODO |
| 18 | F30-T18 | Copy: «التلخيص فقط» / «التلخيص وأهم المعلومات», both languages | owner request | TODO |
| 19 | F30-T19 | Only offer modes that have content; never speak an empty string | secondary | TODO |
| 20 | F30-T20 | Quality gate → `/flutter-code-review` → `@code-reviewer` → device pass → PR | — | TODO |

**T13 and T14 carry the highest regression risk** in the feature: today
`_totalLength` / `_peakProgress` measure a single utterance, including
F10-T08's deliberate high-water-mark logic for Android's "resume = fresh
utterance covering the remainder" behaviour. Both have to start spanning a
queue without losing that.

T02 is independent of everything and could land in any order. T03 → T04 → T05
is a chain (the fields must exist before they can be cached or preferred), and
T10 → T11 → T13 → T14 is the hard chain of the queue work.

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
