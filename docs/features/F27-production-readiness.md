# F27 · Production readiness

- **Branch:** `feature/production-readiness`, to be cut from `develop` (not created yet) · **Milestone:** M9 (launch)
- **Depends on:** all shipped features (F00–F26) · **Supersedes:** the open F12 tasks (T03–T12), once the owner confirms Q7
- **Progress:** 2 / 28 DONE (2 initial steps + 26 tasks) · **Plan LOCKED 2026-10-04, amended the same day with the initial steps P01–P02.** P01 and P02 done and committed 2026-10-05; T01 is next and needs the owner's answers to the open questions.

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
| H6 | No CI (`.github/workflows` doesn't exist). The gate and release builds run by hand on one machine. | T03 |
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

## Open questions (answer before the task they gate)

Q2 (Play account type) and Q16 (app name) are resolved by locked decisions #1 and
#2. The rest are still open.

| Q | Question | Gates |
|---|---|---|
| Q1 | Launch platforms: Android only first, or Android and iOS together? For iOS: a Mac and an Apple Developer membership? (Store fees read as outside the free-tier rule. Confirm.) | T23, T24 |
| Q3 | Target launch date, and expected users or analyses per day? | T06, T09 |
| Q4 | Egypt-only store availability? | T21 |
| Q5 | Which open PRs go into the launch build: #18 (offline-first launch), #19 (splash latency), #28 (F26)? | T02 |
| Q6 | Does the English UI ship (needs the LTR audit) or is it Arabic only? | T15 |
| Q7 | Does F27 take over F12-T03 to T12, with F12 closed as superseded? | T01 |
| Q8 | What's deployed in production now (pre-F20 or F20, which secrets)? Authorising the Supabase MCP lets me check. | T04, T08 |
| Q9 | Create a second free project for staging? Move production out of Seoul (depends on T05)? | T04 |
| Q10 | Is `global_daily_call_cap` set in production? Is CAPTCHA (Cloudflare Turnstile, free) or attestation (Play Integrity / App Attest) on anonymous sign-in acceptable? | T06 |
| Q11 | How long to keep `analysis_attempts` rows and idle anonymous users? | T07 |
| Q12 | `online_ocr_enabled` on at launch, or flipped later? | T08, T26 |
| Q13 | Crash and error reporting: (a) our own Supabase table plus an Edge Function that only accepts allowed error codes (recommended); (b) Sentry free tier with scrubbing; (c) none? | T12 |
| Q14 | Is the release keystore and its passwords backed up somewhere other than this machine? Has it signed anything already distributed? Enroll in Play App Signing (recommended)? | T13, T21 |
| Q15 | Keep the package IDs `com.war2aty.app` / `.dev`, or change them with the rebrand? This is final after the first Play upload. | T13, T21 |
| Q16 | Final app name (and any English name). **Owner supplies it before T14** (decision #2). | T14 |
| Q17 | Developer of record (person or company), support email, and is GitHub Pages OK for hosting the policy pages? | T20 |
| Q18 | A terms-of-use page with a "not legal/medical/financial advice" disclaimer? | T20 |
| Q19 | Store graphics (screenshots, feature graphic): from the Waraqti design project, or to be designed? | T21 |
| Q20 | Android backup: off completely (recommended), or settings-only? | T11 |
| Q21 | PR timing for F27: per phase, or one at the end? | all |
| Q22 | Which test phones are available (known: RMX2001, ELS NX9)? Is an iPhone available? | T18, T23 |

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
| 1 | F27-T01 | Lock the answers | Every open question answered here; F12 marked superseded (if Q7 = yes); the features index lists F27 (the branch already exists from P01) | P02 | TODO |
| 2 | F27-T02 | Repo cleanup and release branching | PRs #18, #19 and #28 merged or closed per Q5; `main` and `develop` back in line; release-branch and tag scheme written in T25's doc | T01 | TODO |
| 3 | F27-T03 | CI (GitHub Actions, free for public repos) | Every PR runs `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`, and `deno test` for `supabase/`; no secrets in CI | T02 | TODO |

### Phase 1: Backend
| # | ID | Task | Output / acceptance | Depends on | Status |
|---|---|---|---|---|---|
| 4 | F27-T04 | Staging project and region decision (owner) | Production's live state recorded (Q8); a free staging project with all migrations and functions; `config/staging.json`; a region decision written down | T01 | TODO |
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
| 14 | F27-T14 | Branding: new app name | Applies the name part of decision #2's inventory: `appName` placeholders (dev + prod), iOS `CFBundleDisplayName` / `CFBundleName`, any brand name in `AppStrings` (ar + en) and the Flutter splash or onboarding, `app_strings_test`, README. Also anything P01 left for later. (The icon and splash are done in P01.) | **Owner's final name** (decision #2), P01 | BLOCKED |

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
| 25 | F27-T25 | Release process document | `docs/RELEASE.md`: versioning (next build number above `+2`), changelog, tagging, `minimum_app_version` policy, rollback with the kill switches | T02, T09 | TODO |
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
