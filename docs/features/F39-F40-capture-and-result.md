# F39 + F40 · Capture flow and result screen

- **Branch:** `feature/capture-and-result`, cut from `develop` at `5139afd` (the PR #44 merge, so the tree carries F35–F38).
- **Milestone:** the fifth and sixth features of the F34 pivot, built **together** by owner decision (2026-11-17) so the capture flow hands its first paper to a real result screen rather than to a dev harness.
- **Depends on:** F36 (`explain-document`, §33), F37 (voice spine, closed with one open defect), F38 (paper model, closed with its device pass partly run).
- **Decisions source:** [F34-non-reader-pivot.md](F34-non-reader-pivot.md) and its "Amendments (2026-11-08)" section; [F38-paper-model.md](F38-paper-model.md)'s scope fence and "Open for the owner"; [F37-voice-lines.md](F37-voice-lines.md). The owner answered nineteen open questions on 2026-11-17; they are **D1–D19** below and are decisions, not suggestions.
- **Design source:** canvas «ورقتي — الشاشات الجديدة» (https://claude.ai/artifact/X9rLoR8AHtmrKq3JTDgbVt), artboards `Crop`, `Waiting`, `Result`.
- **Progress:** 43 / 52

## Why this feature exists

F36 built the endpoint, F37 the voice, F38 the paper and its storage. None of it
is reachable from the product: Home still sends a photo through the old
`ocr-document` → review → `analyze-document` flow, and the only thing that calls
`explain-document` is a dev harness.

At the end of F39 + F40:

1. Home → camera / gallery → crop with one «كمّل» → waiting → the paper's
   result screen, which **starts speaking on its own**.
2. Every explained paper is saved (F38's D9 order) before the result opens, and
   the result screen reads it **from the database** by id — the screen F41 will
   reuse for مستنداتي's details.
3. The old reading pipeline is gone from the app: Tesseract, the OCR screen, the
   review screen, the old result screen, the route decision and the hand-off
   holders.
4. The three failure screens speak their fixed line; the result screen speaks
   `voice_failed` / `no_arabic_voice` / the new `explain_partial` when it should.
5. The voice has a speed control on all three tiers.

**This build is not releasable on its own.** Until F41 replaces مستنداتي, a new
paper appears nowhere once its result screen is left: مستنداتي and Home's recent
strip still read the legacy document tables, which v4 emptied. That is expected
and is F44's problem to gate, not this feature's to patch.

## Scope fence — what this feature does NOT touch

| Not here | Where it goes | Why |
|---|---|---|
| Home's redesign (shutter, video circle, gallery circle) | F41 | Home keeps its layout; only where its two scan buttons lead changes (T15). |
| مستنداتي, `DocumentDetailsScreen`, `DocumentsListScreen`, `SaveDocumentCubit`, the `result_*` widgets they use, `DocumentAnalysis`, the seven legacy tables (v5) | F41 | Their last consumers live there (F38 D3). |
| Reopening an old paper; delete + its voice confirm | F41 | No list exists before F41 (D17). |
| What «؟» plays | F43 | The video does not exist yet. The button is drawn and inert (D6). |
| Share from WhatsApp | F42 | |
| `ocr-document`, `analyze-document`, `schema_version`, `online_ocr_enabled` on the **server** | never, until 1.0.x is out of support | Published builds still use them. Only the **client** side is deleted here. |
| Any change to `explain-document`'s timing or chains | F36 follow-up if needed | D9 shrinks the photo instead; the device pass measures whether that is enough. |
| An "update the app" screen for `UNSUPPORTED_APP_VERSION` | later | §33.7 names one; none exists in the code. It maps to «حصلت مشكلة» here and is recorded as a gap. |
| iOS | after the pivot | Kept compiling. |

## Decisions — owner, 2026-11-17

| # | Decision |
|---|---|
| **D1** | **The result screen reads its paper from the database, by id.** The waiting screen calls `explain-document`, saves the paper (F38 D9), then goes to `/paper/:id`. The route loads the paper with `WatchPaper` and starts the voice on open. The saved row is the only copy that survives Android killing the app mid-flow, and F41's details screen *is* this route. One extra flag distinguishes a fresh paper (read it with Live) from an opened one (replay the saved file). |
| **D2** | **Back on the waiting screen returns Home and the request keeps running.** If it succeeds the paper is saved, unread, so the slot the server counted always has a paper behind it. The explain-and-save job therefore does not belong to the screen: it is an app-scoped runner the waiting cubit subscribes to, and closing the cubit does not cancel it. A failure with no screen left to show it is logged, codes only. |
| **D3** | **The pre-capture check is connectivity only.** No quota pre-check: a spent day is the server's 429, which lands on «خلّصت ورق النهارده» after the photo. Checked when the user taps either scan control on Home, before the camera or picker opens. |
| **D4** | **`explain_enabled` is read from the session's last fresh sync; unknown triggers one fresh sync at tap time, and if that fails too the capture proceeds** and the server's 503 decides. Known-false → «حصلت مشكلة» before the camera. Fail-open on *unknown* only, because the flag is our emergency switch, not a routine state, and the backstop shows the same screen one photo later. |
| **D5** | **Crop: one «كمّل» at the bottom, the four drag handles, a small rotate control at the top, and «؟».** Removed: ✕, the title, the hint line, «صوّر تاني». Back is the system back. `crop_continue`'s «الزرار الكبير اللي تحت» stays true. |
| **D6** | **«؟» is drawn on Crop and Result and does nothing until F43.** Deliberate — recorded so nobody files it as a bug. |
| **D7** | **Camera permission stays exactly as it is.** No new voice line for Android's own dialog. |
| **D8** | **Waiting: the drawn paper from the artboard**, not the user's photo, with the scan line, the voice capsule, «استنى شوية وأنا بقراها» and the three dots. F22's reading-lens screen is deleted. |
| **D9** | **The photo is shrunk before upload:** longest edge 2000 px, JPEG quality 85, in an isolate; a smaller photo is passed through untouched. The shrunk file is also what `SavePaper` encrypts. This is the most likely cause of F38's two read-stage timeouts (a full-size gallery photo against a 4 s per-read cap), and it also shortens every upload on a weak connection. |
| **D10** | **The "unreadable" screen and `fail_unsupported` are removed.** `status: "unsupported"` stays an ordinary, saved result (§33.6, F38 D10) whose own card says what to do; `ANALYSIS_FAILED` cannot tell a failed reading from a failed explanation, so it lands on «حصلت مشكلة». The line is deleted from `VoiceLine`, the assets and `F37-voice-lines.md`. |
| **D11** | **A fixed line always finishes before a reading starts, and no fixed line ever starts while a reading is playing.** The `AUDIOFOCUS_LOSS` trap (F34 "Carried out of F37" #3) makes the order load-bearing: line done → then Live. The waiting screen waits for `waiting_reading` to end before handing over. |
| **D12** | **A new fixed line, `explain_partial`, plays once after the first reading of a `partial` paper ends** — never before it, never on a replay. Claude drafts the Arabic in `F37-voice-lines.md`; the owner edits it and runs `supabase/tools/generate-voice-lines.ts --only=explain_partial` on his machine. This closes F38's "Open for the owner" #1 by keeping §33.4's promise. |
| **D13** | **The ميعاد card's bell opens the existing manual reminder form, pre-filled** with the paper's date (and time when there is one) through `ManualReminderSeed`. No link between the reminder and the paper is stored (F38 D4 stands). |
| **D14** | **Speed works on all three tiers** — Live while streaming, the saved-file replay, and device TTS — from the very first reading. |
| **D15** | **The speeds are the existing four (`ReadingSpeed`: 0.75x / 1x / 1.25x / 1.5x), and there is one value**: the player's button reads and writes the same `DefaultReadingSpeedStore` the settings row uses. The button cycles **1x → 1.25x → 1.5x → 0.75x → 1x**. |
| **D16** | **During a first reading (and always for a device-TTS paper), the player cannot seek:** the waveform animates without filling, the clock counts up, tapping the waveform does nothing, and tapping a segment **scrolls to its card only** while the voice carries on. Once a Live reading is saved, the file phase gives full seek, segment-tap jumps the audio, and the waveform fills. F34's rule holds throughout: a manual scroll stops the auto-scroll, a segment tap restarts it. |
| **D17** | **The dev harness is deleted here** (as F38 said). F38-checklist rows that need a list of old papers — reopening one after a restart, and §F delete — move to F41's device pass. |
| **D18** | **The "N left today" SnackBar is removed** from the new flow (`UsageHintHolder` and its shell listener go with the old result route). |
| **D19** | **One branch, one PR at the very end**, after the final device test list passes. One commit per task, pushed. |

### Derived — taken from the files and the code, not asked

- **Error → screen:** `NoInternetFailure` → «مفيش إنترنت» + `fail_offline`;
  `DailyLimitReachedFailure` → «خلّصت ورق النهارده» + `fail_limit`; **every
  other failure** (`TIMEOUT`, `AI_RATE_LIMITED`, `ANALYSIS_FAILED`,
  `GLOBAL_CAPACITY_REACHED`, `ANALYSIS_DISABLED`, `UNSUPPORTED_APP_VERSION`,
  `INVALID_*`, a local database or storage failure) → «حصلت مشكلة» +
  `fail_service`. Retry re-sends **the same photo**; the photo's temp files live
  until a save succeeds or the user leaves the failure screen without retrying.
- **The failure screens keep F23's look** minus everything that assumed an
  extracted text: «اعرض النص», the text entry card, the "read the text
  meanwhile" tips, and `ExtractedTextOnlyView`.
- **Fixed lines:** `crop_continue` when Crop opens, `waiting_reading` when
  Waiting opens; each screen stops its own line when it is left (and per D11
  never cuts it to start a reading).
- **Result voice failures:** both tiers failed → `voice_failed`; no Arabic voice
  installed → `no_arabic_voice` plus F30-T07's "open TTS settings" action.
- **Card actions:** the call button dials through the existing external-link
  path; «كبّر العنوان للسواق» opens a full-screen, very large view of the
  address; the ميعاد card gains one line for `date.text` (owner, 2026-11-09).
- **Header date:** «النهارده» / «امبارح» / «3 نوفمبر», from `photographedAt`.
- **`audioId` is `paper.id`** (F38 D9); `RecordPaperReading` runs on every
  `VoicePlaybackReadFinished`, fresh read or re-speak.
- **Both locales** for every string (F34 answer 6): `app_strings.dart`,
  `ar_strings.dart`, `en_strings.dart`.

## Existing-code analysis

| Thing | Where | How this feature uses it |
|---|---|---|
| `ExplainPaper` | `features/explain/domain/usecases/` | called by the explain-and-save runner (T07) |
| `SavePaper`, `RecordPaperReading`, `WatchPaper`, `LoadPaperImage` | `core/papers/usecases/` | D9 order; the result screen's source (D1) |
| `BuildPaperVoiceSegments` | `core/papers/` | the segment ids `explain, todo, date, caution, contact, place` — **a stored format** (F38 T04); segments, highlight and segment taps all key off them |
| `VoicePlaybackCubit` / `VoicePlaybackState` | `core/voice/` | the result screen's voice; already has `readAloud`, `replay`, `pause`, `resume`, `seek`, `seekToSegment`, `stop` |
| `SpeakFixedLine`, `FixedLinePlayer`, `VoiceLine` | `core/voice/` | every fixed line; `play` returns when playing **starts** — D11 needs a "finished" signal (T10) |
| `PcmPlayer.kt` | `android/.../voice/` | position comes from `playbackHeadPosition`, i.e. content frames, so it stays true under a speed change (T35) |
| `ReadingSpeed`, `DefaultReadingSpeedStore` | `core/audio/` | the four speeds and the one stored value (D15) |
| `ConnectivityService` | `core/connectivity/` | the pre-capture check (D3) |
| `UsageRepository.syncUsage`, `DailyUsageDto` | `core/usage/` | `get-usage` already sends `explain_enabled` (F36-T05); the client does not parse it yet |
| `ServiceStateView` + F23's failure widgets | `core/widgets/`, `features/analysis/presentation/widgets/failure/` | the failure screens' look; the reusable widgets move before `features/analysis` is deleted |
| `ImagePreviewCubit`, `DraggableCropOverlay`, `RotateImage`, `CropImage` | `features/capture/` | kept; the cubit loses the route decision and the holders |
| `ManualReminderSeed`, `/reminders/manual` | `features/reminders/` | the bell (D13); its `eventMinuteOfDay` is required today and must become optional for a date with no time |
| `image` package | `pubspec.yaml` | already used by the cropper and rotator; the downscaler uses it too — **no new dependency** |
| `app_harness.dart`, `fakes.dart` | `test/support/` | any new `BootstrapStep` dependency or DI-registered platform service needs a fake there, or journey tests hang on a pending timer (F38-T11's lesson) |

**What must stay true throughout.** The old flow keeps compiling and running
until T21 switches the flow over (from T21 until Phase D, a real run ends on a
placeholder result screen); the deletions (Phase G) come **after** the switch,
never before, so every task in between is green on its own. `ocr-document` and
`analyze-document` keep serving 1.0.x. Nothing logs document content — not a
card, not the title, not the photo (§7).

## How every task is run

The owner's working rule for this feature (2026-11-17). Tasks are small on
purpose: each one is a single reviewable commit.

1. **Implement** the task — the session runs on **Sonnet 5.5**.
2. **Gate:** `dart format .`, `flutter analyze`, and the tests the task touches;
   the **full** `flutter test` at the end of each phase. Exit code 0 is not a
   pass — read the counter line and grep the severities
   (`flutter-exit-code-0-is-not-a-pass`).
3. **Self-review** with the `/flutter-code-review` skill.
4. **Stop and ask the owner to switch the session to Opus 5.** Once he
   confirms, the **main agent** (not a spawned subagent) reviews the task's
   diff as `code-reviewer` would. Fix every action item it raises, then
   re-run step 2. Nothing is committed over an open finding.
5. Still on Opus 5, the **main agent** commits — one commit per task,
   `feat(f39-40): <what> [T##]` (or `refactor`/`test`/`docs`) — and pushes.
6. Tick the task here, with anything the task found written inline under it,
   in the same commit.
7. **Stop and ask the owner to switch back to Sonnet 5** before starting the
   next task's implementation.

The branch is merged **only at the very end**, after the final test list
(§"Final test list") has passed on the device and every problem it found is
fixed.

## Phases

Each phase ends green with the full suite. A phase that cannot go green is not
finished and the next one does not start.

### Phase 0 — the record

- [x] **T01** Commit this file; add the F39+F40 row to `docs/features/README.md`
      and bump its totals; add a pointer from F34's Amendments table (F39 and
      F40 rows) to this file. *Done when:* the plan is on the branch and
      findable from F34 and the README.
      *Found:* the README has no F38 row, so its total never counted F38's
      tasks; flagged in the README's prose, not added here. The README's stated
      total was 39 short since F35-T03 (it subtracted F34's 39 tasks, which had
      never been counted); it is now the column's real sum, 504. "What must
      stay true throughout" named T44 as the switch-over; it is T21, so the
      sentence now says T21. The `code-reviewer` pass on T01 also found six
      ordering gaps in this plan, corrected here before any task runs into
      them: T16 removed the old route before T21 built the new one (the
      removal moves to T21, and T21 registers a placeholder `/paper/:id`
      until Phase D builds the screen); T31 played `explain_partial` before T40 creates
      it (the playback moves to T40); a pre-capture failure screen had a
      retry with no photo to retry (T13 now defines it); T27 named a use case
      that does not exist (it now creates `OpenPhoneDialer`); T29 missed the
      one-card `unsupported` paper; and F37's E1/E2/E3 rows were not carried
      into the final test list (now 4.5–4.7). Baseline gate on 5139afd +
      this docs change: `dart format .` 0 of 856 changed; `flutter analyze`
      0 errors, 0 warnings, 21 info (pre-existing); `flutter test` +3440,
      all passed.

### Phase A — foundations (domain/data, no UI)

- [x] **T02** `DailyUsage.explainEnabled` as a **`bool?`** (`null` = unknown),
      parsed by `DailyUsageDto` from `get-usage`'s `explain_enabled` on a fresh
      sync only; a reading rebuilt from the local cache carries `null`, never
      `false`. *Done when:* tests cover present-true, present-false, absent,
      wrong type, and the cached reading's `null`.
      *Found:* a wrong-typed flag reads as `null` and the quota still loads
      (unlike `online_ocr_enabled`, whose wrong type refuses the whole body):
      an unreadable emergency switch is "unknown", not a broken quota. The
      cache rows and `StubUsageRepository` never set the field, so no schema
      change. `API_CONTRACT.md` §32's row still said "absent or unreadable
      reads as `false`"; it now says `null` + D4's fail-open (the
      `code-reviewer` pass caught it). **For T03:** a failed `syncUsage()`
      returns `Ok(cached)` with `explainEnabled == null` (now pinned by a
      test), so a holder that writes on every `Ok` would wipe a known value;
      write only non-null values. Gate: analyze 0 errors / 0 warnings / 21
      info (pre-existing); `test/core/usage` +33 all passed; home, settings
      and capture tests +472 all passed.
- [x] **T03** Keep the session's last fresh `explainEnabled` in memory
      (`UsageRepository` exposes it, or a small `core/usage` holder the
      repository writes on every successful sync — bootstrap's included).
      *Done when:* a successful sync updates it, a failed sync leaves it as it
      was, and a fresh process starts at `null`.
      *Found:* `UsageRepository.lastKnownExplainEnabled` (an interface getter,
      the first option) is written only on the *fresh*-fetch branch of
      `syncUsage()`, to whatever that fresh answer said — including unknown,
      per D4's "the session's last fresh sync" — and never on the
      cache-fallback branch, whose rows never carry the flag (T02) and would
      otherwise wipe a known value every time the network drops. An early
      draft wrote on every `Ok` and only skipped `null`, which happened to
      also swallow a fresh "went back to unknown" answer into a stale `false`;
      `@code-reviewer` (opus) caught it against D4's literal wording before
      commit. `FakeUsageRepository` exposes a directly settable field instead
      of mirroring the production rule, so T04's table test can put it in
      `known-false` without going through a sync.
- [x] **T04** `CheckCaptureReadiness` use case (`features/capture/domain`):
      no connectivity → `offline`; known `false` → `serviceOff`; `null` → one
      fresh `syncUsage()`, then `serviceOff` if it says `false`, otherwise
      `ready`; a failed fresh sync → `ready` (D4). Returns a sealed
      `CaptureReadiness`. A throwing connectivity plugin reads as `offline`.
      *Done when:* a table-driven test covers every branch and the use case
      never throws.
      *Found:* connectivity is checked before the usage flag is ever read, so
      a throwing plugin or no connectivity reads `offline` without touching
      `syncUsage()` even when the flag is unknown or known `false` — the
      `code-reviewer` (opus) pass flagged two tests that set
      `lastKnownExplainEnabled = true` before an offline check, which could
      never have caught a regression that synced before the connectivity
      check; both were rewritten against `syncCallCount == 0`. The use case
      decides straight from the fresh `syncUsage()` result
      (`value.explainEnabled`) rather than re-reading
      `UsageRepository.lastKnownExplainEnabled` afterwards, since
      `RemoteUsageRepository`'s cache-fallback branch (a failed fetch with a
      cached row) returns `Ok` with `explainEnabled` always `null` — never
      `false` — so the two reads are equivalent today; the `usageWith(...)`
      test helper gained an optional `explainEnabled` parameter, additive and
      inert for its ~27 existing call sites. Gate: `dart format` 0 of 4
      changed; `flutter analyze` 0 errors / 0 warnings / 21 info
      (pre-existing); the new test file 10/10, plus the full
      `test/core/usage`, `test/features/capture`, `test/features/home` and the
      usage-hint/fallback app tests (430 total) all passed.
- [x] **T05** `ImageDownscaler` interface (`features/capture/domain/services`)
      and `ImagePackageDownscaler` (`data/services`): longest edge 2000 px,
      JPEG 85, in `Isolate.run`; returns the input path untouched when already
      within bounds; writes to the temp directory and reports the new path so
      the caller can delete it (D9). *Done when:* tests cover a large image, a
      small one (same path back), a portrait and a landscape one (edge picked
      correctly), and an undecodable file → `ImageProcessingFailure`, never a
      throw.
      *Found:* mirrors `ImageRotator`/`ImagePackageRotator` exactly (injectable
      temp dir, decode/resize/encode inside `Isolate.run`, the whole method in
      one `try`/`on Object`). The isolate returns a private record
      `({Uint8List? encoded})?` — `null` means undecodable, `encoded: null`
      means already within bounds (no file written, `Ok(photo)` returned
      before the temp dir is even looked up) — `code-reviewer` (opus) checked
      this crosses the isolate boundary safely and confirmed `image` 4.9.1's
      `decodeImage` already applies EXIF orientation before the width/height
      read, so the longest-edge choice is correct for a rotated JPEG too; no
      action items. Added an extra assertion (not required, `code-reviewer`'s
      one optional suggestion) that the two in-bounds tests also check
      `tempDir.listSync()` stays at length 1. **For T07:** an HEIC gallery
      photo that reaches this downscaler without being decodable by the
      `image` package ends as `ImageProcessingFailure` — expected per this
      task's spec, but the device pass (row 1.2) should confirm what the
      gallery picker actually hands back on the device. Gate: `dart format`
      0 of 4 changed; `flutter analyze` 0 errors / 0 warnings / 21 info
      (pre-existing); full `flutter test` +3468, all passed.
- [x] **T06** `DownscalePhoto` use case wrapping T05. *Done when:* tested
      against a fake downscaler.
      *Found:* `DownscalePhoto` is a thin wrapper (mirrors `RotateImage`), no
      findings of substance; `FakeImageDownscaler` added to
      `test/support/fakes.dart` next to `FakeImageRotator`. `code-reviewer`
      (opus) flagged — not a T06 defect — that neither
      `ImageDownscaler`/`ImagePackageDownscaler` nor `DownscalePhoto` are
      registered in `app/di/service_locator.dart` yet; that registration is
      left for **T07**, when `ExplainAndSavePaper` wires them in, since no task
      explicitly owns it. Gate: `dart format` clean; `flutter analyze` clean;
      `flutter test test/features/capture` +240, all passed.
- [x] **T07** The explain-and-save runner (D2): `ExplainAndSavePaper` in
      `features/explain/domain` — downscale → `ExplainPaper` → `SavePaper`
      (photographedAt = now) → `SyncDailyUsage` (best effort) → `Ok(paperId)`,
      and deletes every temp file it created once the save is done.
      `PaperExplainRunner` (app-scoped, registered as a lazy singleton) owns the
      in-flight job: `start(photo)` returns a broadcast result stream; a second
      `start` while one runs is refused; cancelling a listener never cancels the
      job. *Done when:* tests prove success, each failure kind passes through
      untouched, a database failure after a successful explain is reported, a
      listener that leaves before the end does **not** stop the save, and the
      temp files are gone after success and kept after a failure (retry needs
      them). No log line carries content.
      *Found:* `photographedAt` uses an injectable `clock` (`DateTime
      Function()?`, defaulting to `DateTime.now`), matching
      `DriftPapersRepository`'s own convention rather than a bare
      `DateTime.now()` call, so the value is assertable in a test. Each failure
      is logged once, at its origin, never twice: `DefaultExplainRepository`
      already logs every explain failure itself, so `ExplainAndSavePaper` logs
      only the two steps nothing else logs — a downscale failure
      (`LogStage.capture`) and a `SavePaper` failure after a successful explain
      (`LogStage.save`, the "spent a slot with nothing to show" case the Risks
      section names) — both unconditionally, regardless of whether a screen is
      still watching. `ExplainAndSavePaper` owns the **original** photo's temp
      file too, not only the file it creates itself: it deletes both
      `photo.path` and the downscaled path (deduped when downscaling was a
      no-op) on success, and keeps both on any failure, since T21 hands
      temp-file ownership to the runner at hand-off and row 2.11 of the final
      test list requires the cache clear after a success. `code-reviewer`
      (opus) caught a real bug before commit: `PaperExplainRunner._run` cleared
      `_controller` *after* adding the result to the broadcast stream, so a
      listener that reacted to the result by calling `start()` again (e.g. an
      automatic retry) would hit the "already running" `StateError` even though
      the job had, from its own point of view, already finished; fixed by
      clearing `_controller` before `controller.add(result)`. If
      `ExplainAndSavePaper` itself ever throws instead of returning a `Result`
      — a contract violation, since every dependency it calls is supposed to
      catch its own errors — `PaperExplainRunner` resets `_controller` but
      never adds an error or closes the stream, so a listener on that run
      would wait forever with no event; this is accepted as "a dependency
      broke its contract" rather than invented as a modelled failure, but
      **T20** should know a silently-hanging stream is possible if that
      contract is ever violated. **For T20:** the
      waiting cubit must check `runner.isRunning` before calling `start()` —
      D2's back-and-rescan means a user can reach a second `start()` call for
      real, not just as a programmer error, and the runner has no "join" API
      yet for an already-running job, only `isRunning`; and T20 must not log
      any failure itself, since every failure kind is already logged once at
      its origin (downscale, explain or save) regardless of whether a screen is
      left to show it. **For T13:** the runner does not retain the photo past
      the end of its job, so "retry re-sends the runner's retained photo" needs
      its own place to hold it (outside the runner) once that task wires up the
      hand-off.

### Phase B — the failure screens (rehosted from F23)

- [x] **T08** Move the failure widgets the new screen keeps —
      `FailureTipsCard`, `FailureNoteChip`, `LimitResetCard`, and whichever of
      `AnalysisStepsCard`'s pieces survive — out of `features/analysis` into
      `features/explain/presentation/widgets/failure/` (copy now, the old
      copies die in Phase G). *Done when:* the moved widgets' tests move with
      them and pass; nothing in the old screen changed.
      *Found:* all four widgets copied byte-identical; all four original files
      untouched; `AnalysisStepsCard` survives whole (both enums and the card).
      Test split: 16 moved tests (1 FailureNoteChip + 5 AnalysisStepsCard +
      1 FailureTipsCard + 8 LimitResetCard + 1 small-phone) into the new file;
      8 remaining (3 ExtractedTextEntryCard + 5 SupportedDocumentsSection) stay.
      Gate: format 0 changed, analyze 0 errors / 0 warnings / 21 info, 24/24
      tests passed.
- [x] **T09** `PaperFailureKind` (`offline | limitReached | serviceProblem`)
      and its mapping from `AppFailure`, per "Derived" above. *Done when:* a
      table test walks **every** `AppFailure` leaf — `hasLength`-guarded, so a
      new leaf fails the test until it is mapped.
      *Found:* production `fromFailure` uses a wildcard `_` for
      `serviceProblem`; the exhaustiveness guard is the test's `_expectedKind`
      switch, which lists all 37 leaves with no `default` — a new leaf breaks
      its compilation. No code-review findings. Gate: format 0 changed,
      analyze 0 errors / 0 warnings / 21 info (pre-existing), 5/5 tests
      passed.
- [x] **T10** `FixedLinePlayer` / `SpeakFixedLine` gain a completion signal
      (e.g. `Future<void> playToEnd(line)` or a `done` stream) so D11 can be
      enforced; `JustAudioFixedLinePlayer` implements it from the player's
      `processingState`. *Done when:* tests prove the future completes on the
      natural end, on `stop()`, and on a load failure (never hangs).
      *Found:* review caught that `play()` and a re-entrant `playToEnd()` did
      not complete the pending completer, orphaning the first caller — fixed by
      cancelling any in-flight completer at the top of both methods.
- [x] **T11** `PaperFailureCubit` (use cases only): speaks the kind's line on
      open, stops it on close. *Done when:* tested with a fake player.
      *Found:* straightforward — depends on `SpeakFixedLine` only, `_lineFor`
      switch is exhaustive with no wildcard so a new `PaperFailureKind` value
      forces a compile error. `FakeFixedLinePlayer` promoted from the
      test-local copy in `speak_fixed_line_test` to `fakes.dart` for reuse by
      T12+. Gate: format 0 changed, analyze 0 errors / 0 warnings / 21 info
      (pre-existing), 12/12 tests passed (5 new + 7 pre-existing
      `speak_fixed_line_test`).
- [x] **T12** `PaperFailureScreen`: F23's three pages without the text-only
      parts. Actions per kind: `offline` → «جرّب تاني» + Home;
      `serviceProblem` → «جرّب تاني» + Home; `limitReached` → Home only. RTL,
      Large Text, icon + text on every state.
      *Done when:* widget tests per kind, at the large text scale, in both
      locales. ✔ 72cea61 — 20 tests, no code-review findings.
- [x] **T13** Route `/paper-failure?kind=…` plus the retry hand-off. After a
      photo (from waiting), retry re-sends the runner's retained photo, and
      leaving without retrying deletes the temp files. Before a photo (from
      the Home gate, T15), there is nothing to re-send: retry re-runs the gate
      for the source the user tapped and, on `ready`, opens that camera or
      picker. *Done when:* routing tests cover each kind, both retries, and
      leave.

### Phase C — capture

- [x] **T14** `CaptureGateCubit` (presentation, `features/capture`): one
      `check(source)` → `CaptureGateOpen(source)` / `CaptureGateOffline` /
      `CaptureGateServiceOff`, busy-guarded so a double tap checks once.
      *Done when:* tested over a fake `CheckCaptureReadiness`.
- [x] **T15** Home: both scan controls go through the gate; `offline` and
      `serviceOff` open `/paper-failure` (offline / serviceProblem), `ready`
      opens the capture route as today. *Done when:* a routing test per
      outcome; Home's own layout is unchanged.
      *Note:* landed at 61acb2c but this checkbox was never ticked — fixed at
      T19's commit, no code change.
- [x] **T16** `ImagePreviewCubit` gains `confirm`, ending in
      `ImagePreviewConfirmed(photo)`, **beside** the old `proceed()`; the
      screen keeps calling `proceed()` until T21, so the old flow still runs.
      `confirm` hands the photo's temp files to its caller.
      *Done when:* `confirm` is tested, the existing tests still pass, and the
      "file produced after close is cleaned up" guarantees hold for both
      paths.
- [x] **T17** Crop screen restyled to the `Crop` artboard (D5): dark
      background, «؟» (inert, D6) and a small rotate control in the top bar,
      the photo with the four handles, the voice hint row «اضغط كمّل» with its
      animated bars, one 68 px «كمّل». ✕, title, hint, «صوّر تاني» removed.
      *Review:* 0 findings. dart format fix (line-wrap in test). 40 tests pass.
      *Done when:* widget tests for the layout, disabled-while-processing,
      rotate still working, RTL and Large Text.
- [x] **T18** `crop_continue` on open, stopped on leave and on «كمّل».
      *Done when:* tested.
      *Findings:* none — follows PaperFailureCubit pattern exactly; 5 cubit tests added.
- [x] **T19** Waiting screen to the `Waiting` artboard (D8): the drawn paper,
      the scan line, the voice capsule, the sentence, the dots; respects reduced
      motion. *Done when:* widget tests, including reduced motion and Large
      Text.
      *Review:* Opus 4.6, 2026-11-22. *Findings:* none. Side-fixes: T15
      checkbox+progress bookkeeping; PaperFailureScreen audit-sweep gap.
- [x] **T20** `PaperWaitingCubit`: plays `waiting_reading` on open; starts (or
      joins) the runner; on success waits for the line to finish (D11), then
      emits `navigateToPaper(id)`; on failure emits the failure kind; closing
      the cubit stops the line and leaves the runner running (D2). *Done when:*
      tests cover fast success (line still playing → waits), slow success,
      each failure, and leave-mid-flight (job still saves).
      *Review:* Opus 4.6, 2026-11-22. *Findings:* none. Added `join()` to
      `PaperExplainRunner` so the cubit can subscribe to an already-running job
      (D2 back-and-rescan). `_left` flag guards post-close emits; 13 cubit
      tests + 2 runner tests.
- [x] **T21** Routes: crop → `/paper-waiting` → `/paper/:id?fresh=1` or
      `/paper-failure`; system back on waiting → Home. This is the
      switch-over: the crop screen calls `confirm`, and `proceed()`,
      `DecideAnalysisRoute`, `CreateAnalysisSession` and both holders leave
      `ImagePreviewCubit` (their classes are deleted in Phase G). Temp-file
      ownership passes to the runner at hand-off, exactly once. `/paper/:id`
      is registered with a minimal placeholder screen that T24 replaces, so
      from here until Phase D a real run ends on that placeholder. Journey
      tests the switch breaks are brought onto the new flow here, up to the
      navigation to `/paper/:id` and enough to keep the suite green; T49
      rewrites them fully. *Done when:* routing
      tests for the whole chain with fakes, the cubit's tests rewritten, and
      the full suite green.
      *Review:* pending. *Findings:* —.
      **Owner decision (2026-11-22):** `test/integration/invoice_journey_test.dart`
      and `analysis_failure_paths_test.dart` are left **failing** rather than
      adapted now — both drive the old pipeline end to end against
      `ocr-document`/`analyze-document`, and `test/support/app_harness.dart`
      has no wiring at all for the explain pipeline (no `PaperExplainRunner`,
      no fake `explain-document` endpoint). Rewiring them properly is T49's
      job, not a T21 addendum; adapting them now to a placeholder `/paper/:id`
      would mean asserting against a screen T22–T24 haven't built yet. New
      coverage of the switch-over itself lives in
      `test/app/paper_capture_routing_test.dart` instead (confirm → explain
      run → `/paper/:id` or `/paper-failure`; system back on waiting → Home).
      Unrelated pre-existing failures found by the same full-suite run and
      **not** touched here: `shell_test.dart`, `usage_hint_routing_test.dart`,
      `manual_reminder_seed_routing_test.dart`, `reminders_scan_routing_test.dart`
      (Home has required a `CaptureGateCubit` since T15; these fixtures were
      never updated — ~26 tests) and `paper_failure_screen_test.dart`'s
      `LimitResetCard` test (hardcodes `resetAt = DateTime(2026, 11, 19)`,
      now in the past). Fixed in passing because this task's own changes
      forced those files open anyway: `explicit_ocr_fallback_test.dart` and
      `paper_failure_routing_test.dart`.

### Phase D — the result screen

- [x] **T22** `PaperView` UI model (`features/paper/presentation/models`):
      title, the header date («النهارده»/«امبارح»/«3 نوفمبر»), the present
      cards in segment order with their segment ids, the date card's month /
      day / weekday / «الساعة 10 الصبح» formatting, the phone grouped LTR.
      Pure. *Done when:* tests cover every card combination that matters, the
      date edge cases (no time, midnight, today/yesterday boundaries in Cairo
      time) and the ids asserted as literals.
      *Review:* Opus 5, 2026-11-22. *Findings:* none. Needed four new
      `AppStrings` members (`paperDateToday`, `paperDateYesterday`,
      `weekdayName`, `paperAppointmentTime`) — the morning/night split for
      the appointment time («الصبح»/«بالليل») matches the existing
      `analysisLimitResetTime` precedent («الساعة 12 بالليل»), not a fresh
      guess. 18 model tests + 4 `app_strings_test` entries.
- [x] **T23** `PaperScreenCubit` (use cases only): `WatchPaper(id)` →
      loading / ready / notFound / error; `LoadPaperImage` for the thumbnail
      (failure → placeholder, not an error). *Done when:* tested.
      DONE d352a90 — 11 cubit tests; race guard + no-double-decrypt.
- [x] **T24** The screen's frame: header (back, round thumbnail, title, date,
      inert «؟»), scroll body, fixed bottom slot for the player; loading,
      not-found and error states. *Done when:* widget tests per state, RTL,
      Large Text.
      *Review:* Opus 5, 2026-11-22. *Findings:* one — a keyed empty player-slot
      placeholder was speculative/untested, removed (the player bar lands in
      T34 as the Column's next child). `PaperScreen` reuses `ServiceStateView`
      for not-found/error and `TopBarIconButton`/`StrokeGlyph.arrowBack` for the
      back control; the thumbnail shows the decrypted photo or a drawn
      folded-paper mark; the «؟» is drawn `enabled: false` (D6). Wired into
      `/paper/:id` over `PaperScreenCubit` (new `registerFactoryParam`),
      replacing the T21 placeholder; the routing test's own DI gained the same
      registration. 5 new `AppStrings` members (`paperHelpLabel`, the two
      not-found + two error lines) in both locales + the parity map. 17 widget
      tests (states, RTL, Large Text, the F27-T15 audit sweep).
- [x] **T25** Cards «شرح الورقة», «أعمل إيه؟», «خلي بالك» to the artboard
      (icons, colours, the spoken card's highlight style). *Done when:* widget
      tests including the highlighted variant.
      *Found:* `PaperCardShell` (shared shell: teal border/background +
      speaking-indicator animation when highlighted) with three concrete cards
      — `ExplainCard`, `TodoCard`, `CautionCard` — wired into `PaperScreen` by
      `cardIds` ordering; two new `StrokeGlyph` icons added from the design
      reference. Landed at 241d1e2; this checkbox was never ticked in that
      commit (a bookkeeping gap), fixed here with no code change.
- [x] **T26** Card «ميعاد» with the `date.text` line and the bell (D13);
      `ManualReminderSeed.eventMinuteOfDay` becomes optional and the form opens
      with the time empty when the paper has none. *Done when:* card tests,
      the seed change's tests, and the reminder form's own tests unchanged
      apart from the new optional case.
      *Found:* landed at b6cc2ad; this checkbox was never ticked in that
      commit (the same bookkeeping gap T15/T25 had), fixed here with no code
      change.
- [x] **T27** Card «تكلم مين» with the call button through a new
      `OpenPhoneDialer` use case (`core/platform/usecases/`) over the existing
      `ExternalLinkService`; a failed launch shows a short message, never a
      crash. *Done when:* the use case and the card are tested with a fake
      service.
      *Found:* `tel:` needs its own `<queries>` entry in the manifest — at
      targetSdk 30+ `url_launcher` finds nothing to dial without it, same as
      F27-T20's https/mailto entries; added, with a manifest-presence test
      (`open_phone_dialer_test.dart`) mirroring `legal_pages_test.dart`'s. The
      call button's failure path needed a `PhoneDialerCubit`
      (`features/paper/presentation/cubit/`, idle/callFailed, same shape as
      `LegalLinksCubit`) rather than a bare callback, since "no BuildContext in
      a Cubit" plus "Cubits depend on use cases only" rules out a widget
      calling `OpenPhoneDialer` straight from `_cardFor`; `PaperScreen` wraps
      itself in a `BlocListener` for the SnackBar, which meant adding a second
      `BlocProvider` next to `PaperScreenCubit` at the `/paper/:id` route and
      in every test that builds that route — `paper_capture_routing_test.dart`
      (T21's) and `paper_screen_test.dart` both needed the new provider wired
      in before they would build. The phone icon is the Tabler-style handset
      path copied verbatim from the Result artboard's own «تكلم مين» card
      (`StrokeGlyph.phone`), used for both the card's header icon and the call
      button. Full `flutter test`: 29 pre-existing failures in
      `shell_test.dart` / `usage_hint_routing_test.dart` /
      `manual_reminder_seed_routing_test.dart` / `reminders_scan_routing_test.dart`
      (T21's known gap — Home has needed `CaptureGateCubit` since T15) plus one
      date-rollover flake in `paper_screen_test.dart` (`savedAt:
      DateTime(2026, 11, 22)` reads as "yesterday" now that today is
      2026-11-23) — all confirmed identical on the pre-T27 tree via `git
      stash`, none touched here. Review: removed the manifest comment (§11),
      fixed the date-rollover flake (`savedAt: DateTime.now()` instead of a
      hardcoded date).
- [x] **T28** Card «تروح فين» and the full-screen enlarged address view.
      *Done when:* widget tests, including the enlarged view at Large Text.
- [x] **T29** Status segments: one per present card, equal width; the spoken
      card's segment fills with the voice, the ones before it are full.
      *Done when:* tested for 1 to 6 cards (one = the `unsupported` paper).
- [x] **T30** Voice start (D1): a fresh paper → `readAloud(segments,
      audioId: id)`; an opened paper with `audioSaved` → `replay(audioId,
      spans)`; an opened paper without audio → `readAloud` again (F38 D11). All
      of it after any fixed line has finished (D11). *Done when:* tested for
      the three cases.
- [x] **T31** `RecordPaperReading` on every `VoicePlaybackReadFinished`.
      *Done when:* tests prove it is recorded on the finish of a fresh read
      and of a re-speak. (The `explain_partial` playback that follows a read
      lands in T40, once the line exists.)
- [x] **T32** Voice failures on the result screen: `voice_failed`; for
      `NoArabicVoiceFailure`, `no_arabic_voice` plus the open-TTS-settings
      action. *Done when:* tested.
- [x] **T33** Highlight + auto-scroll to the spoken card; a manual scroll
      stops the auto-scroll; a segment tap scrolls (streaming) or
      `seekToSegment`s (file) and turns auto-scroll back on (D16). *Done when:*
      widget tests drive both phases.
- [x] **T34** Player bar to the artboard: play/pause, 30-bar waveform
      (animated in the streaming phase, filling by position/duration in the
      file phase, tap-to-seek only in the file phase), the clock, the speed
      pill (wired in T39). *Done when:* widget tests for preparing, streaming,
      paused, file, finished and failed.
      *Review:* Opus 5, 2026-11-23. *Findings:* three, all fixed — a `///`
      comment on `PaperPlayerView.fill` (§11); the `preparing` button was
      dimmed to `alpha: 0.4` like a disabled one, which left its white spinner
      at ~1.9:1 on the pale teal, in the one state the user meets on *every*
      read (preparing is busy, not disabled, so it now keeps the full brand
      colour and only truly-disabled states dim); and a paused first reading
      rendered pixel-identical to a finished one — same 30 teal bars, static,
      same `play_arrow` — so `replay` took `Icons.replay_rounded`.
      `PaperPlayerView` (`presentation/models`) is the whole decision: which
      of three actions the button offers, whether it is pressable, the
      waveform's fill, whether it animates, and the clock. `fill: null` is the
      streaming phase's "no length to measure against" (D16) and paints every
      bar in the brand colour — progress in that phase is the segment bar's
      job (T29), not the waveform's. Seek is a `fraction`, mirrored for RTL
      from the bar's own box, so the start of the audio is the right-hand edge.
      The artboard's own footer draws a *partly filled* waveform during what is
      clearly a first reading; D16 overrides that, as the owner's decision
      beats a static mock. Equality deliberately compares `elapsed.inSeconds`,
      not the raw `Duration`, so a Live read's ~5 position events a second
      collapse to one rebuild. Every colour matches the artboard's hexes
      exactly through existing tokens (no new ones). 4 new `AppStrings` members
      + the parity map. 16 model tests + 41 widget tests + 6 on the screen
      itself (device-tier pause unpressable, replay pause/resume, fill + seek,
      failed). **Two device-pass (T52) watch items**, neither fixed here:
      TalkBack cannot scrub the waveform — it is `excludeSemantics` with a
      label and value, the same shape `PaperStatusSegments` shipped with in
      T29/T33, and exposing arbitrary seek properly means slider semantics,
      which is its own task; and the streaming phase rebuilds 30 `Container`s
      at 60 fps, which only the RMX2001 can price.
- [x] **T35** Leaving the screen stops the voice and any fixed line; back from
      a fresh paper goes Home. *Done when:* tested.
      *Review:* 1 nit fixed (guard `didPop` instead of `!fresh`);
      1 pre-existing skipped (`PaperFailureScreen` missing `addPostFrameCallback`).

### Phase E — speed (D14, D15)

- [x] **T36** `ReadingSpeed.multiplier` (0.75 / 1 / 1.25 / 1.5) beside its
      existing TTS `rate`, and `NextReadingSpeed` with the cycle 1x → 1.25x →
      1.5x → 0.75x → 1x. *Done when:* tested; the settings screen still shows
      the same four labels.
      *Review:* Opus 5, 2026-11-24. *Findings:* none. `NextReadingSpeed`
      (`core/audio/usecases/`) is a dependency-free exhaustive `switch`, so a
      fifth `ReadingSpeed` fails compilation until it is placed in the cycle;
      not registered in DI yet — T39 wires it with the pill. The Progress
      line read 32 while T01–T35 were all ticked (the T15/T25/T26 bookkeeping
      gaps); it now counts the ticks. Gate: `dart format` 1 of 941 changed
      (the new file); `flutter analyze` 0 errors / 0 warnings / 21 info
      (pre-existing); `test/core/audio`, `test/features/settings`,
      `audio_options_sheet_test` and `set_reading_speed_test` +231, all
      passed.
- [x] **T37** Kotlin: `PcmPlayer.setSpeed(multiplier)` via
      `PlaybackParams` (speed, pitch 1.0), callable mid-stream; channel method
      in `VoiceAudioPlugin`; `PcmAudioSink.setSpeed`. *Done when:* the Dart
      side is tested over a fake channel; the Kotlin half is a device-pass row
      (F37's rule: Kotlin holds no decisions and is not unit-tested).
      *Found:* `setSpeed` is a no-op when no track is open or on API < 23
      (`PlaybackParams` needs M+), mirroring the file's existing
      `Build.VERSION.SDK_INT` branching, wrapped in try/catch against an
      invalid speed; it only affects the currently-open track, not a future
      `open()` — re-applying the stored speed on every new read/replay is
      **T39**'s job. The three existing fake `PcmAudioSink`s
      (`voice_playback_cubit_test.dart`, `read_paper_aloud_test.dart`,
      `voice_playback_rig.dart`) needed a `setSpeed` stub each to keep
      compiling. **Owner skipped the `code-reviewer` (Opus) pass for this
      task** — committed straight from the Sonnet self-review. Gate: `dart
      format` 0 of 8 changed; `flutter analyze` 0 errors / 0 warnings / 21
      info (pre-existing); full `flutter test` +3767 −39, all 39 failures the
      known T21/T27 baseline (shell/usage-hint/manual-reminder/reminders-scan
      routing gaps, the `paper_failure_screen_test.dart` hardcoded-date
      `LimitResetCard` flake, and the two integration journeys left failing
      until T49) — nothing new.
- [x] **T38** `SavedAudioPlayer.setSpeed` (`just_audio`) and the device tier's
      rate through `ReadingSpeed.rate`. *Done when:* tested with fakes.
      *Built:* `SavedAudioPlayer.setSpeed(multiplier)` →
      `AudioPlayer.setSpeed` (pitch untouched, so held). The device tier gets
      `DeviceVoiceReader.setSpeed(rate)` → `ReadingQueue.setSpeed` →
      `TextToSpeechService.setSpeechRate`, routed through the queue because
      the queue owns the engine. Two scales on purpose: the players take
      `ReadingSpeed.multiplier`, the device tier takes `ReadingSpeed.rate`.
      Best-effort on the device side (the engine's `Result` is dropped, the
      same stance as a refused `setVoice`).
      *For T39:* (1) `flutter_tts`'s rate is a **global engine setting** — the
      Settings voice preview (`PreviewDefaultVoice`) and the old reader's
      `SetReadingSpeed` write the same value, so T39 must re-apply the stored
      speed before every device read, not just once. (2) On Android a rate
      change does not touch the utterance already speaking; it lands at the
      next `ReadingQueue` run, so mid-read on the device tier is "from the
      next run", not instant — a device-pass (T52) watch item. (3)
      `ReadingQueueVoiceReader.setSpeed` is not gated on a reading of its own
      being in flight (unlike `stop`), so calling it is always a write to the
      shared engine.
      *Review:* Opus 5.5, 2026-11-24. 2 nits fixed: the
      `DeviceVoiceReader.setSpeed` doc gave a wrong reason for the scale
      difference; the `just_audio` test only checked "completes" and now
      asserts `AudioPlayer.speed == 1.25`. *Found:* before a source is
      loaded `just_audio` runs on an idle stand-in platform, so no `setSpeed`
      reaches the channel — the speed is held and applied when the real
      player is created, which means a speed set before a replay sticks.
      Fakes: `FakeSavedAudioPlayer` and the cubit test's `_FakeDeviceReader`
      record `speedCalls`; the other two `DeviceVoiceReader` fakes got no-op
      stubs. Gate: `dart format` 0 of 941 changed; `flutter analyze` 0 errors
      / 0 warnings / 21 info (pre-existing); full `flutter test` −39, all the
      known T21/T27 baseline (same list as T37) — nothing new.
- [x] **T39** `VoicePlaybackCubit.setSpeed` → the current tier, mid-read or
      mid-replay; every new read or replay starts at the stored speed; the
      player's pill reads and writes `DefaultReadingSpeedStore`. *Done when:*
      tests prove the speed survives a phase change and a new paper, and spans
      still land on the right card at 1.5x (positions are content time).
      *Built:* `ReadPaperAloud.setSpeed(ReadingSpeed)` keeps the speed and
      applies it to the tier speaking now (`multiplier` to the sink, `rate`
      to the device reader). Every tier also re-applies it as it opens: Live
      after `sink.open`, on each retry, and the device tier before every
      read, which T38's global-`flutter_tts`-rate warning required.
      `ReplaySavedAudio.setSpeed` is a bare forward: `just_audio` holds a
      speed set before a source is loaded (T38). `VoicePlaybackCubit` keeps
      `_speed`, sends it to both use cases on every `setSpeed`, and sends it
      again at the start of every `readAloud`/`replay`. That is why it
      survives the phase change and a second paper on the same cubit. The
      pill is a new `PaperSpeedCubit` (`Cubit<ReadingSpeed>`, the
      `HighContrastCubit` shape) over `GetDefaultReadingSpeed`,
      `SetDefaultReadingSpeed` and `NextReadingSpeed` (now registered in DI).
      No cubit holds another, so the screen's root listener forwards every
      `PaperSpeedCubit` state to `VoicePlaybackCubit.setSpeed`.
      *Review:* Opus 5.5, 2026-11-24. Four findings, all fixed:
      (1) **bug:** the stored speed reached the pill but never the voice. A
      user at 1.5x saw «1.5x» and heard 1x, because only a tap forwarded to
      the voice. Fixed by moving the forward to one root
      `BlocListener<PaperSpeedCubit>`, which carries the loaded default and
      every tap alike. It sits at the root, not in `_Player`, because `load()`
      can answer while the screen is still loading, before `_Player` exists.
      A regression test seeds the store with 1.5x and was confirmed failing
      with the listener removed. (2) the new doc comment in
      `replay_saved_audio.dart` landed between `seek`'s doc and `seek`, so
      `seek`'s doc ended up on `setSpeed`. (3) §11: every comment this task
      added was removed (T27 and T34 removed new comments the same way).
      (4) the "spans at 1.5x" test only checked span ids, after the speed
      change had happened. It now ticks a position mid-`amount` while
      streaming at 1.5x and asserts the highlight is `amount`.
      *Found:* the root listener resolves `PaperSpeedCubit` at mount, so
      `paper_capture_routing_test.dart`'s own DI needed it registered. That
      test never reached the ready state where `_Player` used to read it, so
      the gap had been hidden. `paper_screen_test` and
      `paper_screen_voice_test` build `PaperScreen` directly and got a
      provider. `ReadPaperAloud`'s device-tier fake resolves its read at once,
      so "mid-device-read" is tested at the cubit level, whose fake holds the
      read open. Gate: `dart format` 0 of 943 changed; `flutter analyze`
      0 errors / 0 warnings / 21 info (pre-existing); full `flutter test`
      +3793 −39, all 39 the known T21/T27 baseline (same list as T37/T38).

### Phase F — the fixed lines

- [x] **T40** **Owner-gated.** Add `explain_partial` to `F37-voice-lines.md`
      with Claude's draft Arabic (starting with content, per that file's rule),
      **owner edits it and generates the asset**, then add
      `VoiceLine.explainPartial` and the asset, and wire it on the result
      screen: after T31's record, for a **fresh** `partial` paper only,
      `explain_partial` plays once (D12). *Done when:* `voice_line_test`'s
      two-way parity passes with the real asset, and tests prove the line
      plays after a fresh partial read, never on a replay, never on a success
      paper.
      *Found:* the owner ran the generator himself on his own machine (deno +
      ffmpeg + `supabase/.env`'s key are all there, and it reaches Google —
      the "dev sandboxes cannot reach Google" note is about a different
      sandbox), so the draft/edit/generate steps collapsed into one pass:
      `--only=explain_partial` produced a verbatim take on the first attempt
      (7.4 s, 31 KB). "Never on a replay" needed no `fresh`-flag check at
      all — `VoicePlaybackReadFinished` is only ever emitted by a genuine
      read (`_onReadEvent`/`VoiceReadCompleted`); a replay ends through
      `VoicePlaybackFile`/`VoiceReplayFinished` instead, so the state
      `PaperVoiceStarter` already listens for is structurally read-only. The
      line is spoken from `PaperScreenCubit.recordReading` (it already holds
      `_latestPaper`, so it can check `explanation.status` right where the
      outcome is persisted) rather than from the widget, keeping every use
      case behind a cubit (CLAUDE.md §B2) instead of adding a raw use-case
      call to `PaperVoiceStarter`. `PaperScreenCubit` gained a
      `SpeakFixedLine` dependency, which touched 5 construction sites (DI +
      4 test files). Gate: `dart format .` 0 of 943 changed; `flutter
      analyze` 0 errors / 0 warnings / 21 info (pre-existing); full `flutter
      test` +3798 −39, all 39 the known T21/T27 baseline (5 new tests, all
      passing — same list as T37/T38/T39).
      *Review:* Opus 5, 2026-11-26 — run late, during T41, because this task
      was implemented and ticked but **never committed or reviewed**; its work
      was still in the working tree when T41 started. One real defect, fixed
      here: the guard was `status == partial` alone, so `explain_partial`
      repeated on **every** device-TTS re-speak. The recorded reasoning ("a
      replay ends through `VoiceReplayFinished`, so no `fresh` check is
      needed") holds only for the saved-file tier; a paper that fell to device
      TTS has no `audioSaved` file, so pressing play **re-reads** (F38 §C, row
      3.11), and a re-speak is a genuine read that ends through
      `VoicePlaybackReadFinished` all over again. The Derived section says as
      much — `RecordPaperReading` runs on "every `VoicePlaybackReadFinished`,
      fresh read or re-speak" — so `recordReading` is a per-read hook and the
      wrong host for a once-per-paper line without its own latch. The three
      widget tests missed it because "never on a replay" used
      `audioSaved: true`, the one path the argument actually covered. Fixed
      per D12's literal wording ("plays **once** after the **first** reading")
      with both halves: `PaperScreenCubit` now takes `fresh` (the route
      already had it for `PaperVoiceStarter`; the DI param widened from
      `String, void` to `String, bool`) and holds a `_partialLineSpoken`
      latch. Two cubit tests added and each confirmed failing with the guard
      removed. Also restored the 23-line file-header comment on
      `voice_line_test.dart` that this task had deleted — §11 leaves existing
      comments in untouched code alone, and that block was the file's only
      change. Left as it is, now pinned by this task's own test: a failed
      `RecordPaperReading` suppresses the line (`result.isErr` returns early);
      flagged for the owner rather than changed, since D12 ties the line to
      the reading ending, not to the write landing.
- [x] **T41** Remove `fail_unsupported` (D10): enum value, asset, table row,
      and any reference. *Done when:* parity test passes and a grep for the id
      is empty outside history docs.
      *Found:* nothing in `lib/` or `test/` referenced the line — the only
      live reference was the enum value itself, since D10's screen never
      existed in the new flow (`PaperFailureKind` has only `offline |
      limitReached | serviceProblem`, T09). The three artifacts
      `voice_line_test` holds to parity — table row, enum value, asset —
      were removed together, so neither direction of the guard can pass
      against a half-removal. The surviving mentions are all history, which
      this task's "Done when" allows: F37's own «ثلاث حالات» section (the
      line is the recorded example of a first-person "مقدرتش أقرا" phrasing
      that took three generator attempts — worth keeping for whoever writes
      the next line) and D10 + the Files list here. The table's `#` column
      was renumbered 6–13 → 5–12; the `id` column is the real key, for the
      generator and for the test, and was untouched. The totals line was
      stale before this task and is now measured rather than estimated: the
      twelve remaining files are 238,367 bytes (~233 KB), and the duration
      is 60 − 6.2 + 7.4 ≈ 54 s. **Phase F ends here.** Gate: `dart format .`
      1 of 943 changed (the router, from T40's fix); `flutter analyze`
      0 errors / 0 warnings / 21 info (pre-existing); full `flutter test`
      **+3800 −39** — the 39 are the known T21/T27 baseline, confirmed file
      by file (`shell_test` 18, `usage_hint_routing` 6,
      `analysis_failure_paths` 5, `invoice_journey` 4,
      `manual_reminder_seed_routing` 3, `reminders_scan_routing` 2,
      `paper_failure_screen` 1), and +3800 is T40's +3798 plus this pass's
      two new cubit tests. Nothing new.

### Phase G — the old pipeline goes (after T21 switched the flow)

Run F35's deletion routine for every task here: `flutter analyze` finds the
call sites, the **suite** finds the journeys, `grep -rn "hasLength(" test/`
finds the count guards, a `[Name]` grep over **all** deleted classes finds the
dangling doc links, and a grep for the removed flow's own words ("ocr",
"review", "tesseract", "extracted text", "online route") over `lib/` and
`test/` finds the stale prose. `keptForOldBuilds` keeps any server error code
1.0.x still sends.

- [x] **T42** Router: delete `/ocr`, `/ocr-review`, `/result`, `_saveResult`,
      `_UsageHintOnLeave`, and the shell's usage SnackBar listener +
      `UsageHintHolder` (D18). *Done when:* routing tests updated, no route
      references a deleted screen.
      *Built:* the three route constants and their `GoRoute` blocks, plus
      `_saveResult`, `_UsageHintOnLeave`/`_UsageHintOnLeaveState` and
      `_storeUsageHint`, are gone from `app_router.dart` (−299); the shell lost
      its holder field, `initState`, `didChangeDependencies`, `dispose` and
      `_showUsageSnackBar` (−58). `UsageHintHolder` itself is deleted — D18
      says it "goes with the old result route", and no later task owns it:
      T43 is `features/analysis/presentation` and T44 the old analysis
      domain/data, neither of which reaches `core/usage/`. Its three tests and
      the four routing tests that registered it only to satisfy the shell
      (`manual_reminder_seed`, `paper_capture`, `paper_failure`,
      `reminders_scan`) were cleaned with it. Four test files that exist only
      to drive the deleted routes were removed: `usage_hint_routing` (F26-T04),
      `explicit_ocr_fallback` (F20 §1), and the two integration journeys T21's
      owner decision left failing until T49.
      *Review:* Opus 5, 2026-11-26 — three findings, all fixed here. **(1)**
      The Sonnet pass stopped at the shell and left `UsageHintHolder`
      registered in `service_locator.dart` and named in a `ScaffoldWithNavBar`
      doc comment, so the class survived as orphaned production code that D18
      names and no later task claims; the class, its registration, its import,
      its test and the four test registrations above are now all gone.
      **(2)** Deleting the routes falsified four comments in *retained* code
      that cross-referenced them — `documentDetails` was introduced as sharing
      a layout with "the result route", its `AudioReaderCubit` as "mirrors the
      `/result` route", its `Builder` as the trap "the `/ocr` and `/ocr-review`
      routes **above** already work around", and `_BackToHome`'s doc named "a
      session, an OCR result" as the subjects the scan routes carry, none of
      which is true of its five remaining callers. The dangling clause was
      excised from each and the substantive reason kept; no new prose added
      (§11). **(3)** The generic review skill wrote a `docs/learning/` handoff,
      which is not this repo's convention — outcomes live in this file — and
      its recorded assumption ("the class will be swept in T43") was the wrong
      call in finding (1); removed, and the outcome recorded here instead.
      *Left for T48:* `homeUsageRemaining` (the three string files +
      `app_strings_test`) is now unused in `lib/`, and the T21 comment on
      `ImagePreviewScreen.onConfirmed` still contrasts the new path with "OCR
      or the old analysis result screen" — both belong to the strings/prose
      sweep that runs after the last deletion, not here. `OcrSessionHolder`,
      `ImageAnalysisSessionHolder` and `AnalysisResultCubit` stay registered
      in DI: unreachable from the router now, but their classes live in the
      trees T43/T44 delete.
      Gate: `dart format .` 0 of 937 changed; `flutter analyze` 0 errors /
      0 warnings / 21 info (pre-existing); full `flutter test` **+3790 −24** —
      the 24 are exactly T41's 39 baseline minus the three deleted files
      (`usage_hint_routing` 6, `analysis_failure_paths` 5, `invoice_journey`
      4), leaving `shell_test` 18, `manual_reminder_seed_routing` 3,
      `reminders_scan_routing` 2, `paper_failure_screen` 1. The pass count
      drops 3800 → 3790 as the deleted files' passing tests go with them.
      Nothing new.
- [x] **T43** Delete `features/analysis/presentation` (result screen, OCR
      review, cubits, holders, progress view, reading lens, the old failure
      widgets). *Done when:* analyze clean, suite green.
      *Built:* 25 `lib/` files and 15 test files deleted (−9 213 lines). DI
      cleaned: `AnalysisResultCubit`, `OcrReviewCubit`,
      `ImageAnalysisSessionHolder` registrations and their imports removed;
      `BuildAnalysisResult` kept (it lives in `analysis/domain`, deleted by
      T44). Two retained files touched: `reading_queue.dart` removed a
      parenthetical naming `OcrReviewCubit`; `save_document_cubit.dart`
      removed its doc block that contrasted itself with the now-deleted cubit.
      Remaining dangling references — `analysis_source.dart` and
      `ocr_image.dart` doc comments mentioning the deleted cubits — are in
      `analysis/domain/`, which T44 deletes; `service_locator.dart:1022`'s
      comment mentioning `AnalysisResultCubit` belongs to T48's prose sweep.
      *Review:* Opus 4.6, 2026-11-26 (committed in a prior session; tick +
      findings added here). *Findings:* none.
      Gate: `dart format .` 0 of 900 changed; `flutter analyze` 0 errors /
      0 warnings / 19 info (pre-existing); full `flutter test` **+3562 −24**
      — the 24 are T42's baseline (`shell_test` 18,
      `manual_reminder_seed_routing` 3, `reminders_scan_routing` 2,
      `paper_failure_screen` 1); the pass count drops 3790 → 3562 as the
      deleted presentation tests (228) go with their code. Nothing new.
- [ ] **T44** Delete the client's old analysis domain/data: `OcrImage`,
      `AnalyzeDocument`, `ShouldFallBackToOnDeviceOcr`, the repository, DTOs,
      mappers, validator, mock/fixture sources, `DecideAnalysisRoute`,
      `AnalysisRoute`, `CreateAnalysisSession` if now unused,
      `DailyUsage.onlineOcrEnabled`, and their DI. *Done when:* analyze clean,
      suite green, `deno test` untouched.
- [ ] **T45** Delete `features/ocr`, `flutter_tesseract_ocr`,
      `assets/tessdata*`, the traineddata, any Gradle/ProGuard bits for it, and
      update the play-compliance tool/test. Remove `AppFailure` leaves only the
      deleted code produced (`OcrInitializationFailure`, `OcrFailure`,
      `NoTextDetectedFailure`, `OnlineOcrUnavailableFailure`, and any other the
      compiler shows orphaned), with `keptForOldBuilds` entries for codes 1.0.x
      still reports. *Done when:* the APK builds, analyze clean, suite green,
      and the release APK size is recorded here.
- [ ] **T46** Delete the dev harness (`voice_harness_screen.dart`, its route,
      the `VOICE_HARNESS` define) and adjust `voice_harness_guard_test`
      (delete it or turn it into "no dev route exists"). *Done when:* suite
      green.
- [ ] **T47** Delete the `core/widgets/result_*` widgets, strings and assets
      used only by the deleted screens — keeping every one
      `DocumentDetailsScreen` still uses (F41). *Done when:* analyze clean.
- [ ] **T48** Strings sweep over the three files + `app_strings_test`, and the
      prose/greps sweep above over all of `lib/` and `test/`, **after** the last
      deletion. *Done when:* the greps return only history.

### Phase H — journeys and docs

- [ ] **T49** Journey tests (`test/integration/`): rewrite
      `invoice_journey_test` and `analysis_failure_paths_test` for the new flow
      — Home → gate → crop → waiting → result reads; offline before capture;
      service off; daily limit; retry; back during waiting still saves.
      `app_harness.dart` gets a fake for every new DI-registered platform
      service. *Done when:* green, with no real delay (`settle()` idiom).
- [ ] **T50** Docs: `API_CONTRACT.md` §33.4 (the line now exists) and §33.7
      (the "unreadable" row lands on «حصلت مشكلة»; `UNSUPPORTED_APP_VERSION`'s
      missing update screen recorded) — **that file is CRLF, never `sed -i`
      from Git Bash**; F38's "Open for the owner" #1 marked closed; F34's
      Amendments: F39/F40 marked closed (T01 added the pointer), and its stale
      F36 / F38 status words and "do not have task files yet" line brought up
      to date. *Done when:* the docs match the code.
- [ ] **T51** Full gate: `dart format .`, `flutter analyze`, `flutter test`,
      `deno test --allow-env --allow-net supabase/tests`, counters read and
      recorded; `/flutter-code-review`; a whole-branch `code-reviewer` (opus)
      pass with every action item fixed. *Done when:* all recorded here.

### Phase I — the final test list on the device

- [ ] **T52** Run the app on the RMX2001 and walk the list below **with the
      owner**. Every problem found is fixed (each fix through the same
      review → commit loop) and its row re-run before the merge. Then
      `/explain-feature`, then `@git-expert` opens the one PR (D19).

## Files

**New** — `features/capture/domain/usecases/check_capture_readiness.dart`,
`.../domain/services/image_downscaler.dart`,
`.../data/services/image_package_downscaler.dart`,
`.../domain/usecases/downscale_photo.dart`,
`.../presentation/cubit/capture_gate_cubit.dart` (+ state);
`core/platform/usecases/open_phone_dialer.dart`;
`features/explain/domain/usecases/explain_and_save_paper.dart`,
`.../domain/services/paper_explain_runner.dart`,
`.../presentation/{cubit,screens,widgets}/` for waiting and failure;
`features/paper/presentation/{cubit,screens,widgets,models}/` for the result
screen, cards, segments, player and the enlarged address.

**Changed** — `core/usage/*` (`explainEnabled`), `core/voice/*` (completion
signal, speed), `core/audio/reading_speed.dart`, `features/voice/*` (speed on
each tier), `android/.../voice/{PcmPlayer,VoiceAudioPlugin}.kt`,
`features/capture/presentation/{cubit/image_preview_*,screens/image_preview_screen}.dart`,
`features/home/presentation/screens/home_screen.dart` (where the scan controls
lead), `features/reminders/presentation/models/manual_reminder_seed.dart`,
`app/router/app_router.dart`, `app/di/service_locator.dart`,
`app/shell/scaffold_with_nav_bar.dart`, the three string files,
`docs/features/F37-voice-lines.md`, `assets/voice_lines/`, `pubspec.yaml`.

**Deleted** — `features/ocr/`, `features/analysis/` (all of it, once T08 has
copied what survives), `app/dev/voice_harness_screen.dart`,
`core/usage/usage_hint_holder.dart`, the `result_*` widgets only the old screen
used, Tesseract and its assets, `assets/voice_lines/fail_unsupported.m4a`.

**No new dependency.**

## Risks

- **F37's open defect: one Live read in four falls to device TTS.** F38-T10
  logs the socket's close code now; the device pass counts the engine per paper
  and reads the codes. Do not spend a fix on a guess — F37's note explains what
  each guess trades against "speech starts after about a second".
- **D9 might not be the whole timeout story.** If reads still hit the 4 s cap
  with a 2000 px photo on a calm host, the cause is the reading chain, and the
  fix is F36's, not this feature's.
- **The `AUDIOFOCUS_LOSS` trap (D11)** is invisible to unit tests — a fixed
  line started over a live reading kills it permanently. The ordering is tested
  in the cubits, and the device pass has a row that tries to break it.
- **Speed on `AudioTrack` (T37)** is Kotlin on a cheap API 30 device and only
  the device can prove it.
- **D2's background save** can outlive every screen; a crash or a kill mid-job
  loses that paper with the slot already counted. Accepted: rare, and the
  alternative was making the user wait with no way out.
- **A database failure after a successful explain** spends a slot with nothing
  to show. Rare; it lands on «حصلت مشكلة» and is logged.
- **New papers are invisible after their screen until F41.** Not releasable
  alone — say so in the PR body.
- **The deletion is large.** F35 found every class of leftover the hard way;
  Phase G's routine is the mitigation, and it runs after the last deletion, not
  during it.

## Testing

- **Domain/data:** the gate, the downscaler, the runner (including leave-mid-
  flight), the failure mapping walking every leaf, the completion signal, the
  speed cycle.
- **Cubits:** every new cubit, with the D11 ordering asserted explicitly.
- **Widgets:** every new screen in both locales, RTL, at the largest text
  scale, with icon + text on every state (never colour alone).
- **Journeys:** T49.
- **Privacy guard:** every new `toString()`, log call and error report asserted
  to carry no word of the page (F37-T03 / F38's guards).
- **No real delays.**
- **The device pass finds what tests cannot** — F37 found five defects behind
  3,235 green tests.

## Final test list (T52)

Run by Claude on the RMX2001 (API 30) with the owner holding the phone. Each row
records what was actually observed; a row not run says so.

### 0 · Setup

| Step | What |
|---|---|
| 0.1 | **A quiet host:** Docker + `supabase start` + `supabase functions serve --env-file supabase/.env` and **nothing else heavy** — no Gradle build running beside them (the build happens first, then the stack) |
| 0.2 | `supabase/.env` has `GEMINI_API_KEY` **and** `GEMINI_OCR_MODELS` |
| 0.3 | Local DB: `analysis_enabled = true`, `explain_enabled = true` |
| 0.4 | `adb reverse tcp:54321 tcp:54321`; `flutter run -d <RMX2001> --flavor dev -t lib/main_dev.dart --dart-define=SUPABASE_URL=http://127.0.0.1:54321` |
| 0.5 | An Arabic TTS voice installed (for the device-tier rows) |
| 0.6 | `explain_partial.m4a` generated by the owner (T40) |

### 1 · Photograph → explain, first and on a quiet host (owner's order)

| ID | Do | Expect / record |
|---|---|---|
| 1.1 | Camera → a real paper → «كمّل» | Waiting, then the result opens and speaks. **Record:** the uploaded image's bytes, the read stage's per-leg durations and the explain stage's duration from the function log |
| 1.2 | Same with a **gallery** photo taken at full resolution | Same; the uploaded size is the shrunk one (D9) |
| 1.3 | If 1.1 or 1.2 times out | Stop. Record the per-leg timings; a timeout on a quiet host with a shrunk photo is F36's reading chain, not contention |

### 2 · The capture flow

| ID | Do | Expect |
|---|---|---|
| 2.1 | Aeroplane mode, tap the shutter | «مفيش إنترنت» + its voice line, **before** the camera opens |
| 2.2 | Same for the gallery control | Same |
| 2.3 | `explain_enabled = false`, relaunch, tap the shutter | «حصلت مشكلة» + its line, before the camera |
| 2.4 | Crop opens | `crop_continue` plays; the big «كمّل» is at the bottom (the line's description is true); «؟» does nothing; rotate turns the photo |
| 2.5 | Drag a handle, rotate, «كمّل» | The confirmed framing is what the result's thumbnail shows |
| 2.6 | Tap «كمّل» while `crop_continue` is still speaking | The line stops; `waiting_reading` plays |
| 2.7 | Waiting: system Back | Home at once; the paper still saves (check the DB / `paper_images/`) and is **not** read aloud |
| 2.8 | Daily limit spent (set `daily_limit` low) | Photo → waiting → «خلّصت ورق النهارده» + its line |
| 2.9 | Kill the network mid-wait | «مفيش إنترنت»; «جرّب تاني» with the network back succeeds with the **same** photo |
| 2.10 | A photo that is not a paper | An ordinary result with one honest card; saved; the quota is not spent |
| 2.11 | No temp files left in `cache/` after 1.1, 2.7 and 2.9 | `adb shell ls` the cache |

### 3 · The result screen

| ID | Do | Expect |
|---|---|---|
| 3.1 | A paper with every card | All six in order; the spoken card is highlighted and its segment fills; the screen follows the voice |
| 3.2 | Scroll by hand mid-read | The voice carries on, auto-scroll stops |
| 3.3 | Tap a segment mid-first-read | Scrolls to that card, voice unchanged, auto-scroll back on |
| 3.4 | After the first read finishes, play again | Replays from the file: waveform fills, tap-to-seek works, a segment tap jumps the audio |
| 3.5 | Offline, then play on the same screen | Plays from the encrypted file (F38 §E1/E2/E3) |
| 3.6 | Speed pill | Cycles 1x → 1.25x → 1.5x → 0.75x, mid-read on Live, mid-replay and on device TTS; highlighting stays on the right card at 1.5x; the settings row shows the same value afterwards |
| 3.7 | Bell on ميعاد | The manual reminder form opens with the date (and time when there is one) filled |
| 3.8 | Call button | The dialer opens with the number |
| 3.9 | «كبّر العنوان للسواق» | Full-screen large address |
| 3.10 | A `partial` paper | `explain_partial` plays once **after** the reading, not on replay |
| 3.11 | Live blocked (stop `live-token`) | Device TTS reads it; row shows `engine: deviceTts`, `audioSaved: false`; play again re-speaks (F38 §C) |
| 3.12 | Both tiers blocked, or no Arabic voice | `voice_failed` / `no_arabic_voice` + the TTS-settings action |
| 3.13 | Back | Home; the voice stops at once |
| 3.14 | Large Text at the maximum | Every screen still usable |

### 4 · Carried from F38's checklist

| ID | Row |
|---|---|
| 4.1 | §B3 — `paper_images/<id>/image.enc` and the encrypted `.m4a` exist |
| 4.2 | §D0a/D0b — no `voice_enc_*.m4a` left after a failed or cancelled read |
| 4.3 | §G — `du` the private storage after a handful of papers; write the per-paper averages into F38's D8 |
| 4.4 | §F and "reopen an old paper after a restart" — **moved to F41** (D17) |
| 4.5 | F37 §E1 (never run) — a real incoming call mid-read: the read pauses or stops, it never speaks under the ringtone |
| 4.6 | F37 §E2 (never run) — end the call: nothing resumes speaking into a silent room, or it resumes from the right place |
| 4.7 | F37 §E3 (left for F40) — leave the result screen mid-read, open Settings' voice preview: only the preview speaks (T35 stops the reading on leave, so the two cannot overlap by design) |

### 5 · Counting F37's defect

| ID | Record |
|---|---|
| 5.1 | Over every paper read in this pass: how many were Live, how many fell to device TTS, and the close codes logged for each fall (F38-T10) |

## Definition of done

52 / 52 tasks ticked with findings inline; the full gate green with counters
read; every T52 row run and recorded, every problem found fixed and re-run;
`@code-reviewer` passed on the whole branch; `/explain-feature` held; then one
PR into `develop` (D19), its body saying the build is not releasable before F41.

**Follow-ups outside this branch, owned by the owner:** `GEMINI_OCR_MODELS` as a
secret on the hosted staging and production projects before `explain-document`
is used there (F38's deploy follow-up).
