# F27-T15 — UI audits (large text, LTR, UI-thread work, temp files)

Full-app sweep against the four acceptance items in F27's T15 row: **large
text with no overflow**, the **LTR/English audit** Q6 made mandatory, **heavy
work off the UI thread**, and **temp and session files reliably removed**.

Method, in order: build an automated layout sweep over every screen and let it
find what reading cannot; read every call site the greps turn up for the two
direction-sensitive and locale-sensitive patterns; then trace the two
non-visual items — what runs on the UI isolate, and what the scan leaves on
disk — through the code that owns them.

> **Scope note for the owner.** F27's T15 row lists all four items, while the
> later "What F12 leaves behind" section (added with Q7) sends F12-T05
> *performance profiling* to **T18** and F12-T06 *cache cleanup verification*
> to **T16**. This task did the audit and the fixes for all four, because the
> row is the task definition and because both turned up real defects. What it
> deliberately did **not** do is the part that needs a phone in hand: no
> profile was recorded on a device, and the cleanup fix has not been watched
> on a real filesystem. Those stay with T18 and T16.

---

## 0. The finding that had to come first: the suite was measuring the wrong font

Before this task, **every widget test in the project laid text out in
Flutter's placeholder test font**, whose glyphs are all one em wide. Cairo's
real advances are roughly half that. Measured with a `TextPainter` at the
app's own 12.5 px caption size:

| Text | Cairo | Placeholder font | Ratio |
|---|---|---|---|
| `Not available right now` | 121.1 px | 287.5 px | **2.37×** |
| `Notification permission` | 122.1 px | 287.5 px | **2.35×** |
| `غير متاح دلوقتي` | 81.1 px | 187.5 px | **2.31×** |

So every large-text check written across F11–F26 — the ~55 places where a
test passes a `TextScaler` — was checking a font the app never ships, about
2.3× too wide. The first thing the
new sweep reported was a `SettingsStatusRow` overflowing by 29 px in English
at *normal* text size — which turned out to be entirely this artefact, and
vanished once Cairo was loaded.

**Fixed**: [`test/flutter_test_config.dart`](../../test/flutter_test_config.dart)
now registers `assets/fonts/Cairo.ttf` with a `FontLoader` before the suite
runs. It has to happen there rather than inside a test: `FontLoader.load`
awaits real file I/O, and a `testWidgets` body runs in a `FakeAsync` zone
where that future never completes.

**Fallout across the whole suite: two tests.** Both asserted a layout that
only happens when text is wide, and both were calibrated against the fake
font:

- `result_details_card_test.dart` — "drops a long value under its label". The
  card measures with a `TextPainter` and stacks label over value when the two
  will not fit side by side; with Cairo's metrics, at the test window's 800 dp,
  they fit. Now runs at a phone width, which is the condition the behaviour is
  actually for.
- `teal_top_bar_test.dart` — "a title grows the bar at a large text scale".
  Same cause, same fix.

Nothing else in 2,266 tests depended on it.

---

## 1. Large text, no overflow

### The sweep

New: [`test/support/ui_audit.dart`](../../test/support/ui_audit.dart). Each
screen's own test file calls `auditScreenLayout` once, handing over its
existing pump closure; the helper then renders that screen across

- **both shipped languages** (Q6) — Arabic drives RTL, English drives LTR,
- **three text scales** — 1.0, 1.5 (the app's own `TextSize.veryLarge`
  ceiling) and 2.0, deliberately past it,
- on a **360 × 640 logical surface**: the 720 × 1280 budget Android screen at
  DPR 2, narrower than the owner's RMX2001 (360 × 800) and much shorter, so
  both axes are under pressure at once.

**18 screens × 6 combinations = 108 new tests.**

Why the surface matters more than the scale: `flutter_test`'s default window
is 800 × 600 logical — wider than any phone the app ships on and shorter than
all of them. A row that overflows at 360 dp has room to spare at 800 dp, so
**no existing test could see horizontal overflow at a real phone width**,
however large its text scale. That, plus §0, is why a sweep was worth building
rather than reading screens by eye.

A failure names the screen, the locale, the scale and the size, and prints the
whole `FlutterErrorDetails` — including the error-causing widget and its
source line. `takeException` alone hands back a `RenderFlex` overflow's
message with nothing to say *which* row, which is the part an audit needs, so
the helper collects reported errors itself and restores
`FlutterError.onError` before asserting (the binding asserts hard if a test is
still holding the handler when an `expect` fails).

### Coverage is enforced, not assumed

[`test/app/ui_audit_coverage_test.dart`](../../test/app/ui_audit_coverage_test.dart)
reads every `*Screen` class under `lib/**/screens/` off disk and every
`auditScreenLayout('…')` call out of the test sources, and fails when a screen
has no entry — or when the sweep names a screen that no longer exists. Same
shape of guard as `native_permission_copy_test` (F27-T10). Mutation-checked
both ways by renaming one entry: the missing-screen test and the stale-name
test each failed, then passed again once restored.

That guard immediately found its own gap: **`OcrProcessingScreen` had no test
file at all** — the only screen in the app with none. Closed by
[`test/features/ocr/ocr_processing_screen_test.dart`](../../test/features/ocr/ocr_processing_screen_test.dart):
the sweep plus five behaviour tests over its three pages (waiting, failed,
no-usable-text), the automatic hand-off, and English.

### What it found

**`ReminderSuccessScreen` overflowed the bottom by 84 px**, in both languages,
at ×2 on a 360 × 640 phone. Its body was a `Center > Padding > Column` with no
scroll view, so a tick, a title, a card and two full-width buttons had nowhere
to go. **Fixed** with the pattern `OnboardingScreen` already uses — a
`LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight:
constraints.maxHeight)`, which centres the block when it fits and scrolls when
it does not. Verified by the sweep, which failed on it before the change.

Every other screen passes all six combinations.

### What the sweep cannot see

Two things Flutter reports no error for, by design, so they were read by hand
rather than asserted:

- **Clipped text** — `maxLines` with `TextOverflow.ellipsis` truncates
  silently. Mostly deliberate here (document titles in a list, a one-line
  summary), so a blanket assertion would be noise rather than signal.
- **Content a scroll view absorbs** — correct behaviour, and indistinguishable
  from a layout that happens to fit.

### Recorded, not changed

- **`SettingsStatusRow` gets cramped before it breaks.** The status pill is a
  non-flex child, so it takes its natural width and the `Expanded` label gets
  the rest. With the longest pill text in English — «Not available right now»
  — at ×1.5 on a 360 dp phone the label is left about 83 dp and wraps hard. It
  does not overflow at any scale the app offers, so this is a readability
  observation, not a defect, and the row's shape comes from the approved
  design. Noted here rather than redesigned unilaterally — the same call
  F12-T01 made about `AppColors.light`'s two contrast gaps.
- **The app replaces the OS text scaler rather than respecting it.**
  `_appBuilder` sets `MediaQuery.textScaler` from the user's own `TextSize`
  (`core/accessibility/text_size.dart`), unconditionally. A user who has set
  200 % in Android's accessibility settings gets 100 % inside this app until
  they find the in-app setting, and the app's own ceiling is 1.5. That is
  deliberate and documented (F11-T05: the UI is tuned for that range), and the
  sweep now proves 2.0 is safe on every screen — so honouring the OS setting,
  or taking the larger of the two, is now a smaller change than it was. **An
  owner decision, not a bug**; no behaviour was changed here.

---

## 2. LTR / English audit

English ships (Q6) and the locale is user-switchable (`LocaleCubit`), so every
direction-sensitive and locale-sensitive construct needed checking in both
directions. F12-T02 audited RTL; this is the other half, and it found what
looking only at Arabic could not.

### Fixed

**Four chevrons pointed backwards in English.** `StrokeGlyph.chevronForward`
is drawn pointing *left* — forward in Arabic — and its own doc comment says
"Mirror it for LTR; `StrokeIcon` does not do that for you". Three call sites
in [`settings_section.dart`](../../lib/core/widgets/settings_section.dart)
(`SettingsNavRow`, `SettingsValueRow`, `SettingsLinkRow`) and one in
[`document_list_item.dart`](../../lib/features/saved_papers/presentation/widgets/document_list_item.dart)
did not, so in English the "this row opens something" affordance on the
settings list and on every saved-paper card pointed the wrong way.

Fixed once, in one place: [`ForwardChevron`](../../lib/core/widgets/forward_chevron.dart)
(`core/widgets/`, per CLAUDE.md §2 — it is now used in four places).
[`forward_chevron_test.dart`](../../test/core/widgets/forward_chevron_test.dart)
pins the flip in both directions, and adds a grep guard: any *new* file that
reaches for the raw glyph fails it, with the three pre-existing hand-mirrored
call sites (checked in F12-T02) allowlisted by name.

**The crop handles spoke Arabic to English screen readers.**
`draggable_crop_overlay.dart` carried four hardcoded Arabic `Semantics`
labels — «مقبض القص أعلى» and the other three edges — the app's only
hardcoded Arabic left in a widget. A TalkBack user running the app in English
heard them in Arabic. Now `previewCropHandleTop/Bottom/Left/Right` in
`AppStrings`, in both languages, covered by `app_strings_test`'s parity check;
`draggable_crop_overlay_test` reads them from `ArStrings` instead of
duplicating the literals, so the English side cannot drift.

### Checked, no change needed

- **Hardcoded direction** — `grep` for `TextDirection.` across `lib/` returns
  five hits, every one of them a `Directionality.of(context) == …` read used
  to decide a mirror. No `Directionality` widget forces a direction anywhere,
  and **no `TextAlign.left` or `TextAlign.right` exists in the app at all**.
- **Hardcoded Arabic in UI code** — after the crop-handle fix, a sweep for
  Arabic string literals outside `core/localization/` finds nothing that
  reaches the screen. What remains is deliberate and non-UI: the TTS number
  and month words (`normalize_spoken_numbers.dart`), the OCR extractors'
  Arabic month table, and the mock fixtures' sample bill.
- **The Android notification channel name** (`'التذكيرات'`, passed in
  `service_locator.dart`) is Arabic unconditionally. Not a finding:
  `FlutterLocalNotificationsPort`'s own doc comment already records the
  decision — it is a label on Android's per-app settings page, not something
  the app renders, and threading the saved locale through the launch sequence
  for one string was judged not worth it (F09-T10).
- **Dates, times and months** go through `AppStrings` (`monthName`, `timeAm` /
  `timePm`) in `core/time/document_date_label.dart`, so `25 أغسطس 2026`
  becomes `25 August 2026` with no `intl` and no locale assumption.
- **Directional icons generally** — the other `chevronForward` and `arrowBack`
  call sites all mirror correctly, as F12-T02 found; `chevronDown` is vertical
  and must not flip.
- **The English leg of the layout sweep** (§1) now renders all 18 screens in
  English at three scales, which is the first systematic check that English
  copy — reliably longer than the Arabic — fits.

---

## 3. Heavy work off the UI thread

A read of every CPU-bound path in the app. The picture was already mostly
good: image decode, crop, rotate, quality assessment and OCR preprocessing all
run in `Isolate.run` already, SQLite runs in a background isolate
(`drift_flutter`'s default is `NativeDatabase.createBackgroundConnection`),
there is **no synchronous file I/O anywhere in `lib/`**, and the only
`jsonDecode` calls are over small payloads. Two real violations, both fixed.

### AES-256-GCM ran on the UI isolate

`pubspec.yaml` depends on `cryptography` with **no `cryptography_flutter`**, so
`AesGcm.with256bits()` is the package's pure-Dart implementation: it does all
its work on whichever isolate calls it, `async` signature notwithstanding. A
saved page is a multi-megabyte JPEG, and
[`AesGcmFileEncryptor`](../../lib/core/crypto/aes_gcm_file_encryptor.dart) was
called from the UI isolate twice in the normal flow — encrypting when the user
saves a paper with its picture, and decrypting **every time they open one**.

**Fixed**: both the cipher calls now run inside `Isolate.run`. Reading the key
stays outside, because secure storage is a platform channel and only the root
isolate has one.

On the key: `Isolate.run` **copies** what the closure captures — being in the
same isolate group does not mean a shared mutable heap — so a copy of the key
bytes exists in a second isolate for the length of the call. That copy stays
inside this process: no file, no log, no wire format, nothing a profiler or
another app can reach that could not already reach the original. The copy is
also the reason this trade only makes sense at page size — a few megabytes of
memcpy against tens to hundreds of milliseconds of pure-Dart AES on a low-end
phone. The encryptor's existing eight tests — round-trip, empty
input, tampered tag, flipped body byte, short input, wrong key — all still
pass unchanged, which is what matters for a change inside a cipher.

### base64 of the page image ran on the UI isolate

[`default_analysis_repository.dart`](../../lib/features/analysis/data/repositories/default_analysis_repository.dart)
base64-encoded the captured image for the online reading request on the
calling isolate — a few megabytes in, a third larger out — right as the wait
screen's animation starts. **Fixed**: `Isolate.run(() => base64Encode(bytes))`.

### Residual, recorded for T18

- **Dio serialises that request body to JSON on the UI isolate.** The base64
  string is now produced off-thread, but handing a map containing a ~5 MB
  string to Dio means one more pass over it on the way out. Moving that would
  mean either a custom transformer or encoding the whole body in an isolate —
  a bigger change than T15 should make blind. It belongs behind a measurement.
- **No profile was taken on a device.** Everything above is a static finding;
  the actual frame timings on the RMX2001 and the ELS NX9 are T18's, per Q7.
  What T15 can say is that the two paths which *must* have been janking no
  longer run where they were running.

---

## 4. Temp and session files

The rule is CLAUDE.md §7: «تُحذف النسخة غير المشفّرة والملفات المؤقتة بعد
الانتهاء», and `AnalysisSessionStorage`'s own doc comment promises "no
unencrypted page image outlives its analysis".

### What was already right

The capture flow's own temp files — the source, the rotated copy, the
manually-cropped copy — are handled carefully and were left alone.
`ImagePreviewCubit.close()` deletes them unless it handed ownership to
`ImageAnalysisSessionHolder`, which deletes them in `clear()`, from both
`cleanupImage()` and `close()` — so Retake, Pick another, Analyze and a plain
back-out all converge on a delete. `encryptAndStore` deletes the plaintext it
just encrypted. `deleteStaleSessions()` runs as a launch step.

### What was wrong

**The analysis session folder outlived the analysis, and accumulated.**
`<app cache>/analysis_sessions/{id}/processed.jpg` is an unencrypted copy of
the user's page. Nothing deleted it when the scan ended:

- `ImageAnalysisSessionHolder.clear()` deletes the *capture* temp files; the
  session copy was never in that list.
- `OcrSessionHolder.clear()` touches no files at all.
- `AnalysisResultCubit` had no `close()` override.
- The only cleanup was `deleteStaleSessions()` **at launch** — and Android can
  keep a process alive for days. So a user who scans three papers a day and
  saves the *result only* (the default storage mode) accumulated one
  unencrypted page image per scan, for as long as the app stayed resident.

Saving a paper *with* its picture happened to clear the file, because
`encryptAndStore` deletes its source — which is exactly why the gap was easy
to miss: the path that keeps the image was clean, and the path that keeps
nothing was not.

### Fixed

1. **A new session clears the previous one.**
   `FileAnalysisSessionStorage.createSession` now calls `deleteStaleSessions()`
   first. Only one analysis is ever in flight — the capture flow creates the
   session before OCR and clears both hand-off holders first — so every
   existing folder is from a finished or abandoned run. This bounds the cache
   at one session whatever the user does, including every abandon path
   (Retake, Pick another, back out of `/ocr`).
2. **The result screen deletes its own session on the way out.** New
   `AnalysisSessionStorage.deleteSession(id)` →
   [`DiscardAnalysisSession`](../../lib/core/storage/usecases/discard_analysis_session.dart)
   (in `core/`, because both features touch it: capture creates the session,
   analysis ends it) → called from `AnalysisResultCubit.close()`. The result
   screen is where the scan ends, whatever the user saved, so this is the
   point at which the plaintext copy has no reader left.

   Fire-and-forget and non-throwing by contract: `close()` must not wait on
   the filesystem, and a failed delete is not something a user can act on.

**Tests**: five new in
[`analysis_session_storage_test.dart`](../../test/core/storage/analysis_session_storage_test.dart)
(the create-time purge, including after a *failed* create; `deleteSession`
removing one folder and only that one; a no-op for an already-cleaned session;
a filesystem failure swallowed rather than thrown) and two in
`analysis_result_cubit_test.dart` (the session is discarded on close, including
when the analysis never succeeded). `FakeAnalysisSessionStorage` records what
it was asked to delete.

### Recorded

- **A save in flight when the screen closes.** If the user taps save-with-image
  and backs out within the few milliseconds before `encryptAndStore` has read
  the file, the delete and the read race. On Android — the launch platform —
  unlinking a file that is already open is harmless and the read still
  succeeds; and in the worst case the save fails with the `FileStorageFailure`
  the path already handles, rather than corrupting anything. Judged acceptable
  rather than worth a cross-feature "is a save in flight" signal.
- **Watching this on a real filesystem** (install, scan, check the cache
  directory over `adb`) was not done here. It is T16's, per Q7.

---

## Gate

`dart format .`, `flutter analyze` (0 errors, 0 warnings; infos unchanged from
the pre-task baseline) and `flutter test` — see the F27 row for the counts at
the commit.
