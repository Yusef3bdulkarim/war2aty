# F12-T06 — Cache cleanup verification (temp/session files reliably removed)

Full-app sweep against the one acceptance criterion: every temp/session file
the app creates on disk is reliably removed, not just eventually removed.
"Eventually, at the next cold app launch" turned out to be exactly the gap:
this app already has a careful, well-reasoned cleanup story for capture-flow
temp files, but one class of file — the analysis session's own working
directory — had no cleanup path *inside* a live app session at all.

Method: traced every write of a temp/working file to disk (`grep` for
`getTemporaryDirectory`, `getApplicationCacheDirectory`, `writeAsBytes`,
`File(`, `.copy(`, `createTemp`) back to whatever eventually deletes it, then
read each deletion site's own reasoning to judge whether it is provably
reliable (matching an established, already-reasoned-about pattern in this
codebase) or only incidentally reliable (works today, but nothing guarantees
it). Traced both capture routes (offline OCR, online F13/F14) end to end,
plus the two "delete everything" settings actions.

## Fixed

**`AnalysisSessionStorage`'s per-session directory
(`<cache>/analysis_sessions/{id}/`) had no cleanup path other than the next
app launch's bulk sweep.** `FileAnalysisSessionStorage.createSession` writes
a `processed.jpg` copy into this directory for *every* capture flow —
offline and online alike — and the offline OCR pass (`DartImagePreprocessor
.preprocess`) may write a resized `ocr_resized_*.jpg` sibling into the same
directory. Nothing ever deleted this directory once its analysis was done:
the only existing cleanup, `deleteStaleSessions()`, is a bulk sweep the
bootstrap sequence runs once at the *next cold start*
([`service_locator.dart`](../../lib/app/di/service_locator.dart)'s
`BootstrapStage.cleanup` step) — by its own doc comment, correctly reasoned
for genuinely stale (crash/force-quit) leftovers, but not a promise that a
session's files disappear once that session is actually finished with.

This is a real gap relative to the codebase's own established pattern, not
a theoretical one: the online route's capture-flow temp files (source,
rotated, corrected) already get reliably, *immediately* deleted once
consumed, via `ImageAnalysisSessionHolder.clear()`
([`image_analysis_session_holder.dart`](../../lib/features/analysis/presentation/image_analysis_session_holder.dart))
wired through `AnalysisResultCubit`'s `onImageConsumed` callback; the online
OCR review screen's photo gets the same treatment via `OcrReviewCubit
.cleanupImage()`/`close()`. The one file every route makes —
`session.imagePath` — had no equivalent. Reachable in the plainest way
possible: run the daily 3-analysis quota once without restarting the app,
and three full-resolution unencrypted document photos (plus any OCR-resize
siblings) sit in the OS cache directory for the rest of that app session.
`document_image_store.dart`'s own doc comment even asserts this is already
handled — *"the session's own cleanup (F04) removes it if the user does not
try again"* — a guarantee that did not actually exist in code until this
task.

The complication: `session.imagePath` cannot simply be deleted the moment
analysis finishes, because «حفظ الورقة → مع الصورة» reads it again later,
whenever the user taps save — arbitrarily long after `AnalysisResultCubit
.analyze()` returns, and only if they choose that option. `SaveDocumentCubit`
is the one component that both knows whether that read will happen and is
the last possible consumer of the file, so cleanup now lives there
(`save_document_cubit.dart`):

- **`AnalysisSessionStorage` gained `deleteSession(String id)`** — best-effort
  recursive delete of one session's directory, same "missing is not an
  error, failure is swallowed" contract every other cleanup in this app
  already uses. Defends against ever deleting outside the sessions folder
  (`id.contains('/'/'\\'/'..')` → no-op) even though `id` is never network
  input today — cheap, and closes the door on a future caller wiring it to
  something less trusted. Wrapped in a new `CleanupAnalysisSession` use case
  (`core/storage/usecases/`) so the presentation layer still depends on a
  use case, never the storage class directly (architecture rule).
- **`SaveDocumentCubit.save()`** now calls it once the awaited
  `_saveDocument`/`_saveDocumentWithImage` call resolves — success or
  failure, with or without an image. This is strictly sequential *after*
  the only read that could still need the file, so it can never race that
  read. A result-only save never opened the file at all; a with-image save
  has already had `FileDocumentImageStore` consume and delete the one file
  it needed — either way, whatever the OCR pass left beside it is now safe
  to remove too, instead of waiting for the next cold start.
- **`SaveDocumentCubit.close()`** is the safety net for the one exit path
  with no button — back gesture, swipe, or the app killed before the user
  ever taps «حفظ الورقة» — mirroring the exact shape `OcrReviewCubit.close()`
  already uses for the same reason. Guarded by `state is! SaveDocumentSaving`:
  if a save is genuinely in flight when `close()` fires, deleting here would
  race that call's own read of the session's image, so it is deliberately
  skipped — that in-flight call's own cleanup (above) still runs once it
  resolves, even though the cubit is already closed by then, because closing
  a `Cubit` does not cancel work already in progress.

`SaveDocumentCubit` now takes the session id and the new use case at
construction — updated its one production call site
([`app_router.dart`](../../lib/app/router/app_router.dart), now
`getIt<SaveDocumentCubit>(param1: session)`) and every test construction
site (`save_document_cubit_test.dart`, `save_document_listener_test.dart`,
`no_silent_ocr_fallback_test.dart`).

New tests: `analysis_session_storage_test.dart`'s `deleteSession` group
(deletes the directory and everything inside it, leaves sibling sessions
alone, no-ops on a missing directory/session, swallows a filesystem
failure, refuses a path-traversal id); a new
`cleanup_analysis_session_test.dart`; and a new `session cleanup (F12-T06)`
group in `save_document_cubit_test.dart` covering all five paths above,
including the race guard itself — gated with the same `Completer`-based
"hold the repository call open" technique `analysis_result_cubit_test.dart`
already uses, confirming `close()` does **not** clean up while a save is
genuinely in flight, and that the in-flight call's own cleanup still lands
once it resolves.

**Settings' «حذف كل بيانات التطبيق» (`DeleteAllAppData`, F11-T11) never swept
leftover `analysis_sessions/*` folders** — it wipes the *encrypted* saved-
document images (`DocumentImageStore.deleteAll()`, a different directory)
but a stale session temp file (left behind by, say, an earlier crash) would
still have to wait for the next cold start even after the user explicitly
asked to erase everything now. Fixed by also awaiting the existing
`AnalysisSessionStorage.deleteStaleSessions()` there, after the settings
row clears — safe to call unconditionally the same way the launch-time
bootstrap step already does (nothing can be mid-analysis while the user is
confirming a destructive settings action, so any leftover folder is by
definition stale), and deliberately kept out of the method's returned
`Result` so a wipe the user already confirmed can never be reported as
failed over stale cache. New test in `delete_all_app_data_test.dart`; the
three other call sites (`settings_cubit_test.dart`, `settings_screen_test
.dart`, `shell_test.dart`) updated for the new constructor parameter.

## Checked, no change needed

- **Capture-flow temp files (source, rotated, corrected)** — both routes
  already have a deliberate, already-reasoned-about ownership story:
  `ImagePreviewCubit` tracks every path it creates and deletes them in
  `close()` unless the online handoff fired (in which case
  `ImageAnalysisSessionHolder` takes ownership and deletes them once
  `AnalysisResultCubit` has read the bytes it needs) — the exact race this
  task's own `SaveDocumentCubit` fix had to reproduce the reasoning for.
  Nothing here needed a change; it was the reference pattern.
- **`ImagePackageRotator`'s `rotated_*.jpg`** — written to
  `getTemporaryDirectory()`, tracked via `ImagePreviewCubit._rotatedPath`
  and deleted through the same path as the source photo. Confirmed by
  reading the write site and its one caller.
- **`DoclensPerspectiveCorrector`'s warped output** — the plugin decides the
  output path natively; tracked via `ImagePreviewCubit._correctedPath` the
  same way. Confirmed the Dart side never loses track of whatever path the
  plugin hands back.
- **`AesGcmFileEncryptor`** — operates on `Uint8List` in memory end to end
  (confirmed again while reading it for this task); writes nothing to disk
  itself. `FileDocumentImageStore` is the only writer of the final
  `.enc` file, and already deletes the plaintext source on success
  (`_deleteQuietly`, pre-existing, unchanged by this task).
- **Text-to-speech** — grepped `flutter_tts_text_to_speech_service.dart` for
  `synthesizeToFile`/`writeAsBytes`/`File(`: none. Playback goes straight
  through the platform TTS engine; no temp audio file is ever created.
- **Viewing a saved document's picture** — `DocumentImageStore` exposes no
  read/decrypt method at all today (`encryptAndStore`/`delete`/`deleteAll`
  only), and `document_details_cubit.dart` never references an image path.
  There is currently no feature that decrypts a saved photo back to a
  plaintext temp file for display, so there was nothing to find here — worth
  the reminder for whenever that feature is built, not a gap today.
- **SQLite's own journal/WAL files** — engine-managed, not something the app
  writes or deletes itself; out of this task's scope by construction.

## Flagged for cleanup (not resolved here)

- **The online route's «حفظ الورقة → مع الصورة» may save the wrong picture.**
  While tracing every use of `session.imagePath` for this task, found that
  `FileAnalysisSessionStorage.createSession` copies `current.photo` (the
  rotated-but-not-yet-perspective-corrected photo) into `session.imagePath`
  *before* the online route runs perspective correction
  (`ImagePreviewCubit.proceed`) — so `session.imagePath` and the
  perspective-corrected `corrected.path` the online pipeline actually
  analyzes are two different files. `_saveResult` in `app_router.dart`
  saves `session.imagePath` regardless of route. If that is not intentional,
  an online-route "save with image" keeps the un-corrected photo instead of
  the corrected one the user reviewed. This is a possible correctness/data-
  accuracy question for whoever owns F13/F08, not a cache-cleanup bug — not
  fixed here to keep this task's diff to the one thing it set out to fix
  (per CLAUDE.md's change-discipline rule), and because fixing it would mean
  changing *what* gets saved, a decision this task has no design authority
  over.

## Out of scope (deferred)

- **A real-device pass confirming the OS's own cache-eviction behaviour**
  matches what the code assumes — this task is a code-level sweep, same
  constraint T01–T05 already noted for their own device-only checks;
  belongs to the Exit DoD's "real-device pass" line, not this task.
- **iOS-side verification** of any finding above — this sweep read the Dart
  source and (where relevant) the Android plugin implementations, same
  caveat T05 already flagged for its own OCR-threading finding.
