# F35 · Groundwork and safe removals

- **Branch:** `feature/non-reader`, cut from `develop`
- **Milestone:** post-F33, first feature of the F34 pivot
- **Depends on:** nothing. This is the feature every other F34 feature depends on.
- **Decisions source:** [F34-non-reader-pivot.md](F34-non-reader-pivot.md) and the owner's answers of 2026-11-08, recorded in F34 § "Amendments (2026-11-08)".
- **Progress:** 0 / 19

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

- [ ] **T01** Cut `feature/non-reader` from `develop`. *Done when:* the branch
      exists, pushed, and `git log` shows `b421a3e` as its base.
- [ ] **T02** Commit the uncommitted Gemma experiment as-is (F34-T01):
      `_shared/ai/gemma-config.ts`, `_shared/ai/gemma-native-client.ts`,
      `tools/list-gemma-models.ts`, and the `tools/analysis-benchmark.ts` +
      `tools/benchmark/legs.ts` changes. *Done when:* `git status` is clean of
      them and `deno test` still passes. No behaviour change — it stays
      benchmark-only until F36-T08.
- [ ] **T03** Record the amendments: add an "Amendments (2026-11-08)" section to
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
- [ ] **T05** `RuntimeConfig`: add `explainSchemaVersion: string` and
      `explainEnabled: boolean` with defaults `"1.0"` / `false`, parsed by the
      existing helpers. Unit tests for absent / blank / malformed / valid.
      *Done when:* `deno test` passes and no endpoint reads either field yet —
      a deliberately inert change, so its deploy cannot break anything.

### Phase C — analysis consent

Order matters: the gate goes first, then the failure it produced, then the
setting that fed it, then the storage behind it. Reversing that leaves an
unreachable failure type mid-phase.

- [ ] **T06** Remove the gate from `AnalysisResultCubit` (its
      `getAnalysisConsent` constructor param and the `if (!await …)` branch) and
      from `OcrReviewCubit` (param, nullable field, and the check at l.103–110).
      Update both `get_it` registrations and `test/support/app_harness.dart` +
      `fakes.dart`. *Done when:* both cubits' tests pass with the consent cases
      deleted, and an analysis runs without consulting any setting.
- [ ] **T07** Remove the failure's presentation: `_FailureKind.consentDeclined`
      and its five `switch` arms in `analysis_result_screen.dart`, the
      `isConsentDeclined` branches in `ocr_review_screen.dart`, the
      `ConsentValueCard` widget and its import, and the `onOpenSettings`
      callbacks now unused in `app_router.dart` (3 sites). Then delete
      `AnalysisConsentDeclinedFailure` from `app_failure.dart`, its `error_code`
      arm, and its arm in `shouldFallBackToOnDeviceOcr`. *Done when:* no sealed
      switch over `AppFailure` mentions it and `flutter analyze` is clean —
      exhaustiveness is the proof here, so a missed site cannot compile.
- [ ] **T08** Remove the «السماح بإرسال النص للتحليل» row from
      `settings_screen.dart` and the consent field from `SettingsState` /
      `SettingsCubit`. *Done when:* the settings screen tests pass with the
      consent group deleted, and the screen's remaining rows keep their order.
- [ ] **T09** Delete `core/analysis/analysis_consent_store.dart`,
      `usecases/get_analysis_consent.dart`, `usecases/set_analysis_consent.dart`,
      their DI registrations and their two test files. Leave any stored
      `app_settings` row in place — it is an inert key/value orphan, and a
      delete migration would be a schema change for no gain. *Done when:*
      `grep -ri consent lib/` returns only the privacy-policy copy.

### Phase D — the privacy screen

- [ ] **T10** Point `OnboardingScreen`'s «ابدأ الآن» at
      `context.read<OnboardingCubit>().complete()` instead of
      `context.go(AppRoutes.privacy)`. *Done when:* a widget test asserts the
      CTA completes onboarding, and the router test shows the intro screen leads
      to Home. **This task closes trap #1 and must precede T11.**
- [ ] **T11** Delete `privacy_screen.dart`, the `AppRoutes.privacy` constant and
      its `GoRoute`, and reduce `AppRoutes.firstRun` to `{onboarding}`. Delete
      `test/features/onboarding/privacy_screen_test.dart`. Keep
      `PrivacyPolicyContent`, every `privacyTitle`/`privacyPoint*` string, and
      the settings privacy-policy route (trap #2). *Done when:* a fresh install
      goes intro → Home, and the settings policy page still renders in full.

### Phase E — processing mode

- [ ] **T12** Remove the «طريقة المعالجة» row from `settings_screen.dart`, the
      `GetProcessingMode`/`SetProcessingMode` dependencies from `SettingsCubit`,
      and the field from `SettingsState`. *Done when:* settings tests pass.
- [ ] **T13** Delete `processing_mode.dart`, `processing_mode_store.dart`, both
      use cases, their DI registrations and their two test files. *Done when:*
      `grep -ri processingmode lib/` is empty. No flow change is possible: the
      enum was read by `SettingsCubit` alone.

### Phase F — the image-quality gate

- [ ] **T14** Remove the assessment step from `ImagePreviewCubit`: the
      `assessQuality` param, the `_assessQuality` call at step 3 of `confirm()`,
      and the quality payload on `ImagePreviewConfirmed`. The pipeline becomes
      rotate → crop → hand off. *Done when:* the cubit's tests pass and a
      confirmed preview carries no quality verdict.
- [ ] **T15** Remove the `QualityAlertSheet` presentation from
      `image_preview_screen.dart`. *Done when:* confirming a blurry photo
      proceeds with no sheet, on device.
- [ ] **T16** Delete `assess_image_quality.dart`, `image_quality_service.dart`,
      `dart_image_quality_service.dart`, `image_quality_result.dart`,
      `quality_alert_sheet.dart`, their DI registrations, and the four test
      files. Delete `ImageQualityFailure`, its `error_code` arm and its arm in
      `shouldFallBackToOnDeviceOcr`. *Done when:* `flutter analyze` is clean —
      again, sealed exhaustiveness is the proof.

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
- [ ] **T18** Fix the four dangling dartdoc references to the deleted stores in
      `text_size_store.dart`, `high_contrast_store.dart`,
      `default_reading_speed_store.dart` and `resume_reading_enabled_store.dart`
      — each should name a store that still exists. *Done when:* no unresolved
      dartdoc reference remains in those four files.

### Phase H — the gate

- [ ] **T19** Full gate: `dart format .`, `flutter analyze`, `flutter test`,
      `deno test`, plus a device pass on the RMX2001 (API 30) proving the **old**
      flow is intact end to end: intro → Home → camera → crop (no quality sheet)
      → online read → review → analysis → result → save. *Done when:* all four
      commands are green and the device pass is recorded in this file.

## Files

**Created (3)**
`supabase/migrations/<ts>_explain_document_config.sql` ·
`docs/features/F35-groundwork-and-removals.md` (this file) ·
one Deno test file for the new config keys.

**Deleted (14 source + 16 test)**
`core/analysis/analysis_consent_store.dart` ·
`core/analysis/usecases/get_analysis_consent.dart` ·
`core/analysis/usecases/set_analysis_consent.dart` ·
`core/analysis/processing_mode.dart` ·
`core/analysis/processing_mode_store.dart` ·
`core/analysis/usecases/get_processing_mode.dart` ·
`core/analysis/usecases/set_processing_mode.dart` ·
`features/onboarding/presentation/screens/privacy_screen.dart` ·
`features/analysis/presentation/widgets/failure/consent_value_card.dart` ·
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
- **Added:** one Deno test for the two config keys; one widget test that
  `OnboardingScreen`'s CTA completes onboarding (T10 — the trap's regression
  test).
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
