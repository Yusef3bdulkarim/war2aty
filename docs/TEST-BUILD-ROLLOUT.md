# Multi-Phone Test Build Rollout

One-off ops task, not a numbered product feature — not part of the `docs/features/`
index or the F12 hardening pass. Goal: get an installable Android build of the
current `feature/settings` work (F11 settings + F14 online OCR review flow) onto
several physical test phones.

**To resume any task below in a fresh chat:** open a new chat and say
`Read docs/TEST-BUILD-ROLLOUT.md, let's work on Task <N>`. Each task section is
self-contained — it lists exactly what it needs from the others and where to find
it, so the new chat doesn't need this conversation's history.

## Locked decisions
- **Backend:** hosted Supabase **staging** project (not local Docker/LAN) — testers
  are not all guaranteed to be on the dev machine's Wi-Fi.
- **Platforms:** Android only for this round. iOS (Apple dev account, UDID
  provisioning/TestFlight) is out of scope until asked for.
- **Code state:** finish and merge PR #9 (`feature/settings` → `develop`) first;
  the test build is cut from `develop`, not the WIP branch.

## Status legend
`TODO` · `WIP` · `DONE` · `BLOCKED`

## Tasks

| # | Task | Depends on | Status |
|---|---|---|---|
| 1 | Finish & merge PR #9 into `develop` | — | DONE |
| 2 | Stand up hosted Supabase staging project | — | DONE |
| 3 | Android test build & distribution | Task 1 + Task 2 outputs | DONE |

---

## Task 1 — Finish & merge PR #9 into `develop`

**Depends on:** nothing — can start immediately, in parallel with Task 2.
**Produces:**
- `develop` commit SHA the test build should be cut from: `e41873d`
  (merge commit `merge: settings F11 + OCR review F14 + DST/quota/capture
  fixes (PR #9) into develop`; post-merge `flutter test` green, 1628/1628)

**Steps:**
1. ✅ Organized the ~50 uncommitted files into 3 commits on `feature/settings`,
   pushed, PR #9 updated:
   - `a34b6cc` fix(time): Africa/Cairo via DST-aware IANA zone (not fixed UTC+2)
   - `961a6e9` fix(usage): sync daily quota after successful analysis
   - `38de137` feat(settings): audio & reading defaults — rate/voice/resume [F11-T07]
   - Along the way: found + fixed 2 real regressions the WIP introduced
     (Cairo-DST test fixtures using stale UTC+2 arithmetic; 3 note-section
     tests in `document_details_screen_test.dart` tapping buttons pushed
     off-screen by the new pinned action bar — fixed with `ensureVisible`).
     Full suite: 1628 tests, green, before push.
2. ✅ `dart format .`, `flutter analyze`, `flutter test` — all clean.
3. ✅ Self-review via `/flutter-review` — passed (see PR #9 discussion).
   Note: `@code-reviewer`'s independent deeper pass was intentionally skipped
   for this merge per explicit user instruction, not run.
4. ✅ `@git-expert` merged PR #9 into `develop` (real merge commit, per repo
   convention — not squashed). `feature/settings` kept on remote, matching
   this repo's precedent of not deleting merged feature branches.
5. `docs/features/F11-settings-privacy.md` F11-T07 already marked DONE as
   part of the `feat(settings)` commit.
6. ✅ Done — SHA filled in above.

---

## Task 2 — Stand up hosted Supabase staging project

**Depends on:** nothing — can start immediately, in parallel with Task 1.
**Surprise finding:** a hosted project already existed — created 2026-08-11
during F13-T19's real end-to-end verification (not something this task had to
build from scratch). The "no hosted project yet" comment in
`lib/core/env/app_environment.dart`/`main_prod.dart` is stale; worth fixing in
a follow-up, out of scope here.

**Produces:**
- Project name/ref: `war2aty` / `jecujrsvbmashkpobtsz` (org `kejzeyfadlqnjhypvili`)
- `SUPABASE_URL`: `https://jecujrsvbmashkpobtsz.supabase.co`
- `SUPABASE_ANON_KEY` (publishable — safe to embed, per §24): `sb_publishable_hyeP33fdPhgUynCC7SFVBQ_msx0FR4g`
- `azure_ocr_enabled`: already `true` (set 2026-08-11 during T19, backed by real
  Azure/Google creds already in the project's secrets — verified, not just
  assumed). No change needed; the F14 online-OCR flow this round is testing
  will actually exercise it.
- `DAILY_ANALYSIS_LIMIT`: raised from 3 → **10** for this test round (revert
  after testing wraps — it's the `daily_limit` row in `app_runtime_config`).

**What was actually done this session** (link + migrations + most secrets
already existed from 2026-08-11/13 — verified, not redone):
1. Confirmed link (`supabase/.temp/linked-project.json` → this project).
2. Verified all 6 migrations applied and all secrets present — direct
   `supabase migration list`/`db push` fails on this network (Postgres port
   blocked, not a project problem — `functions/health` responds fine over
   HTTPS), so verified via `app_runtime_config` already containing populated
   rows (`schema_version: "2.0"`, etc.) instead.
3. Deployed the one missing function, `ocr-document` (the other three existed
   but were 3-5 days stale).
4. Redeployed all 4 functions from current `develop` HEAD to pick up backend
   changes merged since the 08-11 deploy (schema v2, `IMAGE_PROCESSING` race
   fix, Groq `reasoningEffort`, `azureOcrEnabled` gating fix) —
   `get-usage`/`health` had real changes and redeployed; `analyze-document`/
   `ocr-document` bundle-hashed identical to already-current, no-op.
5. Raised `daily_limit` 3 → 10 via the REST API (service-role, HTTPS — same
   reason CLI DB commands don't work here) for this test round.

If a *fresh* staging project is ever needed instead (this one no longer fits,
or a true prod project is wanted later), the steps are: create it, `supabase
link --project-ref <ref>`, `supabase db push`, `supabase functions deploy
analyze-document ocr-document get-usage health --project-ref <ref>`, fill
`supabase/.env` from `.env.example` and `supabase secrets set --env-file
supabase/.env --project-ref <ref>`, then set `azure_ocr_enabled` deliberately.

---

## Task 3 — Android test build & distribution

**Depends on:** Task 1's commit SHA and Task 2's `SUPABASE_URL`/`SUPABASE_ANON_KEY`
— fetch both from this file before starting; if either is still `___`, this task
isn't unblocked yet.

**Steps:**
1. ✅ Already on `develop` at `e41873d` (Task 1's SHA) when this ran — no
   checkout needed.
2. ✅ `pubspec.yaml` bumped `1.0.0+1` → `1.0.0+2`.
3. ✅ `config/staging.json` created (untracked so far — see note below) with
   Task 2's `SUPABASE_URL`/`SUPABASE_ANON_KEY`.
4. First attempt with the plain `flutter build apk --flavor prod --release ...`
   command **failed**: `NoSuchFileException` on
   `stripped_native_libs\prodRelease\...\x86_64\libapp.so` — a stale/corrupted
   incremental build, not a real code problem. Fixed by `flutter clean` +
   rebuilding with `--target-platform android-arm64` (physical test phones are
   arm64-v8a; no reason to build/ship x86_64 in this APK anyway). Second build
   succeeded:
   `flutter build apk --flavor prod --release --target-platform android-arm64 -t lib/main_prod.dart --dart-define-from-file=config/staging.json`
   → `build/app/outputs/flutter-apk/app-prod-release.apk` (50.5MB), confirmed
   on disk. Release still signs with the debug key (`TODO` left in
   `android/app/build.gradle.kts`) — fine for ad-hoc internal testing, not for
   Play Store.
5. **Not yet done — needs you:** actually share the APK file with testers
   (Drive/USB/etc.; no Firebase App Distribution per the no-Firebase rule).
   Testers need "install from unknown sources" enabled. The file is sitting
   at the path above on this machine — I can't hand it to anyone outside this
   environment myself.
6. Daily-cap behavior for testers: 10 successful analyses per install per
   Africa/Cairo day (raised from 3 in Task 2 for this test round — revert to 3
   after); a fresh install resets it via a new anonymous identity.

**Loose end:** `config/staging.json` and `pubspec.yaml`'s version bump are
uncommitted on `develop` right now. `config/staging.json` only holds a URL +
publishable key (safe to commit, same as `config/dev.usb.json`) — worth a
small commit + push before this branch drifts, but not done automatically
here since committing/pushing wasn't asked for in this task.
