# F27-T17 — Integration tests

The invoice path end to end, plus the failure paths F27's T17 row names:
timeout, OCR fallback, limit reached. 2,418 tests existed before this task and
every one of them tested a part: a cubit with its use cases stubbed, a screen
with its cubit stubbed, a repository with its datasource stubbed. **Nothing
tested the app.** The journey from a tap on Home to a row in the database
crosses eight screens, five features, two Edge Functions, the Drift database
and the notification scheduler, and no test had ever walked it.

So the work was in the harness, not the assertions: `test/support/app_harness.dart`
boots the shipped app — the real `configureDependencies` graph, the real
router, the real repositories, mappers, validators, cubits and schedulers —
and fakes only the two edges, the platform and the network. Three test files
then drive it by tapping.

---

## 1. What is real, and what is not

| | |
|---|---|
| **Real** | `configureDependencies` itself (every registration, resolved as the app resolves it) · `GoRouter` with all its routes and redirects · every cubit and use case · `DriftDocumentsRepository`, `DriftRemindersRepository`, the settings/consent/onboarding stores, all over an in-memory SQLite with the real migrations · `LocalNotificationsReminderScheduler` · `DefaultAnalysisRepository`, its DTOs, `AnalysisResponseValidator`, the mappers, `api_error_mapper`, `network_failure_mapper` · the app's own `Dio`, with `RequestIdInterceptor`, `ApiLogInterceptor` and `AuthInterceptor` on it · `StubAuthRepository` · the five candidate extractors and `TextNormalizer` · `assets/fixtures/analysis/invoice.json`, served as a real analyze-document body |
| **Faked** | camera, photo picker, Tesseract and its preprocessor, the three `image`-package services (rotate/crop/quality), notifications plugin, TTS, permissions, connectivity, secure storage, the encrypted image store · the HTTP adapter under Dio (`FakeEdgeFunctions`) · the session directory, which is a real temp directory rather than `path_provider`'s |

The line is deliberate: a journey test that stubbed `AnalysisRepository` — as
every existing routing test does — would prove the screens talk to each other
and nothing about the wire shapes, the failure classification, the quota cache
or the notification the user actually gets. All four of those are asserted
here, and two of them are asserted *negatively*, which is the only way §7 can
be tested at all: **what the app sent, field by field.**

### The backend is a scripted adapter, not a mock repository

`FakeEdgeFunctions implements HttpClientAdapter` and is installed on
`getIt<Dio>()`, so a request reaches it having been through every real
interceptor, and the answer goes back up through the real datasource,
repository, validator and mapper. It serves `get-usage`, `ocr-document` and
`analyze-document` with defaults that make the happy path work, holds the
quota as state — **a successful `analyze-document` consumes a slot, as the
server does** — records every call with its decoded body, and lets a test
override one endpoint with a status, a §31 error envelope, or a transport
failure (`DioExceptionType`). An endpoint nobody expected is recorded in
`unexpectedPaths` rather than quietly answered.

### Two things the harness had to solve

**The identity.** DI picks the real Edge Function datasources only when
`AppEnvironment.isConfigured`, and a configured build resolves
`AuthRepository` to `SupabaseAuthRepository(Supabase.instance.client.auth)` —
a process global that `bootstrap` owns and a test must not initialize. The
harness therefore runs a *configured dev* environment and registers
`StubAuthRepository` over it, the same class an unconfigured build uses. That
is the one place the harness swaps a decision DI made rather than a boundary.

**`getIt.allowReassignment` is turned on only after
`configureDependencies` has run**, so a double registration inside DI still
throws where it should, and the overrides still land before anything is
resolved (every one of them is a lazy singleton or factory).

---

## 2. Four things the environment does that no existing test had hit

These cost most of the task, and all four are notes for whoever writes the
next journey test.

**1. Drift streams never arrive inside `testWidgets`.** Drift delivers a query
stream's first value through `Timer.run`, and a timer inside a `testWidgets`
body only fires when a pump advances the fake clock. `await
dao.watchDocuments().first` therefore **hangs the test** — not fails it, hangs
it: the first run of the journey sat for nine minutes until the runner was
killed. The harness reads with one-shot selects (`database.select(...).get()`)
instead, which complete on microtasks.

**2. The app's own teardown leaves a timer pending.** Closing the app closes
its cubits, which cancel those same Drift streams, and Drift schedules a
zero-duration timer to finish the cancellation. `flutter_test` unmounts the
tree itself after the body returns, but the `pump()` it follows with does not
advance the clock — so the timer is still pending when the binding checks, and
**every journey failed on "A Timer is still pending even after the widget tree
was disposed"** rather than on anything it asserted. `AppHarness.dispose()`
unmounts inside the body and pumps 1 ms; `journeyTest` calls it, so a test
cannot forget.

**3. The online route cannot run under `FakeAsync` at all.**
`DefaultAnalysisRepository._buildImageRequest` reads the photo off disk and
base64-encodes it in `Isolate.run` (F27-T15 moved it there), and neither real
file I/O nor a real isolate completes inside a `testWidgets` body — the same
constraint `flutter_test_config.dart` already records for `FontLoader`. This
is why **no widget test had ever driven the online route past the review
screen**: `explicit_ocr_fallback_test` stubs `AnalysisRepository`, so the
isolate is never reached. `AppHarness.settleWithIo` pumps in 100 ms slices
with 50 ms of *real* time in between, and only settles once nothing has been
animating for two consecutive rounds — a fixed round count would be either
flaky or slow, because spawning the isolate takes a few hundred real
milliseconds. The early exit keeps the normal cost at about half a second,
while the round budget leaves three real seconds for a loaded CI runner. It cannot use `pumpAndSettle` while waiting, because the screen
it is waiting on shows the repeating wait animation.

**4. The save confirmation covers the action bar.** `SaveDocumentListener`'s
SnackBar sits for 3 seconds over the bottom of the result page, and
`pumpAndSettle` returns while it is up. The reminder tap after a save landed
on the SnackBar and silently missed; the journey has to wait it out, as the
user does.

### The one dependency DI does not expose

`CameraCaptureCubit`'s factory constructs `PlatformCameraService()` **inside
the closure**, so there is no registration to override and the harness has to
re-wire that one cubit the way DI does. Recorded, not changed: the camera is a
plugin boundary with its own cubit tests, and widening DI to make a test
simpler is not a change this task should make on its own. It is the only
dependency in the graph a test cannot reach.

---

## 3. The journeys (`test/integration/invoice_journey_test.dart`)

Seven tests. The vertical slice's paper is the bundled `invoice.json` fixture
— the real wire body — with its deadline moved to a week out and given a time,
because the fixture's own deadline is April 2024: the scheduler only schedules
alerts still in the future, and a date with no time opens the reminder form
with no default alert and its save button disabled.

**The on-device journey**, one test, asserting as it goes:

1. Home → camera (permission granted, the real `CameraPermissionGate`) →
   shutter → `/preview?path=…` with the photo the camera returned.
2. «استخدم الصورة» → the route decision (connectivity + the server's
   `online_ocr_enabled`, read fresh from `get-usage`) picks the on-device
   pipeline → `/ocr` runs Tesseract → `/ocr-review` shows its text.
   **`ocr-document` was never called**: on this route the image goes nowhere.
3. «كمّل» → `/result`. `analyze-document` called once; the response's own
   figures reach the screen through the real DTO, validator, mapper and
   formatters (`850.50 جنيه`, the deadline as a Cairo-day date). The request
   carries `input_type: text` and **no `image` key** (§7), and its headers
   show the real interceptor chain ran: the publishable key, the session's own
   bearer token and a correlation id. The server consumed one slot and the app
   re-synced to see it.
4. «حفظ الورقة» → the mode sheet → «حفظ» → the confirmation names what was
   kept, one row is in the database with the analysis's title, and the image
   store was **never asked to keep a picture**.
5. «إنشاء تذكير» (the action bar's, which asks which date first) → the
   deadline → the form opens with its default alert → «حفظ التذكير» →
   `/reminders/success`. The reminder row is **linked to the document saved in
   step 4**, and the alert row in the database matches what the OS was told
   through the real scheduler, one for one.
6. «رجوع» → Home, showing the saved paper on the recent strip and «متبقي لك
   تحليلان النهارده» — the count this journey earned, not a seeded one. The
   scan's working directory is **gone from the disk** (F27-T15's fix: an
   unsaved page image must not outlive the screen that read it).

**The online journey**, one test: the image is read off the device and the
analysis is not. `ocr-document` is called once with `input_type: image` and
`image: {data, mime_type}`; the request's keys are asserted to be **exactly**
the §29b set, so nothing about the device, the location or the capture can
ride along with the picture unnoticed; Tesseract never runs; and the
analyze-document request that follows carries the reviewed text and no image.

**A reminder made before the paper is saved**, one test, which documents what
the T17 row's "result → reminder → save" ordering actually is: the reminder is
kept and is deliberately **unlinked** (`documentId` null — a reminder does not
require the paper to be kept), and both ways off the confirmation screen are
`go`, not `pop`, so **the result page is gone and saving afterwards is not a
path the user has.** If the two are to be linked, the save has to come first.
That is the shipped behaviour, not a defect found here, but it is now written
down and held by a test.

Four smaller tests cover the steps on their own (boot over the real graph,
the permission gate, the shutter, the on-device read), so a break in the
middle of the long journey is easy to place.

## 4. The failure paths (`test/integration/analysis_failure_paths_test.dart`)

Six tests. Each makes one endpoint fail the way the backend really fails, and
asserts the whole path — not the error page, which has its own widget tests,
but what was sent, what was not, whether a slot was spent, and whether the
user can carry on.

| Path | What it holds |
|---|---|
| **Timeout** (`receiveTimeout` on analyze-document) | The service-problem page with its wait/connection/read-text tips; **no slot consumed**; «حاول تاني» goes back out on the **same session id** and lands, and only then is a slot spent |
| **OCR fallback** (`receiveTimeout` on ocr-document) | One of F20 §1's four allowed failures: the phone reads the page **exactly once**, the fallback warning shows, and the analysis carries on **from the device's own text** |
| **Online failure outside the allowlist** (500 `INTERNAL_ERROR`) | The reading's error page, **no fallback warning**, Tesseract **never runs**, analyze-document never called |
| **Limit reached** (429 `DAILY_LIMIT_REACHED` with `details.reset_at`) | The limit page naming the limit **from the cached quota** and when it resets; a refusal spends nothing. Booted with a limit of **5**, deliberately not the harness's default of 3, so the page cannot pass by naming a number that happens to match |
| **No connection** | The on-device route is chosen by connectivity, the page is still read on the phone, `ocr-document` is never called, and the failure page says it is the connection |
| **Consent declined** (F11-T02) | `analyze-document` is **never called** — the text never leaves the phone — while the on-device reading still runs, because reading the page needs no consent |

The timeout and the fallback cases are the ones worth having at this level.
`explicit_ocr_fallback_test` already covers the fallback allowlist, but
against a stubbed `AnalysisRepository`: it proves the cubit's decision, not
that a real `DioException` is classified into a failure the allowlist accepts.
Here the timeout is a transport failure travelling through
`network_failure_mapper` → `shouldFallBackToOnDeviceOcr` → the device reader,
and the 429 is a real §31 envelope travelling through `api_error_mapper` into
the limit page's own copy.

## 5. Proved, not assumed

The journey was mutation-checked against a real privacy regression: in
`app_router.dart`'s `_saveResult`, the save mode was temporarily ignored
(`imagePath: session.imagePath` unconditionally, so «النتيجة فقط» would keep
the picture anyway). The journey **failed** — the confirmation that names what
was kept no longer matched — and passed again once reverted. `git diff` over
`lib/` is clean.

The integration suite was run three times in a row to check for timing
flakiness introduced by `settleWithIo`'s real-clock interleaving: 13/13 each
time.

## 6. Reviewed

`@code-reviewer` ran on it: **PASS, no blocking defect.** It confirmed the
three environment claims in §2 independently, found no leakage between tests
(the GetIt resets, the `allowReassignment` restore, the database close and the
temp directory all check out in LIFO order), and judged the §7 negative
assertions and the quota counts to have teeth. Its three items were all
applied:

- **(medium, determinism)** `journeyDeadline()` was being called twice —
  once when the fixture was built and once in the assertion — so a run
  straddling local midnight would have failed on the date rather than on the
  app. The deadline is now resolved **once** per boot and carried on the
  harness (`AppHarness.deadline`), which is what the assertion reads.
  CLAUDE.md §B10 is the rule this was closest to breaking.
- **(low)** the limit-reached test now boots with a limit of 5 rather than
  the default 3 (§4).
- **(low)** a comment that mis-described the SnackBar margin.

It also noted that `AppHarness.picker` and `.tts` are exposed but not yet
driven, and recommended keeping both as the next journeys' entry points —
kept.

## 7. Recorded, not changed

- **The camera service is not injectable** (§2 above). The only dependency a
  test cannot reach through DI.
- **`FakeEdgeFunctions` does not model the server's own quota reservation
  order.** It consumes a slot on a 2xx analyze-document, which matches what
  the app can observe, but the real function reserves the slot *before*
  calling the provider and releases it on its own timeout. That difference is
  exactly what the backend's own `deno test` integration tests cover, and it
  is not observable from the client.
- **No journey covers the gallery route or the quality sheet.** The picker is
  faked and wired in the harness, so adding one is a short test; this task
  spent its length on the camera path the T17 row names.
- **F12-T08's OCR regression dataset is still deferred** (F27's Q7 answer).
  Nothing here reads a real page: `FakeOcrEngine` returns fixed text, so the
  journeys prove the pipeline, never the recognition quality.
- **`ci.yml`'s comment on the analyzer baseline says 16 infos; there are 18.**
  Noticed while reading the gate, unrelated to this task and harmless (the
  step runs `--no-fatal-infos`), but the number in the comment has drifted and
  whoever next touches that file should correct it.

## Gate

`dart format .` (0 changed), `flutter analyze` (**0 errors, 0 warnings**; 18
infos, all pre-existing and none in files this task touched) and `flutter
test` — **2,431 passed** (+13). No backend change, so no `deno test` run.
