# F27 · Production readiness

- **Branch:** `feature/production-readiness`, to be cut from `develop` (not created yet) · **Milestone:** M9 (launch)
- **Depends on:** all shipped features (F00–F26) · **Supersedes:** the open F12 tasks (T03–T12), once the owner confirms Q7
- **Progress:** 6 / 28 DONE (2 initial steps + 26 tasks) · **Plan LOCKED 2026-10-04, amended the same day with the initial steps P01–P02.** P01, P02, T01 and T02 done 2026-10-05, and **every open question is now answered**. T02 closed out all three open PRs (Q5); its other two acceptance items were **ruled on by the owner and moved to T14 and T25** — see "T02 record". T03 added CI, **now verified green on PR #29** (the Phase 0 PR, open against `develop`). T04 is **done bar one dashboard switch**: production was rebuilt in `eu-central-1` (Frankfurt) as `war2aty-prod`, the old Seoul project became staging, and **anonymous sign-ins still have to be enabled on the new project** before the app can authenticate at all.

Everything between the current `develop` and a public store launch: environments,
backend rollout, abuse protection, release builds and signing, branding,
monitoring, compliance, store listings, and the launch itself. It comes out of the
production-readiness audit of 2026-10-04 (summarised below).

## Execution rule (owner, 2026-10-04): binding for every task

1. **One task at a time.** Nothing moves from one task to the next on its own.
2. After each task: mark its row DONE here (with what was done, deviations and
   evidence), then send the owner a **detailed progress report**, then **STOP and
   wait for explicit approval** before starting the next task.
3. Tasks marked **(owner)** need the owner's accounts or consoles (Supabase
   dashboard, Play Console, Apple, provider consoles). For those, I prepare exact
   steps, the owner runs them, and I verify where I can.
4. The usual gate applies to every task that touches code: `dart format .`,
   `flutter analyze`, `flutter test` (plus `deno test` for server changes), then
   `/flutter-code-review`, with `@code-reviewer` offered before a PR.
5. Git: one commit per task, pushed after each. PR timing is still open (Q21).

## Locked decisions

Resolved with the owner on 2026-10-04.

1. **The Google Play account is an Organization (company) account.** The
   12-tester / 14-day closed-testing requirement for new personal accounts does
   **not** apply. A closed or internal track is optional, used only as a smoke test
   (T22). It doesn't gate production access.
2. **The app name and the app icon will change.** *Amended 2026-10-04:* the
   **icon** comes first, together with a new splash screen, in initial step
   **P01**. The owner is supplying the image now. The **name** follows later in
   **T14**, which stays BLOCKED until the owner sends it. Every task that shows the
   name or icon (store listing T21, privacy policy T20, iOS display name T23) uses
   the final values, never «ورقتي».
   What the rename touches (inventory for T14):
   - Android: `manifestPlaceholders["appName"]` for `dev` and `prod` in
     `android/app/build.gradle.kts`; the `mipmap-*` launcher icons; a new adaptive
     icon (`mipmap-anydpi-v26`, with foreground, background and monochrome layers);
     the splash.
   - iOS: `CFBundleDisplayName` / `CFBundleName` in `ios/Runner/Info.plist`;
     `AppIcon.appiconset` (1024 px source); `LaunchImage`.
   - Flutter: `assets/app_icon.png`, any brand name inside `AppStrings` (ar + en)
     and the in-app splash or onboarding, plus `app_strings_test`.
   - Outside the app: store listings, privacy policy and terms pages, README.
   - **The package IDs (`com.war2aty.app`, `.dev`) are a separate decision (Q15).**
     They can't change after the first Play upload, so Q15 must be answered before
     T21 even if the visible name changes.
3. **Standing constraints, unchanged:**
   - **Free tier only** for every upstream service, never a paid tier. Capacity is
     handled by free-tier management and graceful degradation.
   - No Firebase.
   - The privacy copy rules in CLAUDE.md §7 (F18-T02 / F20-T24): no text claims that
     nobody sees the image or the text, and no text names a provider.
   - The F20 production order: **secrets → migration → functions → app → flag**,
     each step only with the owner's confirmation.
4. **Two initial steps run before Phase 0** (owner, 2026-10-04): P01 (new icon and
   splash), then P02 (a production release APK the owner installs and tests on
   their phone). The execution rule applies to them too: P01, report, stop, wait
   for approval; then P02, report, stop, wait for approval; only then T01. P01
   goes first so the test APK carries the new icon. The owner can swap the order.

## Audit summary (2026-10-04)

Repo-only audit. The Supabase MCP was not authorised, so the hosted project's live
state (deployed functions, secrets, config values) is **unverified**. T04 and T08
start by checking it.

### Blockers
| # | Finding | Fixed in |
|---|---|---|
| B1 | iOS `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` say «ومحدش بيشوف صورتها», a claim F20-T24 bans. `app_strings_test` doesn't cover native permission prompts. | T10 |
| B2 | The F20 production rollout hasn't run. The Azure and Google secrets are gone from production, so the deployed functions may be failing today. Key revocation and the Mistral training opt-out (D2) are still open. | T08 |
| B3 | `global_daily_call_cap` fails open (unlimited when unset). The repo is public, so the production URL and publishable key are public, and anonymous sign-in is on. A script can drain the shared free AI quotas for every user, and a reinstall resets the per-install limit. | T06 |
| B4 | No public privacy-policy URL. The in-app screen exists, but both stores need a URL. Play Data safety and Apple's App Privacy labels haven't been filled in. | T20, T21, T24 |
| B5 | The L1–L8 live checks ran on the local stack from Egypt. Gemini's free tier has region restrictions, and the hosted Edge runtime runs in a Supabase region. Unverified. | T05 |
| B6 | Play's 16 KB memory-page requirement (apps targeting Android 15+). The Tesseract plugin ships native `.so` files. Unverified. | T19 |
| B7 | iOS has never been built. No `Podfile` (and so no `permission_handler` settings for unused permissions); the flavor setup needs manual Xcode steps (`ios/FLAVORS.md`); no Apple developer team; no `PrivacyInfo.xcprivacy`; `TARGETED_DEVICE_FAMILY = "1,2"` adds iPad, against the no-tablet rule. **Applies only if iOS is in launch scope (Q1).** | T23, T24 |

### High
| # | Finding | Fixed in |
|---|---|---|
| H1 | No production monitoring: production uses `NoopLogSink`, there's no crash reporting, and no `FlutterError.onError` / `PlatformDispatcher.onError`. | T12 |
| H2 | Android `allowBackup` is on by default. The Drift DB goes to Google Drive backup, the secure-storage keys don't restore, so encrypted images become unreadable after a restore, and the backup is a privacy exposure. | T11 |
| H3 | No staging environment. Production is the only hosted project. | T04 |
| H4 | Free-plan Supabase: the project pauses after about 7 days without traffic; no backups or point-in-time restore; MAU and invocation caps. Anonymous users and `analysis_attempts` rows pile up with no cleanup. | T07, T09 |
| H5 | The project is in Seoul (`ap-northeast-2`), about 8,000 km from users, and the region can't be changed. Moving is cheap only before launch. | T04 (with T05) |
| H6 | No CI (`.github/workflows` doesn't exist). The gate and release builds run by hand on one machine. | T03 — **the gate half is fixed** (`ci.yml`, 2026-10-05); release builds still run by hand on one machine, which is T13's. |
| H7 | Release builds have no `--obfuscate --split-debug-info` and no archived symbols. If `key.properties` is missing, the release build quietly signs with the debug key. | T13 |
| H8 | F12-T03 to T12 are still TODO: LTR, large text, performance, temp-file cleanup, security review, OCR regression set, integration tests, release builds. | T15–T18, T19, T23 |

### Medium / Low
| # | Finding | Fixed in |
|---|---|---|
| M1 | Android has only old-style PNG launcher icons, with no adaptive or monochrome icon, and dev and prod share one icon. No `values-v31` (the Android 12+ system splash runs before the teal one). | P01 |
| M2 | Testers already hold `1.0.0+2`, and there's no versioning or tagging scheme. | T25 |
| M3 | A stale `AndroidManifest.xml` comment says "the image never leaves the device", which is wrong since F20 (users never see it). | T10 |
| M4 | The dev-only mock fixtures (`assets/fixtures/analysis/`) ship in the prod bundle. | T13 |
| M5 | No terms of use and no "not legal/medical/financial advice" disclaimer. | T20 |
| M6 | OEM battery-saver handling for reminders was deferred from F25 and needs a check on several real phones. | T18 |
| M7 | Repo state: `develop` is 141 commits ahead of `main`, `main` has 6 commits that `develop` lacks (e.g. `1e14a5f`), and PRs #18, #19 and #28 are open. | T02 |
| M8 | Three Gradle out-of-memory crash dumps (`android/hs_err_pid*.log`), a sign that release builds may be fragile. | T13 |

### Already in good shape (keep)
- The logger only allows a fixed list of fields.
- Secrets live in Supabase only; a pattern scan of the full git history found no leaked keys.
- RLS is forced on the usage tables with no policies.
- `verify_jwt` is on for every function except `health`.
- Plain HTTP is allowed only to loopback/local hosts on both platforms.
- Android release builds use R8 with keep rules.
- The app is locked to portrait.
- An unconfigured prod build degrades gracefully instead of crashing.
- Kill switches exist: `analysis_enabled`, `online_ocr_enabled`, `maintenance_message`, `minimum_app_version`, `daily_limit`.
- Consent gate, encrypted images, and the F12-T01/T02 accessibility and RTL audits.
- `flutter analyze`: 0 errors, 0 warnings, 16 infos.

## Answers (locked by the owner, 2026-10-05) — F27-T01

Q2 and Q16's *process* were already settled by locked decisions #1 and #2.
Every question is locked. Q3 and Q10 came in a second round, after Q10 was
re-asked in plainer terms, and are folded into the table below.

| Q | Answer | Gates |
|---|---|---|
| Q1 | **Android first.** iOS waits — see Q22: there is an iPhone but no Mac, and iOS cannot be built or signed without macOS. T23/T24 are **BLOCKED** until a Mac exists. | T23, T24 |
| Q3 | **~500 analyses/users per day** at launch. T06 and T09 size the free tiers against that number. Date still unstated; capacity, not the calendar, is what those tasks need. | T06, T09 |
| Q4 | **Egypt only** on the store. | T21 |
| Q5 | **Deal with all three PRs**: merge #28 (clean, 0 behind); rebase and merge #18 (offline launch, 141 behind, one trivial docs conflict); **close #19 as superseded by P01**, first cherry-picking `11ad8b6` (synchronous strings delegate), which is unrelated to the splash and still absent from `develop`. | T02 |
| Q6 | **Both languages ship.** So the LTR/English audit in T15 is required, not optional, and the store listing is needed in Arabic *and* English (T21). | T15, T21 |
| Q7 | **Yes — F12 is closed as superseded**, with three of its tasks carried over explicitly rather than lost (see "What F12 leaves behind"). | T01 |
| Q8 | The owner authorises the Supabase connector; production's live state is inspected then. | T04, T08 |
| Q9 | **Yes**, a second free project for staging. The region decision follows T05. | T04 |
| Q10 | **Play Integrity is accepted** for proving the caller is the real app. Whether `global_daily_call_cap` is already set in production is checked directly once the owner authorises the Supabase connector (Q8). | T06 |
| Q11 | Delegated. **`analysis_attempts`: 90 days. Idle anonymous users: 12 months.** The quota resets every Cairo day, so 90 days is far more than any quota decision needs while still showing an abuse pattern; 12 months keeps a returning user's identity without holding dormant rows for ever. | T07 |
| Q12 | Delegated. **`online_ocr_enabled` stays OFF at launch**, flipped in T26 once T08 has verified production. Production is still pre-F20 and unverified (B2/Q8), so shipping it on would put every first user on an untested path; off means they get on-device OCR, which works today. | T08, T26 |
| Q13 | Delegated. **(a) our own Supabase table behind an Edge Function that only accepts allowlisted error codes.** No third party ever sees user content, which Sentry could not guarantee without trusting its scrubbing; it also stays inside the free-tier rule. | T12 |
| Q14 | **Enrol in Play App Signing.** Note the keystore question was only half answered: whether `war2aty-release.jks` is backed up anywhere other than this machine is still unknown. Enrolling makes a lost *upload* key recoverable, so this is no longer fatal — but until T13 it is still the only copy. | T13, T21 |
| Q15 | **Package IDs stay** `com.war2aty.app` / `.dev`, even though the name changes. Final once the first Play upload happens. | T13, T21 |
| Q16 | The name keeps its sound, with the digit "2" replaced by a letter. **The exact spelling is decided with the owner at T14** — pause there. | T14 |
| Q17 | Developer of record: **a company**. Support email: the owner's personal address. Policy pages: **GitHub Pages, which I set up** in T20. | T20 |
| Q18 | Decided together when T20 is reached. | T20 |
| Q19 | Store graphics are not ready; done together when T21 is reached. | T21 |
| Q20 | Delegated. **Android backup off completely.** The manifest never set `allowBackup`, so Android's default (on) applies today and the local database — document text, reminders — plus the encrypted images can be copied to the user's Google Drive. That contradicts what the privacy screen promises, and a restored backup would carry data whose key lives in secure storage and may not come back with it. | T11 |
| Q21 | **A PR per phase.** | all |
| Q22 | **RMX2001** (confirmed working), **ELS NX9**, and **an iPhone — but no Mac**. | T18, T23 |

### Capacity note for T06 (from Q3)

500 analyses a day is the number every free tier is now sized against, and the
owner's standing constraint is that **no upstream service is ever paid for**.
That makes the providers' *daily* ceilings the binding limit, not Supabase:
each analysis costs one OCR call and one analysis call, on shared keys, so the
whole user base draws on one free quota. **T06 must check 500/day against the
current published free-tier limits of Gemini (OCR), Mistral and Groq
(analysis), and against Supabase's Edge Function invocations**, and say plainly
if any of them cannot carry it. Those limits change often enough that quoting
numbers here would be worse than checking them at T06.

### What F12 leaves behind (Q7)

F12 is closed as superseded, but it is not a clean subset. Three of its tasks
have no home in F27, so they are recorded here rather than quietly dropped:

- **F12-T05 (performance profiling)** -> folded into **T18**. P01 already
  profiled the launch path on a real phone; T18 extends that to the rest.
- **F12-T06 (cache cleanup verification)** -> folded into **T16**, next to the
  encryption and "no document content in logs" checks it belongs with.
- **F12-T08 (OCR regression dataset)** -> **deliberately deferred past launch.**
  A labelled set plus a runner and a recorded baseline is its own project, and
  the OCR path has shipped and is in use. Deferring it is a conscious trade,
  not an oversight: without it, an OCR regression is caught by hand.

The rest map cleanly: T03/T04 -> T15, T07 -> T16, T09/T10 -> T17, T11 -> T13 and
T19, T12 -> T23 and T24.

## Tasks

`(owner)` = the owner runs it in their own console; I prepare and verify.

### Initial steps (before Phase 0), added 2026-10-04
| # | ID | Task | Output / acceptance | Depends on | Status |
|---|---|---|---|---|---|
| P1 | F27-P01 | **New app icon and splash screen** | **Input:** the owner's icon image (ideally a square PNG of at least 1024×1024; transparent background, or a flat background colour stated). **Scope:** (1) Android launcher: legacy `mipmap-*` PNGs, round icon, and an **adaptive icon** (`mipmap-anydpi-v26`, with foreground inside the 66% safe zone, background, and a **monochrome** layer for Android 13+ themed icons); the dev flavor gets a visibly marked variant so dev and prod are easy to tell apart. (2) iOS `AppIcon.appiconset`, with a 1024 px source and no alpha. (3) **Splash:** Android before 12 (`launch_background.xml`, light and night); Android 12+ through a new `values-v31` / `values-night-v31` (`windowSplashScreenBackground` and the icon); iOS `LaunchScreen` / `LaunchImage`; the Flutter-side splash and `assets/app_icon.png` wherever the app shows the icon. (4) **Colour adjustments:** splash background and any icon-adjacent colours tuned to the new icon. Any change to the app-wide palette (CLAUDE.md design tokens) is proposed with a preview and **applied only with the owner's approval**. **Tooling:** either a dev-only generator (`flutter_launcher_icons` / `flutter_native_splash`, which needs the dependency rule's justification) or a hand-written generator script. Chosen at task start with the owner. **Branch:** `feature/production-readiness`, cut from `develop` here instead of at T01. **Acceptance:** sharp icon on the launcher at every density; the themed icon works; the splash shows the new icon in light and dark on Android 11, 12+ and iOS; no white flash; gate green; checked on the owner's phone. **Icon received 2026-10-04 (chat preview):** a deep-teal rounded square with a gradient (close to the brand Deep teal `#0A5C64`), a silver ring, a white document with a check mark, and above it a "network brain" with gold-highlighted nodes. Notes for the task: (a) the preview is a **mockup** (icon on a phone background, drop shadow, 1024×559), so it can't be the source; (b) the network's thin lines and small nodes will blur at launcher size (48 dp) and in the monochrome layer, so a simplified small-size version may be needed (proposed to the owner, never applied on my own); (c) the teal background suits the splash, and the brand palette probably needs no change. | The owner's icon (`assets/branding/icon.jpg`) | DONE 2026-10-05: approved by the owner and committed (904bcb7); the on-phone look is still the owner's to confirm from the P02 APK (see "P01 record") |
| P2 | F27-P02 | **Production release APK for the owner's phone** | `flutter build apk --flavor prod --release -t lib/main_prod.dart --dart-define-from-file=config/prod.json --target-platform android-arm64`, **signed with the release key** (`android/key.properties`), build number bumped above `+2`. Built from the branch state agreed at task start (default: `develop` + P01). **Report:** the APK path, size, version, SHA-256, install steps, and a smoke check (launch, icon, splash, capture → on-device OCR). **Known limits (written into the report):** (a) earlier tester APKs were signed with the debug key, so this one **won't install over them**: uninstall first (local data is lost); (b) the APK talks to the **production** backend, whose state is unverified and still pre-F20 (B2, Q8), so online reading and analysis may fail until T08. That's a backend gap, not an APK defect. If the owner prefers, the analysis check waits for T08. | P01 | DONE 2026-10-05: APK built, signed, installed and smoke-checked on the owner's phone (see "P02 record"); camera→OCR pass left to the owner |

### Phase 0: Decisions and repo
| # | ID | Task | Output / acceptance | Depends on | Status |
|---|---|---|---|---|---|
| 1 | F27-T01 | Lock the answers | Every open question answered here; F12 marked superseded (if Q7 = yes); the features index lists F27 (the branch already exists from P01) | P02 | DONE 2026-10-05: 20 of 22 answered and locked (see "Answers"); F12 closed as superseded and the index updated. Q3 and Q10 answered 2026-10-05; **every question is now locked**. |
| 2 | F27-T02 | Repo cleanup and release branching | PRs #18, #19 and #28 merged or closed per Q5; `main` and `develop` back in line; release-branch and tag scheme written in T25's doc | T01 | **PARTLY DONE 2026-10-05:** all three PRs closed out per Q5 — #28 merged (`f9b7127`), #18 rebased and merged (`7805a56`), #19 closed as superseded with `11ad8b6` cherry-picked (`90efdc8`); gate green. Its other two acceptance items were **ruled on by the owner 2026-10-05 and deliberately moved out of T02**: `main`↔`develop` is deferred to **after T14**, and the branch/tag scheme stays **T25's** to write — see "T02 record". |
| 3 | F27-T03 | CI (GitHub Actions, free for public repos) | Every PR runs `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, and `deno test` for `supabase/`; no secrets in CI | T02 | **DONE 2026-10-05:** `.github/workflows/ci.yml`, two parallel jobs, all four checks, no secrets, `permissions: contents: read`. Every command re-run locally at this commit and green. **Verified live on PR #29** (run `37277905375`, 2026-10-05): both jobs green on the first run — App 5m10s, Backend 16s, every step passing. |

### Phase 1: Backend
| # | ID | Task | Output / acceptance | Depends on | Status |
|---|---|---|---|---|---|
| 4 | F27-T04 | Staging project and region decision (owner) | Production's live state recorded (Q8); a free staging project with all migrations and functions; `config/staging.json`; a region decision written down | T01 | **BLOCKED 2026-10-05 — owner decisions owed.** Production's live state **is** recorded and confirms B2 with dates (pre-F20 code, schema and config); the CLI was already authenticated, so the MCP connector was not needed. Nothing was created: the region choice is irreversible, the free tier's 2 projects are both taken, and **production sits in `ap-northeast-2` (Seoul) serving Egypt**. All three decisions were approved by the owner on 2026-10-05 and carried out: Singapore leftover deleted, **`war2aty-prod` created in `eu-central-1`** with all 7 migrations, all 4 functions and all 11 secrets, Seoul demoted to staging and brought up to the same code, `config/prod.json` repointed and `config/staging.json` added. **One owner step remains — enable anonymous sign-ins on the new project** (verified disabled: `anonymous_provider_disabled`), plus renaming Seoul to `war2aty-staging` and separate staging provider keys. See "T04 record (continued)". |
| 5 | F27-T05 | Provider reachability from the hosted runtime | `ocr-document` (Gemini) and `analyze-document` (Mistral → Groq) succeed from the hosted Edge runtime on staging; function region pinned if needed; evidence recorded | T04 | TODO |
| 6 | F27-T06 | Abuse protection and capacity | `global_daily_call_cap` set to fit the free quotas (documented maths); anonymous sign-in rate limits checked; CAPTCHA or attestation per Q10; server tests | T05 | TODO |
| 7 | F27-T07 | Data retention | `pg_cron` jobs clean up old `analysis_attempts` rows and idle anonymous users per Q11; migration plus tests; database size checked | T04 | TODO |
| 8 | F27-T08 | F20 production rollout (owner) | In order: secrets → migration `20260929120000` → functions → (app at T26) → flag per Q12. Azure and Google keys revoked; Mistral training opt-out on; local `.env` cleaned; each step checked live | T05, T06 | TODO |
| 9 | F27-T09 | Operations runbook | `docs/OPERATIONS.md`: how to use each kill switch, how to watch free-tier quotas (Gemini, Mistral, Groq, Supabase), how to avoid the inactivity pause, incident steps | T08 | TODO |

### Phase 2: App hardening
| # | ID | Task | Output / acceptance | Depends on | Status |
|---|---|---|---|---|---|
| 10 | F27-T10 | Privacy copy in native permission prompts | iOS permission strings reworded per CLAUDE.md §7; a test guard covering `Info.plist` (and any Android-visible copy); manifest comment fixed | T01 | TODO |
| 11 | F27-T11 | Android backup rules | `dataExtractionRules` / `fullBackupContent` (or `allowBackup="false"`) per Q20; checked with `adb shell bmgr` | T01 | TODO |
| 12 | F27-T12 | Error handling and production monitoring | `FlutterError.onError` + `PlatformDispatcher.onError` routed to the logger; a production sink per Q13 that only sends allowed fields, never content; tests | T01, T04 | TODO |
| 13 | F27-T13 | Release build hardening | A prod release **fails** without a release key; `--obfuscate --split-debug-info` with symbols archived; mock fixtures out of the prod bundle; Gradle memory settings fixed; documented build commands | T01 | TODO |
| 14 | F27-T14 | Branding: new app name | Applies the name part of decision #2's inventory: `appName` placeholders (dev + prod), iOS `CFBundleDisplayName` / `CFBundleName`, any brand name in `AppStrings` (ar + en) and the Flutter splash or onboarding, `app_strings_test`, README. Also anything P01 left for later. (The icon and splash are done in P01.) **Also carries the `main`↔`develop` reconciliation deferred from T02** (owner-approved 2026-10-05): once the name is final, recover `LICENSE`, `CONTRIBUTING.md` and `config/prod.json.example` from `main`'s `1e14a5f` onto `develop`, rewrite that README for the new name, and refresh `supabase/.env.example` to post-F20 providers — see "T02 record". | **Owner's final name** (decision #2), P01 | BLOCKED |

### Phase 3: Quality (takes over F12-T03 to T10)
| # | ID | Task | Output / acceptance | Depends on | Status |
|---|---|---|---|---|---|
| 15 | F27-T15 | UI audits | Large text with no overflow; LTR audit if English ships (Q6); performance profile on a low-end phone (heavy work off the UI thread); temp and session files reliably removed | T10–T13 | TODO |
| 16 | F27-T16 | Security review | `/security-review` plus manual checks: encryption, logs, secure storage, network config, dependency audit (`flutter pub outdated`, Deno deps); findings fixed or accepted in writing | T12, T13 | TODO |
| 17 | F27-T17 | Integration tests | Invoice path (capture → OCR → analyze → result → reminder → save → home) and the failure paths (timeout, OCR fallback, limit reached) | T15 | TODO |
| 18 | F27-T18 | Pass on several real phones | Release build on every available phone (Q22); reminder delivery under OEM battery savers; findings fixed | T14, T17 | TODO |

### Phase 4: Android release
| # | ID | Task | Output / acceptance | Depends on | Status |
|---|---|---|---|---|---|
| 19 | F27-T19 | Play compliance build | Target SDK meets Play's current requirement; 16 KB page alignment checked for every native `.so`; permission list reviewed; signed `.aab` built and its size recorded | T13, T14 | TODO |
| 20 | F27-T20 | Privacy policy and terms | Arabic privacy policy (wording consistent with §7) and terms per Q18, at a public URL (Q17); linked from the in-app screen; support contact | T01, T14 | TODO |
| 21 | F27-T21 | Play Console setup (owner) | App created with the final package ID (Q15); Play App Signing; Data safety form; content rating; target audience; Arabic store listing, screenshots, feature graphic and 512 px icon with the final branding | T19, T20 | TODO |
| 22 | F27-T22 | Internal or closed track smoke test (optional) | Not a Play requirement (decision #1). One internal-track build installed from Play on real phones; blocking findings fixed | T21 | TODO |

### Phase 5: iOS (only if Q1 includes iOS)
| # | ID | Task | Output / acceptance | Depends on | Status |
|---|---|---|---|---|---|
| 23 | F27-T23 | iOS build setup (Mac) | Flavors and schemes per `ios/FLAVORS.md`; `Podfile` with `permission_handler` settings; iPhone only; Tesseract builds on iOS; display name from decision #2 | T10, T14 | TODO |
| 24 | F27-T24 | iOS compliance and TestFlight (owner) | `PrivacyInfo.xcprivacy`; App Privacy labels; signing; TestFlight build; App Store listing and review submission | T20, T23 | TODO |

### Phase 6: Launch
| # | ID | Task | Output / acceptance | Depends on | Status |
|---|---|---|---|---|---|
| 25 | F27-T25 | Release process document | `docs/RELEASE.md`: versioning (next build number above `+2`), changelog, tagging, `minimum_app_version` policy, rollback with the kill switches. **Owns the release-branch and tag scheme outright** (owner-approved 2026-10-05: T02 was not to pre-empt it), and with it the `develop` → `main` release merge that T14 unblocks. | T02, T09 | TODO |
| 26 | F27-T26 | Production launch (owner) | Staged rollout (percentages written down); F20 app step and flag per Q12; first-72-hour watch per T09; launch report | all above | TODO |

## Exit DoD

- Every blocker B1–B7 (B7 only if iOS is in scope) is fixed and its evidence
  recorded in its task row.
- The production backend runs F20, with a capacity cap, abuse protection, data
  retention and a runbook. A staging project exists.
- The app ships with the final name and icon, signed with the release key (Play
  App Signing), obfuscated with symbols archived, and with privacy-safe
  production monitoring.
- No user-visible text, store listing or privacy-policy page breaks CLAUDE.md §7.
- A real-device pass of the release build is complete; the store listing is live
  on Play (and the App Store if in scope); the rollout and rollback steps are
  written down.

## Notes

### P01 record (2026-10-04)

- **Source:** `assets/branding/icon.jpg` is the owner's mockup (1024×559 JPG,
  with the icon tile about 448 px inside it), not a clean artwork file. No
  better source exists yet, so the icon is lifted out of the mockup:
  - `tool/branding/generate_brand_assets.dart` (Dart, using the `image`
    package the app already depends on, so **no new dependency**) finds the
    tile, models its background in 2D (the vertical gradient from about
    `#035763` to `#023742`, plus the soft glow behind the symbol), and separates
    the symbol from it with colour-to-alpha;
  - it then writes every target. Re-run with
    `dart run tool/branding/generate_brand_assets.dart --preview` once a better
    source arrives; `--source <path>` takes any file.
  - `--preview` writes review images to `build/branding-preview/` (git-ignored).
- **Android:**
  - adaptive icon (`mipmap-anydpi-v26`): background, foreground and monochrome
    layers at every density. The tile maps onto the 72 dp visible area, so the
    symbol keeps the source's proportions inside the 66 dp safe zone;
  - legacy `ic_launcher` and `ic_launcher_round` icons, with
    `android:roundIcon` added to the manifest;
  - **dev flavor:** `src/dev/res` overrides only the background (brand amber)
    and the legacy icons, so a dev build is unmistakable on a home screen.
- **Animated splash (owner-approved 2026-10-04 from an HTML preview; the ring
  design below was replaced on 2026-10-05 — see "the last 4–6 dropped frames".
  The preview, now `tool/branding/splash_preview.html`, shows all three
  candidates with the approved one marked):**
  - **Native splashes show the teal alone, no mark**, so the mark appears
    once, in the Flutter animation:
    - before Android 12: `launch_background.xml` (unchanged);
    - Android 12+: `values-v31` / `values-night-v31` with
      `windowSplashScreenBackground` and a transparent `splash_icon.xml`,
      because the system splash would otherwise show the launcher icon;
    - iOS: `LaunchImage` and the storyboard unchanged.
  - **Flutter splash:** the mark alone at the centre (128 dp) on the brand
    gradient. A soft radial glow (0–0.7 s); the mark fades in from 0.90 to full
    scale (0.10–0.75 s); three rings fade in at 0.25 / 0.40 / 0.55 s. The rings
    turn (inner and outer clockwise at 30 and 14 °/s, middle counter-clockwise
    at 22 °/s) and pulse ±25 % on a 2.4 s cycle, out of phase, for as long as
    the launch takes. Drawn by `SplashRingsPainter`, which repaints through a
    `repaint` listenable, so frames never rebuild widgets.
  - **No text on screen.** The app name, tagline and loading dots are removed;
    `PulsingDots`, its test and the now-unused `appTagline` string are deleted.
    The app name labels the mark, and the launch stage is a live region, for
    screen readers only.
  - **`kLogoEntranceDuration`: 6 s → 1.8 s** (approved timing). This overlaps
    open PR #19, which also changes it (Q5).
  - **Reduced motion:** the settled frame at once, with still rings and no
    ticking clock.
  - Tests pin all of this: no text; the mark's label and the live region; fade
    and scale; centred at 128; rings still turning after the entrance; reduced
    motion leaves no frame scheduled. Mutation-checked: removing the live
    region, or starting the clock under reduced motion, each fails a test.
- **The old `PaperPlaneLogo`** (an animated drawing of the *old* icon) is
  deleted.
- **Smooth hand-off to the app (owner chose option A, 2026-10-04).** The owner
  saw the splash cut to Home. Cause: `app.dart` swapped the splash's
  `MaterialApp` for the router's in one frame, with no transition, and Home's
  costliest first frame happened in full view. Now `SplashHandOff`
  (`bootstrap/presentation/widgets/splash_hand_off.dart`):
  - mounts the router app **under** the still-opaque splash and lets
    **2 frames** through, so Home's first build and paint happen out of sight;
  - then plays a **400 ms exit**: the splash fades out while the mark grows
    1.0 → 1.06 and the rings spread 15 % (via the `SplashExit` inherited
    animation). Then the splash leaves the tree;
  - keeps both layers mounted throughout (keyed), so the splash animation never
    restarts and Home is never rebuilt;
  - ignores touches and screen readers from the start of the exit;
  - under reduced motion, uses a plain 150 ms fade;
  - uses `RepaintBoundary`s, so the ticking splash never repaints Home.

  The splash sets light status-bar icons, which switch to Home's dark ones
  only once it leaves. Tests: `splash_hand_off_test` (7) plus 3 more in
  `splash_screen_test`. Mutation-checked: letting the splash take touches, or
  stay visible to screen readers, during its exit each fails a test.
- **Launch work off the UI thread.** `tzdata.initializeTimeZones()` decoded
  the whole timezone database synchronously on the UI isolate, in the
  "reminders" launch step, i.e. during the splash animation. It now runs in
  `Isolate.run`, and only `Africa/Cairo` (the one zone the app uses) is added
  to the main isolate's database. The database already ran on a background
  isolate (`driftDatabase`). The splash mark is also pre-decoded in
  `bootstrap()`.
- **Notification small icon (regression fix).** P01 made `@mipmap/ic_launcher`
  an adaptive icon, and notifications used it as their small icon. Android
  draws that from alpha only, and an adaptive icon there breaks notifications
  on Android 8.0. The generator now writes a white silhouette,
  `drawable-*/ic_stat_notify.png` (24 dp), used by
  `FlutterLocalNotificationsPort`.
- **"Settle, then reveal" (owner approved 2026-10-04), measured on the RMX2001.**
  The owner saw the rings freeze just before Home. Measured setup: profile
  build, prod flavor, Impeller on OpenGL ES, 60 Hz; frame-gap probe, now
  removed. Findings, and the fix for each:
  - **Home's first build (~55 ms) and its rebuild with data (~65–100 ms)**
    landed while the rings turned, which was the freeze. Now `SplashHandOff`:
    1. **settles** the rings to a stop (350 ms, speed eases out as `(1−p)²`,
       then the clock stops);
    2. **mounts the app under the motionless splash**, waiting frame by frame
       until Home reports its content (`HomeState.hasLoaded`, via
       `LaunchReveal`; static first-run pages report at once; 600 ms cap);
    3. only then **reveals**.
  - **The app's very first frame (~210 ms)** fell on the entrance's first
    frames, so the mark jumped. The entrance now starts 2 frames later, on a
    still teal screen identical to the native splash.
  - **Tabs:** go_router already builds only the Home branch at launch
    (`preload: false`). Locked in by a test.
  - **Data reads** were already on a background isolate (Drift), so they
    were not deferred: deferring would have revealed a half-loaded Home.
    Deferred instead: opening the reminder a notification tap launched the app
    for (`ReminderNotificationOpener` waits for `LaunchReveal.revealed`).
  - **Tried and dropped:** pre-warming the fade's opacity layer (0.99
    opacity). It made no measurable difference.
  - **Results (4 cold starts):**

    | Phase | Before | After |
    |---|---|---|
    | Hand-off | 3–5 dropped frames, worst 63–99 ms (visible freeze) | settle: 0 dropped; Home's long frames happen hidden (still screen); fade: 1–2 single dropped frames of 30–40 ms |
    | Entrance | 210 ms jump at its start | jump gone; 3–6 single drops of 26–59 ms remain, timed with the `reminders` and `usage` launch steps |

- **Deferred housekeeping (owner approved option A, 2026-10-05).** The launch
  sequence is split in two:
  - **blocking** (`InitializeApp`, unchanged shape): `session`, `config`, and a
    `reminders` step trimmed to setup only. That setup cannot move: it loads
    the IANA data every Cairo-day reading needs (`core/time/cairo_day.dart`,
    which both usage repositories call as Home builds), and no notification may
    be scheduled before the plugin and its channel exist. It also still reports
    the launch tap (F25-T04) before the router mounts;
  - **deferred** (`FinishLaunch`, new use case): `cleanup`, the reminder
    `reconcile`, and the usage `syncUsage`. `BootstrapCubit.finishLaunch()`
    runs them from the hand-off's `onRevealed`, after `LaunchReveal` is marked
    so a launch notification still opens first. It runs once per app start,
    logs non-critical failures, and never throws.

  `BootstrapStep.runGuarded()` was extracted so both runners share one timeout
  and never-throws guard. Tests: 5 for `FinishLaunch`, 2 on the cubit, and one
  in `shell_test` that boots the real app and proves the wiring; all three are
  mutation-checked.
  - **Results (4 cold starts, same setup):**

    | Window | Before option A | After |
    |---|---|---|
    | Reveal fade (visible) | 1–2 drops | **0–1 drop** (one 33–35 ms frame) |
    | Settle (visible) | 0 drops | **0 drops** |
    | Housekeeping | inside the splash | runs entirely **after** the reveal ends |
    | Raster per frame | median 17.0 ms, 60 % over budget | **median 7.6 ms, 32 % over** |

- **The 160–230 ms stall: found and fixed (2026-10-05).** It was *not* a
  garbage collection, as first assumed. Diagnosing it needed an instrument that
  could tell the two possible causes apart: an 8 ms periodic timer on the UI
  isolate alongside the frame callbacks. If the timer stalls across the gap the
  isolate was blocked; if it keeps ticking, frames merely were not delivered.
  - **It blocked the UI isolate** (the timer stalled 154–216 ms with it), and
    marks around each launch stage put it exactly between `config` and
    `reminders`: the **`config` step**, the app's first HTTPS request, paying
    for the TLS and certificate setup every later request reuses. RSS grew
    ~12 MB across it.
  - **Fix:** `config` moved to `_buildDeferredSteps`, first in the list.
    Nothing on the first screen needs it: the client reads
    `RuntimeConfigStore` in exactly one place — the stub usage repository of an
    *unconfigured* build, lazily, at analysis time — and it starts on
    `RuntimeConfig.defaults`. A configured build never reads it at all
    (`analysisEnabled` and the quota come from the usage response). So the
    first HTTPS request now happens on a Home that is already still.
  - **Verified: 9 cold starts** (4 after a fresh install, then 5 more without
    reinstalling). In every one the isolate is **never blocked while the
    animation runs**, and the worst gap is a single frame, 34–51 ms.
- **The last 4–6 dropped frames are not the splash's drawing — proven, not
  argued (2026-10-05).** The owner replaced the ring design to be rid of them,
  choosing **option 3, the still mark** (preview
  `build/branding-preview/splash-options.html`): the mark alone over a static
  gradient and glow, breathing, with no orbiting elements at all. Measured on
  the same phone, four cold starts: **still 5–6 dropped single frames, worst
  34–38 ms** — the same as the rings. Adding repaint boundaries above the
  animated parts changed nothing either (5 dropped, 34–38 ms).
  - **So the design was never the cause.** A screen drawing almost nothing
    misses as many frames as one orbiting seven glowing nodes.
  - **An earlier reading here was wrong and is corrected:** "raster median
    16.9 ms against a 16.7 ms budget" was read as the scene being too
    expensive. It is not a cost — `rasterDuration` includes waiting for the
    next vsync and the buffer swap, so a figure that tracks the frame period
    is what *keeping up* looks like. The variant comparison that seemed to
    indict the node halos (5.5 ms against 16.9 ms) was run-to-run noise: the
    same figure swung 7.6–16.9 ms across builds of near-identical code.
  - **What they actually are:** single missed frames while the launch does its
    real work next door — the session request, opening the database, the
    notification plugin and its isolate — on a budget chipset. Dart is idle
    across every one of them, so nothing in the splash can prevent them.
  - **Open for the owner:** accept them (they are one missed frame each,
    during launch), or trim what still runs before the first screen. Keeping
    the ring design would have cost nothing in smoothness either, so the choice
    between the two is purely a design one.
- **One launch is still slow, by design of the measurement:** the first start
  straight after `adb install` shows a ~184 ms stall while Android optimizes
  the freshly written app. Play delivers pre-optimized artifacts, so a real
  install does not reproduce it; every later cold start is clean.
- **Also tried and reverted:** approximating the node halos with stepped fills
  instead of a radial gradient, to cut shader allocation. Measured: raster
  unchanged (16.9 ms), because the cost is the translucent fill area, not the
  shader. Reverted.
  - **Tried and dropped:** building the app widget (and so resolving the
    router) only in the still phase, on the theory that it caused the 160 ms
    stall. Measured: no effect. Reverted rather than kept as unmeasured
    complexity.
- **Colours:** no change to the app palette. The splash keeps the brand teal
  gradient (`#0E7C86` → `#0A5C64`) and `splash_bg` (`#0A6C76`). The icon's own
  background is darker (`#035763` → `#023742`) and is kept as the owner drew
  it.
- **iOS:** generated on Windows and not built. Checking it needs a Mac (T23).
  The iPad icon sizes are still generated; T23 decides on iPhone-only.
- **Known limits, for the owner:**
  - **Resolution:** the symbol's source is about 315 px tall. Android launcher
    icons need at most about 290 px, so they're sharp. The Flutter splash
    mark at 3x (384 px) is upscaled about 1.2× and the iOS 1024 px icon about
    2.3×, so both are slightly soft. **A square 1024 px or larger source, or SVG, fixes it with
    one re-run.** Needed before the App Store submission (T24) and wanted for the
    Play 512 px store icon (T21).
  - **Small sizes:** at 36–48 dp the network's lines and nodes merge into a
    texture. A simplified small-size variant (fewer, larger nodes) was proposed
    to the owner and **not applied**.
- `assets/app_icon.png` (bundled but referenced nowhere in the code) was
  regenerated from the new icon so no old branding remains.

### P02 record (2026-10-05)

Release APK built from `feature/production-readiness` (= `develop` + P01), the
plan's default, with the command P02 specifies. Installed and smoke-checked on
the owner's RMX2001.

- **The APK.** `build/app/outputs/flutter-apk/app-prod-release.apk`,
  version 1.0.0 (build 3, up from +2), 36.5 MB,
  SHA-256 `d18b2eb160caa444cee3b8639d62c869af818c2661a952142e517a9349b2b53c`.
  Signed with the release key `war2aty` (cert SHA-256
  `8B:72:40:7C:…:79:14:03`, CN=Yusef Abdulkarim, O=War2aty, valid to 2054),
  **v2 scheme**, verified with `apksigner`. v1 is absent and does not matter:
  `minSdk` is 24, and v1 is only needed below API 24.
- **A release-only bug P02 caught.** `isShrinkResources` deleted
  `drawable/ic_stat_notify` from the APK: the notification small icon is named
  from Dart as a string (`'@drawable/ic_stat_notify'`), so nothing on the
  Android side references it and the shrinker could not see it. Profile builds
  keep it, so no earlier device test could have found this — a fired reminder
  would have had no icon. Fixed with the standard keep rule,
  `android/app/src/main/res/raw/keep.xml`; the icon is back at all five
  densities. It is the only resource named this way (checked across `lib/`).
- **Size: 54.7 MB → 36.5 MB.** `--target-platform` only limits Flutter's own
  engine, so the plugins' native libraries (Tesseract, OpenCV) shipped for
  three ABIs. `android/app/build.gradle.kts` now reads the same
  `target-platform` property Flutter passes and excludes the other ABIs at
  packaging time. Deliberately driven by that flag rather than pinned to
  arm64: a build that names no platform — the App Bundle for Play — keeps
  every ABI, so 32-bit devices are still served and Play splits per device
  itself. `ndk.abiFilters` alone was not enough (something downstream re-adds
  the ABIs), hence the `packaging.jniLibs` exclusion, which runs last.
  `assets/app_icon.png` was also dropped from the bundle (204 KB): it is the
  512 px store-listing icon the generator keeps in step, and nothing loads it
  at runtime. The file stays in the repo for the listing.
- **Smoke check (passed).** Uninstall was required and the device's local data
  was lost, as the task warned — the old install was debug-signed
  (`f8b346a4`), the new one is not (`4dd75bbb`). Installed clean,
  `versionCode=3`. Cold launch: native teal → the splash's mark over its glow,
  light status-bar icons, no text → Home in Arabic RTL with the 4-tab shell,
  dark status-bar icons, correct empty state for a fresh install. The
  reminders tab opens with its own empty state, so lazy tab building works in
  a minified build too. **No exceptions or errors in logcat**, and nothing was
  broken by R8 or resource shrinking.
- **Left to the owner:** the camera → on-device OCR pass needs a real page in
  front of the lens, so it cannot be driven from here. The launcher icon's
  look on the home screen is also the owner's to confirm; it is verified
  *present* (adaptive icon resolving at every density, with the monochrome
  layer for themed icons).
- **Backend caveat stands.** The APK points at production, which is still
  pre-F20 and unverified (B2, Q8), so online reading and analysis may fail
  until T08. That is the known backend gap, not an APK defect.

### T02 handover (written 2026-10-05, for a fresh session)

T02 runs in a new chat, so everything it needs is here rather than in a
conversation it cannot see.

**Scope (the owner's Q5 answer): deal with all three open PRs.**

| PR | Branch | State as measured 2026-10-05 | What to do |
|---|---|---|---|
| #28 | `feature/ui-polish-bars-snackbar` | 6 commits ahead, **0 behind**, no conflicts | Merge. It also brings `docs/features/F26-bars-and-snackbar.md`, after which **F26 joins the index** and the note under the table in `docs/features/README.md` comes out. |
| #18 | `feature/offline-first-launch` | 4 ahead, **141 behind**, one conflict — `docs/features/README.md` only | Rebase onto `develop`, resolve that docs conflict, merge. It touches `lib/app/di/service_locator.dart`, which auto-merges. |
| #19 | `feature/splash-startup-latency` | 4 ahead, 40 behind, no conflicts | **Close as superseded by P01** — but first cherry-pick `11ad8b6` ("perf(localization): resolve the strings delegate synchronously"). Verified 2026-10-05: `AppStringsDelegate.load` is still `async` on this branch, so that commit is a real, splash-independent win. Its other two commits are dead: they tune a 6 s entrance that is now 1.8 s, and strip blurs and text the splash no longer has. |

**Before merging anything**, re-measure those numbers — `develop` may have moved:
`git fetch origin` then, per branch,
`git rev-list --count origin/develop..origin/<branch>` and the reverse, plus
`git merge-tree --write-tree origin/develop origin/<branch> | grep CONFLICT`.

**Then:** `dart format .`, `flutter analyze` (expect the same 16 pre-existing
infos as `develop`, no errors), `flutter test` (2176 passing as of T01). Commit
per the one-commit-per-task rule, push, and **open the Phase 0 PR** — the owner
chose a PR per phase (Q21), and Phase 0 is T01–T03, so the PR opens once T03
(CI) is done, not at T02.

**Then stop** for the owner's approval, per the execution rule at the top.

### T02 record (2026-10-05)

**Done: all three open PRs closed out, exactly as Q5 directed.**

The handover's measurements were re-taken first and matched to the commit:
#28 6 ahead / 0 behind, clean; #18 4 ahead / 141 behind, conflicting in
`docs/features/README.md` only; #19 4 ahead / 40 behind, clean.

| PR | What happened | Result |
|---|---|---|
| #28 | Merged with a merge commit (the repo's existing style). Brought `docs/features/F26-bars-and-snackbar.md`, so **F26 is now in the index** and the "missing on purpose" note under the table is gone. | MERGED — `f9b7127` |
| #18 | Rebased onto `develop`. The one conflict was the index table: `develop`'s side kept, the F19 row inserted in numeric order, total corrected, and F19's own critical-path sentence re-appended. The other three commits replayed clean — `lib/app/di/service_locator.dart` auto-merged across all 141 commits. Force-pushed with `--force-with-lease`, then merged. | MERGED — `7805a56` |
| #19 | `11ad8b6` cherry-picked with `-x` onto `feature/production-readiness` first — authorship, message and provenance line intact. Verified still needed: `AppStringsDelegate.load` was still `async` on `develop`. Its import hunk conflicted (this branch has `dart:io` and already imported `app_localizations.dart`); resolved by keeping both and ordering per `directives_ordering`. Then closed, with the full rationale posted as a PR comment — including why the other two commits were dropped (they tune a 6 s entrance that is now 1.8 s and strip blurs and text the P01 splash no longer has). | CLOSED — cherry-pick is `90efdc8` |

**Merging `develop` back into `feature/production-readiness`** took two
resolutions worth recording, because both sides were right:

- `docs/features/README.md` — F26 (from #28), F19 (from #18) and F27 (from T01)
  all belong in the table; total is now **315 tasks across 25 features**.
- `lib/app/di/service_locator.dart` — a doc-comment clash where
  `_sessionBound` (F19, `develop`) and `_buildDeferredSteps` (P01, this branch)
  each existed on one side only. Both kept; the comment is `develop`'s new
  wording with this branch's `_buildDeferredSteps` sentence re-appended.

**Gate: green.** `dart format .` clean (685 files, 0 changed), `flutter analyze`
16 infos and no errors (the same 16 as before — all pre-existing, none in the
merged code), `flutter test` **2206 passing, 0 failing**. The earlier count of
2176 was measured before #28 and #18 landed; no test file was lost in either
rebase (the file sets were diffed to confirm it).

**Two acceptance items were moved out of T02, with the owner's approval
(2026-10-05): both recommendations below were accepted as written.**

1. **`main` ↔ `develop` are still apart**, now 6 and 153 commits. The 6 on
   `main` are five old merge commits plus one real content commit, `1e14a5f`
   ("professionalize repo for external review"), which `develop` never got:
   `LICENSE`, `CONTRIBUTING.md`, `config/prod.json.example`, a `README.md`
   rewrite, `.gitignore` and `pubspec.yaml` cleanups. Merging `main` into
   `develop` conflicts in `README.md` and `supabase/.env.example`.
   **Deferred to after T14 — owner-approved 2026-10-05.** That `README.md`
   names the app «ورقتي», which changes at T14, and its
   `supabase/.env.example` predates F20 (it still lists providers that were
   deleted), so resolving it today means resolving it again later. The work is
   written into the **T14** row: recover `LICENSE`, `CONTRIBUTING.md` and
   `config/prod.json.example` from `1e14a5f` as a separate small commit on
   `develop`, rewrite the README for the new name, refresh
   `supabase/.env.example`. The `develop` → `main` release merge itself then
   happens under the scheme **T25** defines.
2. **The release-branch and tag scheme** belongs in `docs/RELEASE.md`, which is
   T25's deliverable and does not exist yet. Writing it here would mean writing
   T25's doc before T09 (its other dependency) has decided anything.
   **Owner-approved 2026-10-05: it stays T25's**, and the T25 row now says so.

Nothing was deleted: the merged branches `feature/ui-polish-bars-snackbar` and
`feature/offline-first-launch`, and the closed `feature/splash-startup-latency`,
all still exist on `origin`, matching how every earlier merged branch was left.

**The Phase 0 PR is not opened yet** — per Q21 it opens once T03 (CI) is done.

### T03 record (2026-10-05)

**`.github/workflows/ci.yml`** — one workflow, two jobs that run in parallel:

| Job | Steps |
|---|---|
| **App (format, analyze, test)** | `flutter pub get`, then `dart format --output=none --set-exit-if-changed .`, `flutter analyze --no-fatal-infos`, `flutter test` |
| **Backend (deno test)** | `deno test --allow-env --allow-net supabase/tests` |

Triggers: **every pull request**, whatever its base, plus pushes to `main` and
`develop` so a bad interaction between two separately-green PRs is still caught
once no PR is open. `permissions: contents: read`, and `concurrency` cancels a
superseded run on the same branch.

**Every command was re-run locally at this commit and exits 0:** format clean,
analyze 16 infos / 0 errors, `flutter test` **2206 passed**, `deno test`
**734 passed, 42 ignored** (the ignored ones are the integration tests skipping
themselves — see below).

**Findings worth keeping, each measured rather than assumed:**

1. **`flutter analyze` exits 1 on infos alone.** Measured: with the project's 16
   known infos and no errors, the bare command returns 1, so the obvious
   workflow step would have failed on its first run. `--no-fatal-infos` returns
   0 while **errors and warnings still fail** (both are fatal by default). This
   matches the baseline the plan already treats as accepted (T02 handover). To
   make the gate stricter, the 16 infos — all in test files — have to be
   cleaned up first; that is a standalone decision, not T03's.
2. **No secrets are needed, by construction.** The unit tests use injected
   fakes; the integration tests under `supabase/tests/integration/` skip
   themselves when `SUPABASE_URL` / `SUPABASE_ANON_KEY` are absent and no local
   stack is up (`supabase/README.md` § Tests). `RUN_LIVE_ANALYSIS` is never set,
   so no CI run can spend provider quota.
3. **Versions are pinned** — Flutter `3.41.9` and Deno `2.9.4`, the versions the
   project is developed against. A new stable release therefore cannot change
   the gate's verdict mid-review; upgrading is a deliberate edit here. The
   pinned Flutter also pins `dart format`, which is what makes the formatting
   check reproducible at all.
4. **Actions are pinned to major tags**, not commit SHAs. Acceptable here
   because the workflow holds no secrets, has read-only permissions and
   produces no artifact. **This stops being true at T13**: a release-build
   workflow carries the signing key, and that one should pin by SHA.
5. **The mixed line endings do not break CI.** `core.autocrlf=false` and there
   is no `.gitattributes`, so a Linux runner checks out bytes identical to the
   working tree, and `dart format` preserves each file's existing endings.
   Introducing a `.gitattributes` would change this and must be done
   deliberately, with the formatting check re-verified.
6. **No `build_runner` step.** Drift's generated sources are committed
   (`app_database.g.dart` and the two DAOs), per CLAUDE.md §B3.
7. **Every bundled asset is committed**, including the two `tessdata`
   traineddata files (1.4 MB and 4.1 MB), so `flutter test` needs no extra
   fetch step.

**One thing CI cannot do yet, and one the owner should rule on:**

- **CI's first live run passed.** ~~Nothing triggers it on a feature branch~~ —
  resolved: PR #29 (opened 2026-10-05) triggered run `37277905375`, and both
  jobs went green first time: **App 5m10s** (checkout, Flutter 3.41.9 from
  cache, `pub get`, format, analyze, 2206 tests) and **Backend 16s**. The
  workflow needed no correction after being written, and the gate verdict in CI
  matched the local one exactly. One informational annotation, no action needed:
  GitHub will migrate the `ubuntu-latest` label to Ubuntu 26 from 2026-10-19.
- **`deno fmt --check` was deliberately left out**, and measuring why turned up
  something: it **fails today on 4 files**, entirely because of line endings
  (`Text differed by line endings`) — `analysis-provider.ts`,
  `openai-compatible-client.ts` and their two tests. `deno lint` is clean and
  could be added as-is. So the deferred line-ending cleanup now has a concrete
  cost: it is what blocks the backend's formatting check from joining the gate.
  Neither check is in T03's acceptance, so neither was added.

### T04 record (2026-10-05) — production state measured, three decisions owed

The Supabase **MCP connector is still not available in this session** (the two
Supabase MCP servers remain unauthorised here, and OAuth cannot run in a
non-interactive session — a session restart is likely what picks up a link made
in the claude.ai settings). But it turned out not to be needed: the **Supabase
CLI on this machine is already authenticated**, and the Postgres port that was
blocked on this network on 2026-09-06 (see `docs/TEST-BUILD-ROLLOUT.md`) is
**open again**, so production could be inspected directly over both HTTPS and
Postgres.

#### Production's live state (Q8) — measured, not assumed

| What | State |
|---|---|
| Project | `war2aty` / `jecujrsvbmashkpobtsz`, org `kejzeyfadlqnjhypvili`, **ACTIVE_HEALTHY**, Postgres 17.6 |
| **Region** | **`ap-northeast-2` — Seoul.** See the region problem below. |
| `health` | Responds `{"status":"ok"}` over HTTPS, no auth (`verify_jwt: false`) |
| Functions | All four ACTIVE: `analyze-document` v9 (updated **2026-09-26**), `get-usage` v8, `health` v8, `ocr-document` v6 (all three updated **2026-08-16**) |
| Migrations | **6 of 7 applied.** `20260929120000_online_ocr_flag.sql` — F20's — is **not applied** (`remote: ""`) |
| Secrets | 18 present, including `GEMINI_API_KEY`/`GEMINI_MODEL`, `MISTRAL_*`, `GROQ_*`, `INSTALLATION_HASH_SALT`, `DAILY_ANALYSIS_LIMIT`, `MAX_OCR_CHARACTERS`, `ANALYSIS_SCHEMA_VERSION`, `AI_TIMEOUT_SECONDS`. **No Azure or Google secrets** — consistent with F20-T16 deleting them. Missing versus `.env.example`: `AI_ATTEMPT_TIMEOUT_SECONDS`, `MIN_FALLBACK_MS` |

**This confirms B2 with dates rather than suspicion.** F20 completed on
2026-09-30 (`6eb705c`); every deployed function predates it — `ocr-document`,
the one F20 rewrote around Gemini, by six weeks. F20's migration was never
applied, so `online_ocr_enabled` does not exist in `app_runtime_config`.
Production is therefore pre-F20 on all three axes at once: code, schema and
config. T08 is where that is fixed; nothing here changed production.

**One gap left open deliberately.** The `app_runtime_config` row values
(`daily_limit`, `online_ocr_enabled`, the global cap, `minimum_app_version`)
are still unrecorded: reading them means a production data read, which this
session is not permitted to do — the table also holds pseudonymous
installation hashes. Q10 and Q12 both want those values. They need either the
owner's explicit permission for a production read or a look at the dashboard.

#### The region problem (the T04 "region decision", and it is bigger than T04 assumed)

**Production serves Egypt from Seoul.** Cairo→Seoul is roughly 8,500 km, about
230–280 ms round trip before any work is done; and every analysis is a chain of
Edge Function → AI provider calls, so the user pays that distance more than
once. The AI providers are US/EU-hosted, so Seoul is also the wrong side of the
world from them — which is T05's measurement, but the direction is not in doubt.

**A project's region cannot be changed.** The only fix is a new project. The
closest regions the CLI offers — there is no Middle East or Africa one — are
`eu-central-1` (Frankfurt), `eu-west-3` (Paris) and `eu-central-2` (Zurich);
Egypt's international transit runs through Europe via the Alexandria landings,
so any of them is roughly 60–80 ms. `ap-south-1` (Mumbai) is the next best at
roughly 110–130 ms. **Recommended: `eu-central-1`.**

**Now is the cheapest this will ever be.** The app has not launched: only
testers hold it, local documents live on the device, and the only server-side
state is usage counters and anonymous identities. After launch, moving means
resetting every user's anonymous identity and quota.

#### The three decisions T04 cannot make on its own

1. **Fix the region, or keep Seoul?** Recommended: create the new project in
   `eu-central-1` **as the new production**, and keep the existing Seoul project
   **as staging** — it already carries the migrations, functions and secrets a
   staging project needs, so this gets both deliverables from one move and
   wastes nothing.
2. **The free tier is full.** The org already holds **two** projects, which is
   the free plan's limit: production, and `Yusef3bdulkarim's Project`
   (`ernmfjskupxgopczarrx`, `ap-southeast-1`/Singapore, **INACTIVE** since
   2026-08-11) — a leftover. Whatever is decided in (1), that leftover should go
   first. **Deleting it needs the owner's say-so**, and a check that it holds
   nothing wanted.
3. **Which provider keys does staging use?** Under the no-paid-tiers rule
   ([[war2aty-no-paid-tiers-ever]]), pointing staging at production's Gemini /
   Mistral / Groq keys means staging traffic eats the same free quota the
   launched app depends on. Either separate free-tier keys for staging, or keep
   staging traffic deliberately tiny. This decides what goes into the staging
   project's secrets.

Creating a project is an account-level action with an irreversible region
choice, so **nothing was created**. `config/staging.json` waits on (1) and (2),
since it needs the new project's URL and publishable key.

#### What is ready to run the moment those are answered

`docs/TEST-BUILD-ROLLOUT.md` already records the sequence for standing up a
fresh project, and it still holds: `supabase projects create <name> --org-id
kejzeyfadlqnjhypvili --db-password <chosen> --region <chosen>`, then
`supabase link --project-ref <ref>`, `supabase db push` (now possible from this
machine again), `supabase functions deploy analyze-document ocr-document
get-usage health --project-ref <ref>`, then `supabase secrets set --env-file
supabase/.env --project-ref <ref>`, and finally set `online_ocr_enabled`
deliberately — **off at launch**, per Q12. The DB password is a secret: it goes
to the owner's password manager, never into the repo.

**No staging flavor exists.** `Flavor` is `{dev, prod}` and
`lib/core/env/app_environment.dart` says a staging flavor is deferred. None is
needed: `AppEnvironment.prod()` reads both values from dart-defines with no
defaults, so staging runs today as
`flutter run --flavor prod -t lib/main_prod.dart
--dart-define-from-file=config/staging.json`. The cost is that such a build
carries the production `applicationId`, so it replaces the real app on a device
rather than sitting beside it. A real `staging` flavor would fix that and is the
better long-term answer, but it needs Android product flavors, an iOS scheme
(unbuildable until there is a Mac, Q1/Q22) and an icon variant — so it is
proposed, not assumed.

### T04 record (continued) — 2026-10-05, the owner's four approvals carried out

The owner approved all four recommendations, including permission for the
production read. What follows is what was actually done, in order, and the three
things still owed.

#### 1. The runtime config, finally recorded (closes Q8, answers part of Q10)

The old production's `app_runtime_config` held:

| key | value |
|---|---|
| `analysis_enabled` | `true` |
| `daily_limit` | `3` (reverted from 10 on 2026-09-06) |
| `max_ocr_characters` | `12000` |
| `max_image_bytes` | `8000000` |
| `minimum_app_version` | `"1.0.0"` |
| `maintenance_message` | `null` |
| `schema_version` | `"2.0"` |
| **`azure_ocr_enabled`** | **`true`** |

That last row is the find. F20 replaced the key with `online_ocr_enabled`, and
F20-T16 deleted the Azure secrets — so production was carrying a stale,
**enabled** flag for a provider whose credentials no longer existed. That is the
HTTP 500 recorded in [[analysis-bugs-aug13]], still live. It also makes Q12's
"off at launch" the only safe setting, and it is gone now.

**Q10's open half is answered:** there is no `global_daily_call_cap` key, so no
global cap was ever set. `nullablePositiveInteger` reads its absence as "no
cap". T06 sets it.

**A disclosure.** The first dump used `--data-only` without `--schema public`,
so it also pulled the `auth` and `storage` schemas — 39 anonymous users with
their sessions and refresh tokens. No row content was read (only per-table row
counts, to see what had been exposed) and the file was deleted immediately. The
later reads used `-s public` with the three usage tables excluded, which returns
`app_runtime_config` and nothing else. **`-s public` is the right form; a bare
`--data-only` is not.** As a side effect the row count is a useful number: the
old project holds **39 anonymous identities**, i.e. testers only — which is what
made moving region cheap.

#### 2. The Singapore leftover — deleted

`ernmfjskupxgopczarrx` was checked first and was genuinely empty: **no functions,
no secrets**, never used since its creation on 2026-08-11. Deleted, freeing the
second of the free tier's two project slots.

#### 3. The new production — `war2aty-prod` in `eu-central-1`

| | |
|---|---|
| Ref | `ivbpmzasxpphclundjyy` |
| Region | **`eu-central-1`** (Frankfurt) — roughly 60–80 ms from Egypt, against 230–280 ms from Seoul |
| Status | ACTIVE_HEALTHY, Postgres 17 |
| Migrations | **All 7 applied** |
| Functions | All 4 deployed, `verify_jwt` correct from `config.toml` (true, true, true, `health` false) |
| Secrets | All 11 set from `supabase/.env`, giving the same 18 names the old project had |
| `health` | `{"status":"ok"}` |
| Runtime config | Identical to the old project's **except** `online_ocr_enabled: false` instead of `azure_ocr_enabled: true` — exactly Q12 |

The DB password was generated here (40 chars, URL-safe), never printed and never
committed. It is in this session's scratchpad at
`war2aty-prod-db-password.txt` and **must be moved to the owner's password
manager**, because the scratchpad is temporary. Losing it is recoverable — it can
be reset from the dashboard, and the CLI uses the access-token login role rather
than this password for `db push`.

#### 4. Staging — the old Seoul project, brought up to current code

`jecujrsvbmashkpobtsz` kept its data and identities and now runs **the same code
as production**: all 4 functions redeployed, and the one missing migration
(`20260929120000_online_ocr_flag`) applied, which deleted the stale
`azure_ocr_enabled` and seeded `online_ocr_enabled: false`. Functions were
deployed **before** the migration deliberately: F20's code reads the flag's
absence as off, so that order is safe in a way the reverse is not.

A side effect worth knowing: the APK on the owner's phone points at this
project, and its client code is post-F20. Until now it was talking to a pre-F20
backend. That mismatch is gone — their build now matches the server it reaches.

#### 5. Config files

`config/prod.json` now points at `ivbpmzasxpphclundjyy`; **`config/staging.json`
is new** and points at the Seoul project with its existing publishable key. Both
hold only a URL and a publishable key, which §24 permits in the client. No
staging *flavor* was added — `AppEnvironment.prod()` takes both values from
dart-defines, so staging runs as
`flutter run --flavor prod -t lib/main_prod.dart
--dart-define-from-file=config/staging.json`, at the cost of carrying the
production `applicationId`.

#### Three things still owed — two of them the owner's

1. **Enable anonymous sign-ins on `war2aty-prod`** — *blocking*. Verified
   disabled by attempting a real sign-in: HTTP 422,
   `anonymous_provider_disabled`. Anonymous Auth is the app's **only** identity,
   so until this switch is on, the new production cannot authenticate anyone.
   Dashboard → Authentication → Sign In / Providers → Anonymous sign-ins.
   `supabase config push` was considered and **rejected**: `config.toml` says in
   its own header that it configures the local stack only, and pushing it would
   also send `site_url = "http://127.0.0.1:3000"` and disable storage, realtime
   and analytics on the hosted project.
2. **Rename the Seoul project to `war2aty-staging`** — cosmetic but worth doing,
   since it is still called `war2aty`. The CLI has no rename; it is a dashboard
   edit.
3. **Separate free-tier provider keys for staging** (the owner's decision 3).
   Staging still holds the production Gemini / Mistral / Groq keys, because new
   free-tier accounts can only be created by the owner. They were left in place
   rather than removed, so staging stays functional and nothing regressed — but
   **until they are replaced, any analysis run against staging spends the same
   free quota production depends on**, so staging should not be exercised yet.

Nothing here touched T05's job: whether the providers are actually reachable
from the Frankfurt runtime, and the function-region pin, are measured there —
and the move to Frankfurt should help, since the providers are US/EU-hosted.
