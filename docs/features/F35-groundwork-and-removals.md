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

- [x] **T04** Migration `supabase/migrations/<ts>_explain_document_config.sql`:
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
      >
      > **APPLIED LOCALLY 2026-11-09.** Docker up, `supabase migration up`
      > (not `db reset` — nothing wiped); the local DB sat at
      > `20261010120000` and this was the only pending migration. Two of the
      > three done-criteria are now met and the third is T19's device pass,
      > so **this box stays open until that run** — it is the same run, not
      > extra work.
      >
      > **The high-severity risk is now disproven by diff, not by reading.**
      > A before/after dump of `app_runtime_config` differs by exactly two
      > added lines, nothing modified and nothing removed: `schema_version`
      > is still `"2.0"` and `online_ocr_enabled` is still `true`. The two
      > new rows carry the right JSONB types too (`jsonb_typeof`: string and
      > boolean), which is what `nonEmptyString` and `optInFlag` expect.
      >
      > **The PostgREST round-trip this note called unproven is proven,
      > three links deep.** PostgREST hands back `"1.0"` as a JS string and
      > `false` as a JS boolean; feeding that *actual* response through the
      > real `parseRuntimeConfig` yields `explainSchemaVersion "1.0"`,
      > `explainEnabled false`, `schemaVersion "2.0"`, `onlineOcrEnabled
      > true`.
      >
      > **And an endpoint that loads the config still answers.** `health` was
      > useless for this — it deliberately reads neither database nor config,
      > which its own header explains — so the check ran against `get-usage`,
      > which calls `loadRuntimeConfig` and is the call Home already makes on
      > load. With a real anonymous session: **HTTP 200**, `schema_version
      > "2.0"`, `online_ocr_enabled true`, `daily_limit 3`,
      > `analysis_enabled true`, and **no `explain_*` field at all** — so the
      > published 1.0.2 app sees a byte-identical response shape. That is the
      > migration's "cannot change the behaviour of a single request" claim,
      > measured.
      >
      > **One dependency this hands F36.** The header above says
      > `explain_enabled` is the client's gate, "read from the usage sync
      > Home already performs" — but `get-usage`'s response does not carry
      > it, and nothing in `_shared/usage/` mentions it. T05 added both keys
      > to `RuntimeConfig` (server-side parsing) only. F36 must widen the
      > usage response as well, or the client gate has nothing to read.
      > Nothing in F35 is wrong here; it is the next feature's first task.
      >
      > **Local env note for whoever runs the device pass.** `[edge_runtime]`
      > is `enabled = false` in `config.toml` by design (`supabase start`
      > does not pass `.env` secrets to that container), so functions must be
      > served separately with `supabase functions serve --env-file
      > supabase/.env`. `supabase start` alone leaves `/functions/v1/health`
      > answering 503.
      >
      > **CLOSED 2026-11-09 by the T19 device run.** The third criterion —
      > the published app's analysis succeeding against the local stack —
      > was met by the real dev app on the RMX2001 over `adb reverse`:
      > `get-usage` 200 against the migrated config with the response shape
      > unchanged, then `ocr-document` 200 and `analyze-document` 200 for a
      > full invoice. See T19's record.
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

- [x] **T17** Remove the now-unused strings from all **three** files
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
      > Both pass, with every keep intact: `privacyTitle`, the eight
      > `privacyPoint*` members, `ocrOnlinePoorQuality` and
      > `ocrOfflineQualityWarning` are untouched, and `settingsPrivacySection`
      > survives too — T08 and T12 emptied that section of both its rows, but
      > `settings_screen.dart` still renders the heading above the
      > privacy-policy row. Checked, not assumed.
      >
      > **Two consumers the task list did not name, both in `test/`.** The
      > 19 keys cost **23** lines of `app_strings_test`'s `_accessors` map,
      > not 19 — four entries wrap onto a second line, so a line-per-key
      > edit would have left four orphan halves. The second is
      > `privacy_policy_screen_test`'s `shows no CTA` guard, which asserted
      > `find.text(ar.privacyAgree)` was absent: both its subject **and** the
      > screen whose CTA it guarded against are now deleted. Rewritten to
      > assert no `FilledButton`/`ElevatedButton`/`TextButton` is on the page
      > — broader than the one label it checked, and it still passes because
      > the back arrow and the two footer links are `InkWell`s. That is a
      > repair of a test this task breaks, not the coverage addition T16
      > refused to make.
      >
      > **The prose sweep, which is the one T18 could not do.** Five stale
      > references to the deleted first-run privacy step were found and
      > fixed here, because F35 is what made them false. One is a genuinely
      > dangling dartdoc link — `[PrivacyScreen]` in
      > `privacy_policy_content.dart` — **which T18 missed**: its proof
      > grepped for the two deleted store names, not for every class F35
      > deleted. A `[Name]` sweep over all 17 now returns nothing. The
      > other four are plain prose, invisible to any name grep:
      > `settingsPrivacyPolicyLabel`'s doc and `displayMedium`'s doc both
      > still listed a first-run privacy page, and `PrivacyPolicyScreen`'s
      > header said "agreeing already happened on first run" and justified
      > the footer's placement by a widget that no longer exists.
      >
      > **So the deletion routine needs two greps, not one.** T09, T11 and
      > now T17 have each found stale prose the previous task left, and T18
      > — the task whose whole job was dangling references — found only what
      > it thought to search for. For F39/F40: grep `[Name]` for every
      > deleted class **and** grep the removed flow's own words (here "first
      > run", "consent", "quality") across `lib/` and `test/`.
      >
      > The suite stays at 2825 tests: dropping `_accessors` rows removes
      > assertions inside parameterised tests rather than tests, and the
      > rewritten guard is still one test.
      >
      > §Files' **Modified** list gains the three prose files above and the
      > two test files. Its heading read `(18)` against a list of 29 files —
      > it was the estimate this plan was written with, and no task had
      > bumped it since. It now reads `(34 files)`, counting what the list
      > actually names with its `{a,b}` groups expanded, so the next reader
      > can check it in one command instead of trusting it.
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
      > **Amended by T17: that grep was too narrow.** It searched for the two
      > deleted store names, so it missed `[PrivacyScreen]` in
      > `privacy_policy_content.dart` — a dangling dartdoc link to a class
      > T11 deleted, exactly what this task was for. T17 found it by
      > sweeping `[Name]` for all 17 classes F35 deletes and fixed it
      > there. The lesson is the grep's subject: sweep the deleted **set**,
      > not the names the task happens to mention.
      >
      > **The links stay cross-library, as they were.** dartdoc only resolves
      > a `[...]` reference against the enclosing library's scope, and none of
      > these stores import each other — the pre-existing
      > `[DriftLocaleStore]` in `text_size_store` was already in that state.
      > So these name stores that exist rather than render as links; making
      > them resolvable would mean imports for documentation's sake. Kept the
      > file's own style instead.

### Phase H — the gate

- [x] **T19** Full gate: `dart format .`, `flutter analyze`, `flutter test`,
      `deno test`, plus a device pass on the RMX2001 (API 30) proving the **old**
      flow is intact end to end: intro → Home → camera → crop (no quality sheet)
      → online read → review → analysis → result → save. *Done when:* all four
      commands are green and the device pass is recorded in this file.
      > **All four commands green at `fdbcf05`:** `dart format .` 0 changed ·
      > `flutter analyze` 19 issues, every one a pre-existing `info` in a
      > file F35 never touched, 0 errors / 0 warnings · `flutter test`
      > **2825 passed** · `deno test --allow-env --allow-net supabase/tests`
      > **767 passed, 0 failed, 69 ignored** (the live ones, which want keys
      > or a stack). The Deno suite needs no Docker — worth knowing, since
      > this plan assumed otherwise.
      >
      > **Device pass — RMX2001 `QCKFXSDAGMCIPB55`, Android 11 (API 30),**
      > dev flavour over `adb reverse tcp:54321`, local stack with the
      > owner's real provider keys, production-like config (`daily_limit 3`,
      > `analysis_enabled true`, `online_ocr_enabled true`,
      > `schema_version "2.0"`). Build `assembleDevDebug` 67.3 s → installed
      > 6.0 s. Neither `com.war2aty.app` nor `com.war2aty.app.dev` was on the
      > phone beforehand (only an old `war2aty_ocr_spike`), so **first run
      > was genuine and is not repeatable** without `pm clear`.
      >
      > | § | Check | Evidence | Result |
      > |---|---|---|---|
      > | 1 | intro «ابدأ الآن» → Home, no privacy page (T10/T11) | owner, on a true first run | **pass** |
      > | 2 | Settings «الخصوصية»: no consent toggle, no «طريقة المعالجة», no phantom skeleton row (T08/T12) | owner | **pass** |
      > | 2b | «سياسة الخصوصية» renders four promises, no CTA (T11/T17) | owner | **pass** |
      > | 3 | crop confirmed → straight through, no quality sheet (T14–T16) | owner; server shows the flow going on to `ocr-document` with nothing in between | **pass** |
      > | 3b | same with a deliberately blurry shot | owner only — see the gap below | **pass (owner-observed)** |
      > | 4 | review «الكلام اللي لقيناه» clean, no fallback banner | owner; `ocr-document` 200 in 8721 ms, so no failure existed for a banner to report | **pass** |
      > | 5 | analysis → result, Home 3 → 2 | `analyze.provider` `mistral` `failed_over:false`; `analyze.completed` `invoice`, `counted:true`, `used_today 1`, `daily_limit 3` | **pass** |
      > | 6 | save, reopen from Home | owner (local Drift, no server trace by design) | **pass** |
      >
      > **Zero app errors for the whole session:** no `E/flutter`, no
      > unhandled exception, and every backend call 200 — 3 `get-usage` from
      > the app, 1 `ocr-document` (8721 ms), 1 `analyze-document` (7335 ms).
      >
      > **The one honest gap.** Only **one** capture ever reached the server.
      > The blurry run of §3b left no trace at all, so its result rests on
      > the owner's eyes rather than a log. That is still sufficient for what
      > T14–T16 removed — the gate sat at crop-confirm, *before* any reading,
      > so the absence of the sheet is fully observable on the phone — but a
      > log-backed second capture was not obtained, and this row should not
      > be cited as if it were. The same server-vs-screen cross-check is what
      > caught the owner having already walked §3–§5 while reporting §1.
      >
      > **Benign noise, recorded so nobody re-investigates it.** The run log
      > carries a `W/KeyStore … ServiceSpecificException (code 7)` stack from
      > `flutter_secure_storage`'s key-mismatch path on a fresh install; it
      > resolves itself two lines later (`No data to migrate` → `Migrated 0
      > items` → `completed successfully`). A launch watcher grepping for
      > `Exception` matched that warning and reported a failure that had not
      > happened — filter's fault, not the app's.
      >
      > **Caveat machinery working, not a defect.** `analyze.validated`
      > reported `downgraded: "amounts,amounts,amounts,amounts,dates"`,
      > `dropped_fields: "dates"`, `dropped_items: 1`, giving
      > `status: "partial"` — four amounts and a date shown as unconfirmed
      > rather than as fact, which is §7's «راجع المعلومة» rule doing its job
      > on a real Egyptian invoice.

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

**Modified (34 files)**
`app/di/service_locator.dart` · `app/router/app_router.dart` ·
`core/error/app_failure.dart` · `core/logging/error_code.dart` ·
`core/localization/{app_strings,ar_strings,en_strings}.dart` ·
`core/theme/app_typography.dart` · `core/widgets/privacy_policy_content.dart` ·
`core/accessibility/{text_size_store,high_contrast_store}.dart` ·
`core/audio/{default_reading_speed_store,resume_reading_enabled_store}.dart` ·
`features/analysis/presentation/cubit/{analysis_result_cubit,ocr_review_cubit}.dart` ·
`features/analysis/presentation/screens/{analysis_result_screen,ocr_review_screen}.dart` ·
`features/analysis/domain/usecases/should_fall_back_to_on_device_ocr.dart` ·
`features/capture/presentation/cubit/{image_preview_cubit,image_preview_state}.dart` ·
`features/capture/presentation/screens/image_preview_screen.dart` ·
`features/onboarding/presentation/screens/onboarding_screen.dart` ·
`features/settings/presentation/cubit/{settings_cubit,settings_state}.dart` ·
`features/settings/presentation/screens/{settings_screen,privacy_policy_screen}.dart` ·
`supabase/functions/_shared/config/runtime-config.ts` ·
`supabase/tests/unit/runtime-config.test.ts` ·
`test/support/{app_harness,fakes}.dart` ·
`test/core/localization/app_strings_test.dart` ·
`test/features/settings/presentation/screens/privacy_policy_screen_test.dart` ·
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

### Status — 2026-11-09

| # | State | Evidence |
|---|---|---|
| 1 | **done** | T01–T19 all checked, a commit each, `feature/non-reader` pushed |
| 2 | **done** | recorded in T19: 0 changed · 19 pre-existing infos, 0 errors/warnings · 2825 passed · 767 passed / 69 ignored |
| 3 | **done** | T19's table, with its one owner-observed row called out |
| 4 | **done, and tighter than written** | exactly **one** hit — `app_strings.dart`'s doc comment on the photo opt-in. The two OCR-result strings this item allowed for do not match the pattern at all |
| 5 | **half done — staging applied 2026-11-09** | see below |
| 6 | **done** | `README.md:50` lists F35; F34 § "Amendments (2026-11-08)" |

**Item 5 stands exactly as written, and an earlier note in this file got it
wrong.** A previous pass claimed there is no staging environment, reading the
"Promoted to production — 2026-09-06" section at the end of
`docs/TEST-BUILD-ROLLOUT.md` and missing the superseding note at the top of
that same file, added later (2026-10-05, F27-T04). The truth:

| Role | Project ref | Region | Note |
|---|---|---|---|
| **staging** | `jecujrsvbmashkpobtsz` | `ap-northeast-2` (Seoul) | the original project, redesignated staging on 2026-10-05 |
| **production** | `ivbpmzasxpphclundjyy` | `eu-central-1` (Frankfurt) | what `config/prod.json` points at, so what the published 1.0.2 app talks to |

So there IS a safe rehearsal: **apply to staging first, verify, then apply to
production** — which is what item 5 asked for all along. The correction matters
because the wrong version argued the apply had no rehearsal and therefore
carried more risk than it does.

Two practical notes for whoever runs it:

- `supabase db push` does not work on this network (Postgres port blocked —
  the same reason earlier sessions verified through `app_runtime_config` rows
  and applied changes over HTTPS). The apply goes through the console SQL
  editor, pasting `20261108120000_explain_document_config.sql` as written —
  into **staging first, then production**.
- **An agent session cannot do this apply.** Both the hosted-database reads and
  the PR merges were refused by the harness's permission classifier
  (`Production Reads`, `Merge Without Review`) on 2026-11-09, so the two
  applies and the two merges are the owner's to run, or need an explicit
  permission rule added first. Verifying them afterwards is cheap: the keys
  must read `"1.0"` / `false`, and `schema_version` and `online_ocr_enabled`
  must be byte-identical before and after.
- The smoke test needs the published build **installed**: the device run found
  neither `com.war2aty.app` nor `com.war2aty.app.dev` on the owner's phone, so
  the 1.0.2 APK has to go back on before it can be smoke-tested.

**Staging applied and verified, 2026-11-09 (owner, console SQL editor).**
On `jecujrsvbmashkpobtsz` the two rows read `explain_schema_version = "1.0"`
(jsonb string) and `explain_enabled = false` (jsonb boolean) — the same types
the local apply produced and the two `parseRuntimeConfig` expects.
`schema_version` is still `"2.0"`. **Production (`ivbpmzasxpphclundjyy`) is
still owed**, and so is the published-app smoke test.

**Observed on staging, and it belongs to F20, not here:**
`online_ocr_enabled` is `false`. It has never been flipped on — F20 shipped
with the flag dark pending an owner decision ("production flip", open since
2026-09-30), so online reading is off on that project and the app falls to
on-device Tesseract. F35 neither reads nor writes that key, and the migration
names only its own two keys under `on conflict do nothing`, so it cannot have
changed it. Recorded because an earlier note in this file told the owner to
expect `true` — that was the **local** stack's value, set for the device
pass, not the hosted one. The correct check is "unchanged", not "true".

**A trap worth writing down for the production apply.** The Supabase
dashboard labels the `main` branch of *every* project `PRODUCTION`, so that
badge does not tell you which project you are in. The project named
`war2aty` is staging; production is the one named `war2aty-prod`. The only
reliable check is the ref in the URL.

The apply itself is as safe as it can be made: both rows are
`on conflict (key) do nothing`, nothing reads either value yet, and the local
apply proved by before/after diff that `schema_version` and
`online_ocr_enabled` are untouched.

## Independent review — 2026-11-09

An independent read-only review ran over F35's 21 commits (`b421a3e..HEAD`,
the F32/F33 release line excluded — it has its own PR, #36). Verdict: **pass**,
with no functional, security, performance or state-management defect. It
confirmed independently that every removed DI registration has its deletion,
that no cubit/state field or `app_settings` key is left without a reader, that
all four sealed switches are exhaustive with `keptForOldBuilds` still holding
`IMAGE_QUALITY` and `ANALYSIS_CONSENT_DECLINED` for published builds, that
every privacy string survives and none of the 19 deleted ones was load-bearing
for a privacy promise, that no path can land a new user on a deleted route,
and that the migration touches neither forbidden key and is re-appliable.

**What it found: stale prose, the same class every third task here found.**
Four doc comments still described the removed quality gate or the removed
processing-mode setting as live. All four are fixed.

**What it missed, and why that is the more interesting half.** Re-running the
grep this plan prescribes — the removed flow's own words, not just the
deleted class names — turned up a fifth that the review did not report, and
it is the worst of the set: `onboarding_cubit.dart`'s header said the
first-run flag is flipped "when the user finishes the privacy step". That is
the class that owns the first-run gate, and the privacy step is exactly what
T11 deleted — the trap this whole feature was ordered around, still described
as live in the one file where a reader most needs the truth. The grep also
found `primary_cta.dart` calling the first run "pages" when one page is left,
and three comments saying "the privacy screen's footer" where only the
*policy* screen now exists to have one; all are fixed, and the ambiguity in
those three was created by T11 deleting the class that made "privacy screen"
mean something else.

**What was deliberately left.** Three references are historical and correct in
the past tense: `tts_voice.dart` and `select_voice_for_reading.dart` record why
F30 locked decision 9 needed no privacy-copy change, and
`android_backup_rules_test.dart` describes the backup bug's context. Rewriting
those would falsify a record rather than fix a claim. `image_preview_screen.dart`
keeps its "the quality check that used to stand here … is gone (F35-T15)" note,
which is the point of it. And `CLAUDE.md` §7 still lists the F11 consent gate as
a live user control — true when written, false now, but that file is the owner's
instructions to its agents, not code this feature owns; **flagged for the owner,
not edited.**

**The lesson, sharpened.** T18 searched the deleted class names and missed a
dangling link; T17 searched "first run", "consent" and "quality" in prose but
only inside the files it was already editing. The grep has to be run over all
of `lib/` and `test/`, for the removed flow's vocabulary, *after* the last
deletion lands — not during it. For F39/F40, that is one command and it is the
only thing that catches this class, because no lint does.

Gate re-run after the sweep: `dart format .` 0 changed · `flutter analyze` the
same 19 pre-existing infos, 0 errors/warnings · `flutter test` 2825 passed.
`deno test` was not re-run: the sweep touched no `supabase/` file.
