# F35 · Groundwork and safe removals

- **Branch:** `feature/non-reader`, cut from `develop`
- **Milestone:** post-F33, first feature of the F34 pivot
- **Depends on:** nothing. This is the feature every other F34 feature depends on.
- **Decisions source:** [F34-non-reader-pivot.md](F34-non-reader-pivot.md) and the owner's answers of 2026-11-08, recorded in F34 § "Amendments (2026-11-08)".
- **Progress:** 16 / 19 — Phase A done, Phase B written, Phases C, D, E and F done; T04's apply owed (needs Docker)

## Why this feature exists

F34 bundles every deletion into one task (T20) and places it in Phase 3, after
the server and the voice. That ordering means the old pipeline stays wired up
through two features' worth of work, and the deletions then land in the same
commit as the new capture flow — where a regression cannot be told apart from a
rewrite.

This feature pulls forward only the removals that are **safe while the old flow
still runs**, each with its own gate, so that:

1. The branch starts with less code, not more.
2. Every removal is proved independently by `flutter test` before the new flow
   exists to confuse the signal.
3. The `app_runtime_config` rows F36 needs are live in production **before** the
   function that reads them is deployed, so F36 never ships against a missing key.

At the end of F35 the app still builds, still analyses papers through
`ocr-document` + `analyze-document`, and still passes every test. Nothing a user
can see has changed except the four things the owner removed from the product.

## Scope fence — what this feature does NOT touch

Listed because each was considered and deliberately deferred:

| Not here | Where it goes | Why |
|---|---|---|
| Tesseract, `OcrEngine`, `/ocr`, `/ocr-review` | F39 | The only reading path until `explain-document` exists. |
| The old result screen and `core/widgets/result_*` | F40 | Still the only screen that can show an analysis. |
| `DocumentAnalysis`, the 7 document tables, `AnalysisSection` | F38 | Replaced wholesale with the schema-v4 migration. |
| **The reminder ↔ document link** | **F38** | See "Resequenced" below. |
| `ExtractedTextOnlyView`, `extracted_text_entry_card` | F40 | **Not** consent-only — see trap #3. |
| `online_ocr_enabled` | never deleted | The published 1.0.x app's `ocr-document` reads it. |

### Resequenced: the reminder ↔ document link

The owner's answer to Q8 was to cut the link now. Verification says doing it in
F35 costs more than it saves: the coupling spans **26 files in `lib/` and 20 in
`test/`**, and it runs through `ResultActionBar`, `ResultDateRow`,
`ResultDetailsCard`, `UpcomingReminderCard`, `ReminderFormCubit`,
`DocumentDetailsScreen` and the result screen — all of which F38, F40 and F41
delete outright. Cutting it here means rewriting files that are removed two
features later.

Worse, `Reminders.documentId` is a `references(Documents, #id)` foreign key with
`onDelete: cascade`. Dropping that column needs a table rewrite, and F38 already
performs one for schema v4. Doing it twice risks two migrations where one will do.

**Decision: the link is cut in F38, inside the schema-v4 migration.** The product
decision stands; only its landing point moves. Recorded here so it is not lost.

## Existing-code analysis

Verified against the tree at `b421a3e`, not inferred from docs. Three findings
change what the tasks have to do.

### Trap #1 — deleting `PrivacyScreen` traps the user on the intro screen

`PrivacyScreen` is the **only** caller of `OnboardingCubit.complete()`
([privacy_screen.dart:53](../../lib/features/onboarding/presentation/screens/privacy_screen.dart#L53)),
and `OnboardingScreen`'s «ابدأ الآن» only navigates to it
([onboarding_screen.dart:91](../../lib/features/onboarding/presentation/screens/onboarding_screen.dart#L91)).
Remove the screen without moving that call and the onboarding flag is never
flipped: the router's `_firstRunRedirect` keeps every launch on the intro page,
forever, with no way to Home. **T10 must land before T11.**

### Trap #2 — the shared privacy copy must survive

`privacyTitle` and `privacyPoint*` are rendered by `PrivacyPolicyContent`, which
is **also** the settings screen's «سياسة الخصوصية» page (F11-T12). Only
`privacyAgree` — the CTA — becomes unused. Deleting the point strings would blank
the policy page and break the five `app_strings_test` privacy-truth assertions.

### Trap #3 — `ExtractedTextOnlyView` is not the consent screen

It looks like the consent-declined fallback, but `_FailureBodyState._showText`
toggles it for **every** failure kind
([analysis_result_screen.dart:455](../../lib/features/analysis/presentation/screens/analysis_result_screen.dart#L455)).
Removing consent does not orphan it. It stays until F40.

### Verified reference counts

| Thing removed | `lib/` sites | `test/` files | Notes |
|---|---|---|---|
| Analysis consent | 4 call sites + store/use cases/failure/error code/settings/DI | 15 | `AnalysisResultCubit`, `OcrReviewCubit`, both screens |
| `PrivacyScreen` | 4 | 1 | route, `firstRun` set, onboarding CTA |
| `ProcessingMode` | store/use cases/enum + `SettingsCubit` only | 6 | **not referenced by any flow** — settings-only orphan |
| Image-quality gate | service/use case/entity/sheet + `ImagePreviewCubit`/state/screen + failure/error code | 7 | plus one branch in `shouldFallBackToOnDeviceOcr` |

Four `[Drift…Store]` dartdoc references in `core/accessibility` and `core/audio`
point at classes this feature deletes; they are comments only, and will dangle.

### Load-bearing facts about the config change

- `schema_version` is **one global row**, exact-matched by
  [analyze-request.ts:318](../../supabase/functions/_shared/analyze/analyze-request.ts#L318)
  for both request shapes. Changing it breaks every published build instantly.
  Hence a separate `explain_schema_version` key, per the owner's answer to Q2.
- `parseRuntimeConfig` tolerates a malformed individual row and falls back; a
  failed table **read** throws. New keys follow the existing `nonEmptyString` /
  boolean helpers — no new parsing style.
- `explain_enabled` is seeded **false**, so F36's endpoint deploys dark.

## Phases

Each phase ends green: `dart format .`, `flutter analyze`, `flutter test`, plus
`deno test` for Phase B. A phase that cannot go green is not finished, and the
next phase does not start.

### Phase A — the branch and the record

- [x] **T01** Cut `feature/non-reader` from `develop`. *Done when:* the branch
      exists, pushed, and `git log` shows `b421a3e` as its base.
- [x] **T02** Commit the uncommitted Gemma experiment as-is (F34-T01):
      `_shared/ai/gemma-config.ts`, `_shared/ai/gemma-native-client.ts`,
      `tools/list-gemma-models.ts`, and the `tools/analysis-benchmark.ts` +
      `tools/benchmark/legs.ts` changes. *Done when:* `git status` is clean of
      them and `deno test` still passes. No behaviour change — it stays
      benchmark-only until F36-T08.
- [x] **T03** Record the amendments: add an "Amendments (2026-11-08)" section to
      F34 holding the owner's nine answers and the six decisions taken on his
      behalf (audio format, audio encryption, voice fallback, schema-draft
      process, network check, voice-line process), plus the reminder-link
      resequencing above. Add the F35 row to `docs/features/README.md` and bump
      its totals. *Done when:* the decisions are findable in-repo without the
      conversation that produced them.

### Phase B — the server config keys

- [ ] **T04** Migration `supabase/migrations/<ts>_explain_document_config.sql`:
      insert `explain_schema_version` = `"1.0"` and `explain_enabled` = `false`,
      both `on conflict (key) do nothing`. **Must not touch `schema_version` or
      `online_ocr_enabled`** — the published app depends on both. Header comment
      in the house style explaining why a second schema key exists at all.
      *Done when:* applied locally, `select` shows both rows, and the published
      app's analysis still succeeds against the local stack.
      > **Written and committed (`5a4e18a`); the apply is OWED.** Docker was not
      > running, so the migration has not touched a database. What was verified
      > statically: the two keys the SQL seeds are character-for-character the
      > two `parseRuntimeConfig` reads; neither `schema_version` nor
      > `online_ocr_enabled` appears outside a comment; no earlier migration
      > uses either key; and both JSONB literals copy the forms proven by
      > `20260726124644` and `20260929120000`. Still unproven: that it applies
      > cleanly and round-trips through PostgREST. Carry this to T19, and to the
      > staging/production apply in the definition of done.
- [x] **T05** `RuntimeConfig`: add `explainSchemaVersion: string` and
      `explainEnabled: boolean` with defaults `"1.0"` / `false`, parsed by the
      existing helpers. Unit tests for absent / blank / malformed / valid.
      *Done when:* `deno test` passes and no endpoint reads either field yet —
      a deliberately inert change, so its deploy cannot break anything.

### Phase C — analysis consent

Order matters: the gate goes first, then the failure it produced, then the
setting that fed it, then the storage behind it. Reversing that leaves an
unreachable failure type mid-phase.

> **Correction, found during T06.** The split between T06 and T07 holds for
> production code but NOT for tests. Ten tests in `service_state_test.dart`
> reach the consent-declined page through `pumpConsentDeclined`, which writes
> `false` to the store and calls `cubit.analyze()` — i.e. *through the gate* —
> and `explicit_ocr_fallback_test.dart` has an O8 test built the same way. The
> moment the gate goes, that page is unreachable from them and they fail at
> runtime, so leaving them for T07 would mean a red phase.
>
> T06 therefore removes the gate **and every test that could only reach the
> page through it**. T07 keeps all the production presentation. T06 also turned
> out to touch **9 test files, not 2**: the plan's own reference count of 15
> consent test files was right, but T06's task text under-counted which of them
> construct the cubits.
>
> Of those nine, eight were found by `flutter analyze` as
> `undefined_named_parameter` errors. The ninth —
> `test/integration/analysis_failure_paths_test.dart`, "a declined analysis
> consent sends nothing at all" — **compiled cleanly** and failed only at
> runtime, because it reaches the gate through the harness's `analysisConsent`
> seed rather than a constructor argument. Worth remembering for T08/T09 and
> for F39/F40: in this codebase the compiler finds the call sites, but only the
> suite finds the journeys. Note also that `flutter analyze` and `flutter test`
> both exit **0** here even with errors and failures, so the counter line has to
> be read, never the exit code.

- [x] **T06** Remove the gate from `AnalysisResultCubit` (its
      `getAnalysisConsent` constructor param and the `if (!await …)` branch) and
      from `OcrReviewCubit` (param, nullable field, and the check at l.103–110),
      plus both `get_it` registrations and the eight test files that construct
      either cubit or reach the declined page through the gate. *Done when:*
      every affected test passes with the consent cases deleted, and an analysis
      runs without consulting any setting.
      > `test/support/app_harness.dart` and `fakes.dart` were NOT touched here,
      > as the plan expected: they use `AnalysisConsentStore` (the store), not
      > the use case, so they still compile. They go with T09.
- [x] **T07** Remove the failure's presentation: `_FailureKind.consentDeclined`
      and its `switch` arms in `analysis_result_screen.dart`, the
      `isConsentDeclined` branches in `ocr_review_screen.dart`, the
      `ConsentValueCard` widget and its import, and the `onOpenSettings`
      callbacks now unused in `app_router.dart` (**2 sites, not 3**). Then
      delete `AnalysisConsentDeclinedFailure` from `app_failure.dart`, its
      `error_code` arm, and its arm in `shouldFallBackToOnDeviceOcr`.
      *Done when:* no sealed switch over `AppFailure` mentions it and
      `flutter analyze` is clean — exhaustiveness is the proof here, so a
      missed site cannot compile.
      > Two additions the plan missed. **`privacy_text_note.dart` is deleted
      > too**: its only use was the consent-off page (its own doc says so), so
      > it dies with that page rather than surviving to F40 — the plan had it in
      > neither list. And **`onOpenSettings` is removed outright** from both
      > screens and both router sites: grep proved the consent page was its only
      > purpose, so leaving the parameter would have left a callback nothing can
      > reach. `cameraPermissionOpenSettings` is a different, unrelated string
      > and stays.
      >
      > **The published app forced a decision here.** Removing one client
      > failure leaf broke four guard tests the compiler cannot see: three
      > hardcode leaf counts (now 33 leaves, 17 local, 30 policy rows), and
      > `error_report_codes_test` asserts the server's `error-report-codes.ts`
      > allowlist holds no code the app cannot produce.
      >
      > The obvious fix — delete `ANALYSIS_CONSENT_DECLINED` from that
      > allowlist — would have been a **published-app regression**:
      > `error-report-request.ts` answers 400 INVALID_REQUEST for any unlisted
      > code and the app's sink swallows that 400, so 1.0.2 users (who still
      > have the setting) would silently lose the report for exactly the failure
      > they were hitting. The server entry therefore STAYS, with a
      > do-not-delete comment, and the test gains a documented
      > `keptForOldBuilds` exemption plus a second assertion, so a code named
      > there cannot later be dropped server-side unnoticed.
      >
      > **T16 hits this again** with `ImageQualityFailure` → `IMAGE_QUALITY`, as
      > will F39/F40 for every leaf they remove. The exemption is a named set
      > with a reason per entry, not a one-off subtraction, for that reason.
- [x] **T08** Remove the «السماح بإرسال النص للتحليل» row from
      `settings_screen.dart` and the consent field from `SettingsState` /
      `SettingsCubit`. *Done when:* the settings screen tests pass with the
      consent group deleted, and the screen's remaining rows keep their order.
      > Three things worth knowing before T12 does the same job for the
      > processing-mode row, which sits in the same section:
      >
      > - `_PrivacySection`'s **skeleton row count** had to drop 4 → 3. It is a
      >   hand-written number that no test pins (the skeleton tests count
      >   *sections*, not rows), so nothing would have failed if it had been
      >   left wrong — the loading state would simply have shown one row too
      >   many. T12 must drop it again, 3 → 2.
      > - `SettingsCubit`'s dartdoc used `setAnalysisConsent` as its
      >   "emit-first pattern" exemplar in **four** places. Re-pointing them at
      >   `setProcessingMode` would only have moved the problem to T12, so the
      >   explanation now lives on `setDefaultReadingSpeed`, which survives all
      >   of F35.
      > - The constructor's initializer list began `}) : _getAnalysisConsent =`,
      >   so deleting those lines would have taken the `}) :` with them. Read,
      >   not sed — the same trap as T07's orphan `],`.
      >
      > Two deletions were checked before being made rather than after: the
      > consent group held the only `settingsPrivacySection` assertion in its
      > own group, but the skeleton group already asserts it both ways
      > (absent while loading, present after), and the
      > `setAnalysisConsent() before load() is a no-op` guard is duplicated for
      > every other setter, `setDefaultReadingSpeed` included. Nothing lost.
- [x] **T09** Delete `core/analysis/analysis_consent_store.dart`,
      `usecases/get_analysis_consent.dart`, `usecases/set_analysis_consent.dart`,
      their DI registrations and their two test files. Leave any stored
      `app_settings` row in place — it is an inert key/value orphan, and a
      delete migration would be a schema change for no gain. *Done when:*
      `grep -ri consent lib/` returns only the privacy-policy copy.
      > The orphan row is `analysis_consent`, written by the store's own
      > private `_key`. Nothing reads it from this build on; it costs one row
      > per device and no migration.
      >
      > The done-criterion holds with one honest adjustment: `lib/` still
      > matches `consent` in the **three localization files** (T17 owns those
      > strings) and in **four dangling `[DriftAnalysisConsentStore]` dartdoc
      > links** (T18 owns those — and they are exactly the four files this plan
      > predicted). Everything else is gone.
      >
      > Also fixed here, because T09 is what made them false: two prose
      > comments that still described consent as live code — the
      > `_registerSettings` header in `service_locator.dart` and
      > `_LanguageSection`'s doc in `settings_screen.dart`. Neither is a
      > dartdoc link, so T18's sweep would not have caught either.

### Phase D — the privacy screen

- [x] **T10** Point `OnboardingScreen`'s «ابدأ الآن» at
      `context.read<OnboardingCubit>().complete()` instead of
      `context.go(AppRoutes.privacy)`. *Done when:* a widget test asserts the
      CTA completes onboarding, and the router test shows the intro screen leads
      to Home. **This task closes trap #1 and must precede T11.**
      > Both halves landed. The new widget test taps the real CTA against a
      > real cubit and asserts the flag is persisted **and** the gate the
      > router watches has moved — either alone would pass while first run
      > stayed broken: the state without the write does not survive a
      > relaunch, and the write without the state does not lift the redirect.
      >
      > `shell_test`'s "finishing onboarding lands on the shell" was the
      > journey the compiler could not see. It walked intro → privacy → Home in
      > two taps; it is now one. It did not fail on its own, because
      > `PrivacyScreen` still exists until T11 — which is precisely why the
      > phase order matters: had T11 gone first, this test would have failed
      > with a missing route rather than telling anyone the flag was never set.
      >
      > The screen's own earlier tests pump it bare, with no
      > `BlocProvider<OnboardingCubit>`, and still pass: `context.read` sits
      > inside the `onPressed` closure, so only a tap would reach it, and they
      > only assert the button is enabled. Left as they are.
- [x] **T11** Delete `privacy_screen.dart`, the `AppRoutes.privacy` constant and
      its `GoRoute`, and reduce `AppRoutes.firstRun` to `{onboarding}`. Delete
      `test/features/onboarding/privacy_screen_test.dart`. Keep
      `PrivacyPolicyContent`, every `privacyTitle`/`privacyPoint*` string, and
      the settings privacy-policy route (trap #2). *Done when:* a fresh install
      goes intro → Home, and the settings policy page still renders in full.
      > Trap #2 held: `PrivacyPolicyContent` lives in `core/widgets/` and is
      > still rendered by `privacy_policy_screen.dart`, and every
      > `privacyTitle`/`privacyPoint*` string is untouched in all three
      > localization files. Only `privacyAgree` is orphaned now — T17 takes it.
      >
      > `AppRoutes.firstRun` stays a `Set` with one member rather than
      > collapsing into `location == onboarding`: `_firstRunRedirect` needs no
      > edit that way, and F43 replaces the intro screen with the first-launch
      > video, which may well put a second route back in it.
      >
      > One stale doc fixed: `createAppRouter`'s header still said the redirect
      > lifts when "finishing the privacy step". Prose, not a dartdoc link, so
      > T18's sweep would have missed it — the same class of leftover T09 found
      > in `_registerSettings`.

### Phase E — processing mode

- [x] **T12** Remove the «طريقة المعالجة» row from `settings_screen.dart`, the
      `GetProcessingMode`/`SetProcessingMode` dependencies from `SettingsCubit`,
      and the field from `SettingsState`. *Done when:* settings tests pass.
      > Both traps T08 flagged for this task held: the skeleton row count went
      > 3 → 2 (hand-written, pinned by no test — a wrong number here shows a
      > phantom loading row and fails nothing), and `SettingsCubit`'s
      > initializer list still began `}) : _getProcessingMode =`, so a
      > range delete would have taken the `}) :` with it.
      >
      > A third of the same shape, not in the plan, and **sed found it the hard
      > way**: deleting the three cubit tests by line range left an orphan
      > `});`. Caught immediately, but it is the T07 `],` / T08 `}) :` lesson
      > arriving in test code — the fences at the end of a deleted range matter
      > as much as the ones at the start.
      >
      > Two things were salvaged rather than deleted along with the row.
      > `_Radio` and the nine `_sheet*`/`_option*` layout constants sat under
      > the processing-mode sheet's banner but are used by the language,
      > text-size, reading-speed and supported-types sheets as well; they stay,
      > with the banner rehomed to "Shared option-sheet layout" so they do not
      > read as dead code. And the test titled `load() reads the persisted
      > settings, defaulting to smart analysis` is now `...falling back to
      > their defaults` — the title named the one default this task removes,
      > while its assertion still covers the four that remain.
      >
      > Also removed: the `_registerSettings` comment claiming it reuses
      > `_registerAnalysis`'s processing-mode store. Fourth piece of stale
      > prose F35 has cleared, and again not a dartdoc link T18 would catch.
      >
      > 7 tests left the suite (3 cubit, 4 screen), none of them unique: the
      > delete-all rows sharing the privacy section have their own groups, and
      > the skeleton group already asserts `settingsPrivacySection` both ways.
- [x] **T13** Delete `processing_mode.dart`, `processing_mode_store.dart`, both
      use cases, their DI registrations and their two test files. *Done when:*
      `grep -ri processingmode lib/` is empty. No flow change is possible: the
      enum was read by `SettingsCubit` alone.
      > The prediction held exactly — nothing outside `SettingsCubit` ever read
      > the enum, so T12 left these four files with no caller at all. Both
      > `lib/core/analysis/` and `test/core/analysis/` are now **gone entirely**,
      > directories included: processing mode was the last thing in either.
      >
      > The done-criterion needs the same honest adjustment T09 made, for the
      > same two reasons. `grep -ri processingmode lib/` still matches the five
      > `settingsProcessingMode*` strings in the three localization files
      > (**T17** owns those — they are on its 19-key list) and two
      > `[DriftProcessingModeStore]` dartdoc links in `text_size_store.dart`
      > and `default_reading_speed_store.dart` (**T18** owns those two files
      > already, for their `[DriftAnalysisConsentStore]` links — so T18's scope
      > is unchanged, it now has two kinds of dangling ref to fix in the same
      > four files, not one). `grep -ri processing_mode lib/ test/` is empty.
      >
      > `FakeProcessingModeStore` was the dartdoc exemplar for
      > `FakeDefaultReadingSpeedStore` and `FakeResumeReadingEnabledStore`'s
      > "`null` means untouched" convention — the same trap T08 hit with
      > `setAnalysisConsent`. Both now point at `FakeLocaleStore`, which is
      > where the deleted fake's own doc pointed, so the chain ends somewhere
      > permanent instead of moving the problem to the next deletion.
      >
      > The orphan `app_settings` row is `processing_mode`. Left in place, the
      > same call T09 made for `analysis_consent`: one inert row per device,
      > read by nothing from this build on, and not worth a migration.

### Phase F — the image-quality gate

> **Resequenced during execution: T15 runs before T14.** As planned, T14
> removes the `quality` payload from `ImagePreviewConfirmed` first — but
> `image_preview_screen.dart` destructures that field
> (`case ImagePreviewConfirmed(:final quality)`), so T14 in the planned order
> cannot compile on its own. Folding the screen's listener arm into T14 does
> not rescue it either: `_onQualityKnown` would then be unreferenced, and
> `unused_element` is a warning, so the phase would still not be green.
> Running the consumer first makes both tasks independently green and changes
> neither one's scope.
>
> This is the mirror of Phase C's ordering, not a contradiction. There the
> producer (the gate) could go first because the failure type it produced
> still existed for the presentation to switch on. Here the producer owns a
> *field*, so removing it breaks the consumer's compilation. The shared rule:
> **whichever side would stop compiling goes first.**

- [x] **T14** Remove the assessment step from `ImagePreviewCubit`: the
      `assessQuality` param, the `_assessQuality` call at step 3 of `confirm()`,
      and the quality payload on `ImagePreviewConfirmed`. The pipeline becomes
      rotate → crop → hand off. *Done when:* the cubit's tests pass and a
      confirmed preview carries no quality verdict.
      > Step 3 needed no replacement cleanup, which is worth stating because
      > steps 1 and 2 both do. The assessment produced no file, so the
      > `isClosed` guard that followed it was guarding nothing — the crop's
      > guard, one await earlier, is the last one with a temp file to account
      > for. The emit now follows the crop directly.
      > `ImagePreviewConfirmed`'s equality and `hashCode` collapse onto
      > `photo` alone.
      >
      > Three tests went with the step, all about the step itself. The third,
      > `quality assessment receives the final (rotated + cropped) photo`, was
      > the only one whose *subject* outlives it: it pinned the rotate→crop
      > order by observing which file the quality fake was handed. That order
      > is now asserted directly on the confirmed state by `confirm crops
      > after rotating`, renamed to say so — so it stays pinned by a test that
      > does not need the gate to see it.
      >
      > Two more stale comments fixed, both describing the sheet T15 had just
      > removed: `ImagePreviewConfirmed`'s dartdoc on why it carries the
      > framing, and the same explanation in the cubit test that pins it. The
      > framing still has to survive confirm; the reason is now the frame
      > between confirming and the session being created.
- [x] **T15** Remove the `QualityAlertSheet` presentation from
      `image_preview_screen.dart`. *Done when:* confirming a blurry photo
      proceeds with no sheet, on device.
      > Ran first — see the resequencing note above. `_onQualityKnown` and the
      > `showQualityAlertSheet` call are gone; the `ImagePreviewConfirmed`
      > listener arm calls `proceed()` directly, which is exactly what the
      > good-quality path already did. The change is that the poor path stops
      > diverging, not that a new path appears.
      >
      > One test went with the sheet: `the crop stays on screen behind the
      > quality sheet (F15-T14)`. It reached the sheet through production
      > code, so it could not outlive it. Its property is covered twice over —
      > the mid-export test directly above it asserts the overlay does not
      > spring back behind the veil, and the cubit's `the confirmed state keeps
      > the framing the preview is showing` pins the same thing at state level.
      >
      > **The device half of this criterion is owed** — "no sheet on a blurry
      > photo" is so far proved only in the widget suite. It folds into T19's
      > device pass, which walks this same screen.
- [x] **T16** Delete `assess_image_quality.dart`, `image_quality_service.dart`,
      `dart_image_quality_service.dart`, `image_quality_result.dart`,
      `quality_alert_sheet.dart`, their DI registrations, and the four test
      files. Delete `ImageQualityFailure`, its `error_code` arm and its arm in
      `shouldFallBackToOnDeviceOcr`. *Done when:* `flutter analyze` is clean —
      again, sealed exhaustiveness is the proof.
      > **Two test files, not four.** The plan's count included the quality
      > portions of `image_preview_cubit_test` and `image_preview_screen_test`,
      > which T14 and T15 had already handled; only
      > `dart_image_quality_service_test.dart` and
      > `quality_alert_sheet_test.dart` were whole files to delete. The
      > feature's §Testing total of 16 is unaffected.
      >
      > **Sealed exhaustiveness was not in fact the whole proof.** It caught
      > every production site, as predicted, and missed four guard tests that
      > hardcode counts — the same blind spot T07 hit. Three were found by
      > grepping for `hasLength` with the known numbers: 17 → 16 local leaves
      > and 33 → 32 total in `app_failure_test`, 30 → 29 policy rows in
      > `should_fall_back_to_on_device_ocr_test`. **The fourth was found only
      > by running the suite**: `app_logger_test`'s `maps all 29 failures to
      > distinct non-empty codes`, 29 → 28, which that grep missed because its
      > number matched none of the three already known. Searching for the
      > numbers you know finds the guards you know. For F39/F40, which remove
      > far more leaves than this: grep `hasLength(` across `test/` first, then
      > still run the suite.
      >
      > **The published-app decision went exactly as T07 set up.**
      > `IMAGE_QUALITY` stays in the server allowlist with a do-not-delete
      > comment, and `keptForOldBuilds` gains it with its own reason: 1.0.2
      > still runs the gate and still reports the code, and an unlisted code
      > is a 400 the app's sink swallows — so deleting the line would not
      > degrade those users' reporting, it would delete it silently. The
      > exemption's third test (`every code kept for old builds is still
      > accepted by the server`) now covers two entries, which is the first
      > evidence it was worth building as a named set rather than a one-off.
      >
      > **A pre-existing gap found and recorded, not fixed.**
      > `should_fall_back_to_on_device_ocr_test`'s table is named `covers
      > every AppFailure leaf` and claims "same count as app_failure_test's
      > taxonomy guard", but it holds 29 of 32 leaves and the claim never held
      > (it was 30 against 33 before this task). `ExternalLinkFailure`,
      > `NoArabicVoiceFailure` and `TtsEngineUnavailableFailure` are answered
      > by the production switch's exhaustiveness but have never been
      > tabulated. The test's name and comment now say what it actually
      > guarantees; **adding the three missing rows is deliberately left
      > undone** — it is a coverage change, not a removal, and belongs to
      > whoever owns that policy next (F39 touches this file).

### Phase G — the sweep

- [ ] **T17** Remove the now-unused strings from all **three** files
      (`app_strings.dart`, `ar_strings.dart`, `en_strings.dart`), keeping both
      locales per the owner's answer to Q6:
      `settingsAnalysisConsentLabel`, `analysisConsentDeclinedTitle`,
      `analysisConsentDeclinedMessage`, `analysisConsentDeclinedOpenSettings`,
      `analysisConsentValueTitle`, `analysisConsentValueType`,
      `analysisConsentValueKeyPoints`, `analysisConsentValueRequired`,
      `analysisConsentValueDates`, `settingsProcessingModeLabel`,
      `settingsProcessingModeSmartAnalysis`, `settingsProcessingModeTextOnly`,
      `settingsProcessingModeSmartAnalysisDescription`,
      `settingsProcessingModeTextOnlyDescription`, `qualityAlertTitle`,
      `qualityAlertMessage`, `qualityAlertRetake`, `qualityAlertContinue`,
      `privacyAgree` — 19 keys.
      **Keep** `privacyTitle`, `privacyPoint*` (trap #2), `ocrOnlinePoorQuality`
      and `ocrOfflineQualityWarning` (OCR-result copy, not the capture gate;
      they go in F39). *Done when:* `app_strings_test`'s "covers every
      AppStrings member" and the five privacy-truth assertions all pass.
- [x] **T18** Fix the four dangling dartdoc references to the deleted stores in
      `text_size_store.dart`, `high_contrast_store.dart`,
      `default_reading_speed_store.dart` and `resume_reading_enabled_store.dart`
      — each should name a store that still exists. *Done when:* no unresolved
      dartdoc reference remains in those four files.
      > **Five references, not four.** The count was per file, but
      > `default_reading_speed_store.dart` carried two in one sentence
      > (`[DriftAnalysisConsentStore]/[DriftProcessingModeStore]`). The
      > replacements each name a live sibling store:
      > `text_size_store` → `[DriftHighContrastStore]` and
      > `[DriftLocaleStore]`; `high_contrast_store` → `[DriftTextSizeStore]`
      > and `[DriftLocaleStore]`; `default_reading_speed_store` →
      > `[DriftDefaultReadingVoiceStore]` and
      > `[DriftResumeReadingEnabledStore]` (both in `core/audio`);
      > `resume_reading_enabled_store` → `[DriftHighContrastStore]`, which is
      > the bool store the sentence wanted. Rewrapping the `core/audio` one
      > cost a third comment line.
      >
      > **Nothing in the gate could have caught this, and nothing proves the
      > fix.** `comment_references` is not in `analysis_options.yaml`, so a
      > dangling `[...]` is invisible to `flutter analyze` — which is why
      > these four survived T09 and T13 with the classes already deleted. The
      > proof is a grep: `AnalysisConsentStore|ProcessingModeStore` across
      > `lib/` and `test/` now returns nothing. For F39/F40, add that grep to
      > the deletion routine alongside `hasLength(` (T16) — doc comments are
      > the one place a deleted name can live on unflagged.
      >
      > **The links stay cross-library, as they were.** dartdoc only resolves
      > a `[...]` reference against the enclosing library's scope, and none of
      > these stores import each other — the pre-existing
      > `[DriftLocaleStore]` in `text_size_store` was already in that state.
      > So these name stores that exist rather than render as links; making
      > them resolvable would mean imports for documentation's sake. Kept the
      > file's own style instead.

### Phase H — the gate

- [ ] **T19** Full gate: `dart format .`, `flutter analyze`, `flutter test`,
      `deno test`, plus a device pass on the RMX2001 (API 30) proving the **old**
      flow is intact end to end: intro → Home → camera → crop (no quality sheet)
      → online read → review → analysis → result → save. *Done when:* all four
      commands are green and the device pass is recorded in this file.

## Files

**Created (2)**
`supabase/migrations/20261108120000_explain_document_config.sql` ·
`docs/features/F35-groundwork-and-removals.md` (this file).

The new config keys' tests went into the existing
`supabase/tests/unit/runtime-config.test.ts`, where the parsing rules already
live — not into a file of their own, as this plan first sketched.

**Deleted (15 source + 16 test)**
`core/analysis/analysis_consent_store.dart` ·
`core/analysis/usecases/get_analysis_consent.dart` ·
`core/analysis/usecases/set_analysis_consent.dart` ·
`core/analysis/processing_mode.dart` ·
`core/analysis/processing_mode_store.dart` ·
`core/analysis/usecases/get_processing_mode.dart` ·
`core/analysis/usecases/set_processing_mode.dart` ·
`features/onboarding/presentation/screens/privacy_screen.dart` ·
`features/analysis/presentation/widgets/failure/consent_value_card.dart` ·
`features/analysis/presentation/widgets/failure/privacy_text_note.dart` ·
`features/capture/domain/usecases/assess_image_quality.dart` ·
`features/capture/domain/services/image_quality_service.dart` ·
`features/capture/domain/entities/image_quality_result.dart` ·
`features/capture/data/services/dart_image_quality_service.dart` ·
`features/capture/presentation/widgets/quality_alert_sheet.dart` ·
and the matching test files.

**Modified (18)**
`app/di/service_locator.dart` · `app/router/app_router.dart` ·
`core/error/app_failure.dart` · `core/logging/error_code.dart` ·
`core/localization/{app_strings,ar_strings,en_strings}.dart` ·
`core/accessibility/{text_size_store,high_contrast_store}.dart` ·
`core/audio/{default_reading_speed_store,resume_reading_enabled_store}.dart` ·
`features/analysis/presentation/cubit/{analysis_result_cubit,ocr_review_cubit}.dart` ·
`features/analysis/presentation/screens/{analysis_result_screen,ocr_review_screen}.dart` ·
`features/analysis/domain/usecases/should_fall_back_to_on_device_ocr.dart` ·
`features/capture/presentation/cubit/{image_preview_cubit,image_preview_state}.dart` ·
`features/capture/presentation/screens/image_preview_screen.dart` ·
`features/onboarding/presentation/screens/onboarding_screen.dart` ·
`features/settings/presentation/cubit/{settings_cubit,settings_state}.dart` ·
`features/settings/presentation/screens/settings_screen.dart` ·
`supabase/functions/_shared/config/runtime-config.ts` ·
`supabase/tests/unit/runtime-config.test.ts` ·
`test/support/{app_harness,fakes}.dart` ·
`docs/features/{README,F34-non-reader-pivot}.md`

**Assets:** none. F35 adds and removes no asset.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| T11 before T10 bricks first launch | **high** | Phase D's order is mandatory; T10 ships its own regression test |
| Migration touches `schema_version` or `online_ocr_enabled` by accident | **high** | T04 asserts both rows unchanged after apply; published-app smoke test in T19 |
| A privacy-point string removed along with `privacyAgree` | medium | `app_strings_test`'s five truth assertions fail loudly |
| A consent or quality site missed | low | Both are sealed-class members: `flutter analyze` cannot miss one |
| Settings row order shifts visibly | low | Two rows leave adjacent sections; a widget test pins the remaining order |

## Testing

- **Deleted** with their subjects: the 16 test files listed above.
- **Updated:** `app_harness.dart` and `fakes.dart` lose four fakes; the settings
  cubit/screen tests lose two groups; the result-screen and ocr-review tests
  lose their consent cases; `image_preview_cubit_test` loses the quality stage.
- **Added:** eight Deno tests in `supabase/tests/unit/runtime-config.test.ts`
  for the two config keys — two of which exist to pin the separations that make
  the keys worth having at all: the two schema versions move independently in
  both directions, and `online_ocr_enabled` (ON in production) cannot leak into
  `explainEnabled`. Plus one widget test that `OnboardingScreen`'s CTA completes
  onboarding (T10 — the trap's regression test).
- **Unchanged and load-bearing:** `app_strings_test`, `play_compliance_test`,
  `legal_pages_test`, `shell_test`. These are the feature's real safety net; if
  a removal goes wrong, one of them is what says so.

## Definition of done

1. All 19 tasks checked, each with its own commit, pushed.
2. `dart format .`, `flutter analyze`, `flutter test`, `deno test` all green.
3. The RMX2001 device pass of T19 recorded in this file.
4. `grep -ri "consent\|processingmode\|imagequality" lib/` returns only
   privacy-policy copy and the two OCR-result quality strings.
5. `explain_schema_version` and `explain_enabled` exist in staging **and**
   production, and the published 1.0.2 app still analyses a paper successfully
   against production after the migration.
6. F34 carries the amendments section; `docs/features/README.md` lists F35.
