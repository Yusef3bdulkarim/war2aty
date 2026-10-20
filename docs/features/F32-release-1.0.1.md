# F32 · Release `1.0.1+2` — the first update to a published app

- **Branch:** PR #34 merges to `develop` first, then `release/1.0.1` cut from
  `develop` · **Milestone:** post-F31
- **Depends on:** F30 (reading aloud), F31 (the voice sample), PR #34 (the
  camera fixes), F27-T19 (`tool/check_play_compliance.dart`), F27-T13
  (`tool/build_release.ps1`)
- **Progress:** 6 / 16
- **PR:** one PR from `release/1.0.1` into `develop` at the end, then
  `develop` → `main`, then the tag

`1.0.0+1` has been **live on Google Play Production since 2026-10-11**. This
is the first time this project ships an *update* rather than a first upload,
and that changes the rules in one way that governs everything below: a
published versionCode can never be reused, and a 100% rollout cannot be
halted — only superseded. A bad build means shipping `+3`, not pulling `+2`
back.

## What is in the release

Forty-three commits since the published bundle, in three pieces.

**F30 — reading aloud (22 tasks, PR #32).** Three faults reported from three
physical phones turned out to have six distinct root causes. The worst:
a phone with no Arabic voice installed (Samsung TTS ships none in many
regions) was read to in an **English** voice with nothing said about it,
which is why «الخلاصة» appeared to "read only the English letters" — the
Arabic was being spoken by a voice that cannot pronounce it. Also fixed:
English inside an Arabic paper read letter-by-letter, a 1–3 s delay before
the first word, amounts above ten thousand killing the reading outright, one
unexplained error message standing in for every distinct engine failure, and
readings long enough for the engine to refuse.

**F31 — the voice sample (4 tasks, PR #33),** plus the owner's 2026-10-20
decision to shorten the sample back to a greeting (T04 below).

**PR #34 — the camera.** Two bugs from device use. On a fresh install, granting
the camera permission landed the user on an error screen: the permission gate
treated the system prompt's own resume as a return from Settings and read a
grant the OS had not finished committing, while the viewfinder opened three
overlapping camera sessions in the same lifecycle transition. Separately, the
camera stayed open and streaming behind the crop, the OCR, the review and the
result screens, because `didPushNext` was never handled.

**Why `1.0.1` and not `1.1.0`:** every item is a fix to behaviour that already
shipped. The only new thing a user can see is a stop control on a settings row.

## Locked decisions

Taken with the owner on 2026-10-20.

1. **Version `1.0.1+2`.** `+2` is forced — Play refuses any build number not
   above the published `+1`.
2. **The release contains everything**, PR #34 included. The owner ran the
   device pass and reported all paths working; corroborated here by
   `build/app/outputs/apk/prod/release/app-prod-release.apk`, built
   **2026-10-19**, a day after the camera commits, `com.war2aty.app`,
   versionCode 1, targetSdk 36.
3. **The release-branch and tag scheme is defined by being used** (this is
   F27-T25's outstanding deliverable). `release/1.0.1` off `develop`; one PR
   back into `develop`; `develop` → `main`; tag `v1.0.1+2` on `main`.
4. **CI moves to Flutter 3.47.7** (T07, option A). See "The Flutter split".
5. **M6 is deferred** — plainly, with no partial run folded into T13. See
   "Deferred, and why".

## The Flutter split — why T07 is not housekeeping

CI pins **3.41.9**; the machine that builds the uploaded artefact runs
**3.47.7**. Flutter is not only a build tool: the engine, the Dart compiler's
output and the Android glue all ship *inside* the APK. So "2,898 tests green"
on CI is a statement about an app that is not the one being uploaded.

The upgrade has already left two marks:

- `android/gradle.properties` carries two lines **Flutter's migrator wrote by
  itself** (`android.builtInKotlin=false`, `android.newDsl=false`). The
  migrator only runs when a newer SDK meets a project built by an older one.
- `assembleProdRelease` died on 2026-10-19 with `OutOfMemoryError: Metaspace`
  inside the Kotlin FIR compiler — a failure mode this project had never seen,
  from a new compiler sharing one JVM under `kotlin.compiler.execution.strategy=in-process`.

`targetSdk` is **36 under both**, so the number Play checks directly has not
moved. What moved is the engine and the plugin binaries — precisely the class
of change `tool/check_play_compliance.dart` was built for (F27-T19: more than
half of what Play enforces here lives in prebuilt binaries this project does
not own, and `flutter test` cannot see any of it).

Option B — downgrading the machine to 3.41.9 — was rejected because it would
discard the owner's device verification, which was performed on a 3.47.7
build.

### What 3.47.7 does to the analyzer — found 2026-10-20, during T04

Raising the pin is not a one-line change. CI runs
`flutter analyze --no-fatal-infos`, which tolerates infos but still fails on
warnings. On 3.47.7 that command **exits 1**, because a lint new to the newer
SDK, `unawaited_return_in_try_block`, fires twice in `lib/`:

- `lib/core/documents/file_document_image_store.dart:61`
- `lib/features/bootstrap/data/repositories/supabase_auth_repository.dart:75`

Neither is reachable by CI today — 3.41.9 does not have the lint — and neither
came from this release's commits. The info count also drifted from the 16 the
CI comment calls the accepted baseline (F27-T02) to 19.

So **T07 cannot go green by editing the pin alone**: those two warnings have to
be fixed, or the gate loosened, and loosening it would hide the next real
warning. The F27-T19 argument applies unchanged here — the upgrade's effects
show up in places `flutter test` cannot see.

`flutter test` itself is unaffected: all **2,898 tests pass** on 3.47.7
(verified during T04).

## The ordering constraint that is not negotiable

**T10 (the `report-error` deploy) must land before T14 (the upload).**

F30-T08 added eight TTS error codes to the Edge Function's allowlist, and
F27-T20 added `EXTERNAL_LINK` before it. The allowlist is a closed vocabulary
by design, and a report carrying an unknown code is refused with a 400 that
the client's sink swallows **silently** — that is the design, so that a
failing error reporter can never become a user-visible failure. Upload first
and the consequence is exact: the one release whose headline is "every reading
failure is now reported by cause" would report none of them, through the first
72 hours, with nothing anywhere saying so.

## Tasks

### Phase 0 · Clear the desk

| # | ID | Task | Status |
|---|---|---|---|
| 1 | F32-T01 | Park the uncommitted F31 copy change off `fix/camera-permission-and-lifecycle` — it belongs to neither that branch nor its reviewed PR | DONE |
| 2 | F32-T02 | Drop the redundant `analysis_options.yaml` stash — superseded by `af0af3e` (F30-T12), which added the same three excludes in quoted form. Dropped as `stash@{1}` (`e086f19`); T01's park is the only stash left, at `stash@{0}` | DONE |
| 3 | F32-T03 | Merge PR #34 into `develop`; record the owner's device pass in the PR before it closes | DONE |

### Phase 1 · The release branch

| # | ID | Task | Status |
|---|---|---|---|
| 4 | F32-T04 | Cut `release/1.0.1`; land the shortened voice sample (3 string files + the F31 doc note); gate | DONE |
| 5 | F32-T05 | Commit `android/gradle.properties` — metaspace 1G and the two migrator flags, with the 2026-10-19 failure recorded in the header | DONE |
| 6 | F32-T06 | `pubspec.yaml` → `1.0.1+2` | DONE |
| 7 | F32-T07 | Raise the CI Flutter pin to 3.47.7 and **prove CI green on it** before any further work — **blocked: two new warnings fail the gate, see "What 3.47.7 does to the analyzer"** | TODO |
| 8 | F32-T08 | `docs/RELEASE.md` — F27-T25: versioning, tags, changelog, `minimum_app_version` policy, rollback via the kill switches, and the `develop` → `main` merge | TODO |
| 9 | F32-T09 | Play "What's new" in Egyptian Arabic, under §7 (no provider named, no claim about who sees the image or the text) | TODO |

### Phase 2 · Backend

| # | ID | Task | Status |
|---|---|---|---|
| 10 | F32-T10 | Deploy `report-error` to production (8 TTS codes + `EXTERNAL_LINK`); apply the pending `20261010120000` migration; verify both live | TODO |

### Phase 3 · Build and verify

| # | ID | Task | Status |
|---|---|---|---|
| 11 | F32-T11 | `./tool/build_release.ps1 -Artifact aab`; copy the symbols aside **immediately** (building an APK afterwards overwrites the bundle's arm64 symbols in the shared version-keyed directory — F27-T19's trap, which has bitten once already) | TODO |
| 12 | F32-T12 | Run **both halves** of `check_play_compliance.dart` — the bundle, and an APK from the same commit for the merged-manifest half | TODO |
| 13 | F32-T13 | Device pass on the RMX2001 from the same build: reading aloud in every mode, the voice sample and its stop, the camera from a clean install, and the Gemini online path | TODO |

**An early APK exists, built 2026-10-20 at `3413bcd` for a device test on a
second phone** — `-Artifact apk -Flavor prod -Arm64Only`, `com.war2aty.app`,
versionCode 2, versionName 1.0.1, targetSdk 36, `arm64-v8a` only, signed
`CN=Yusef Abdulkarim, O=War2aty, L=Cairo, C=EG`. It is **not** T11's artefact
and **not** the one T12 reads for the merged-manifest half — that APK must come
from the same commit as the bundle. Its symbols were copied to
`build/symbols/1.0.1+2-apk-arm64-devicetest/` straight away, because T11's
bundle build writes over `build/symbols/1.0.1+2/`, and without them a crash
report from that phone cannot be deobfuscated.

**T05's metaspace fix is proven:** `assembleProdRelease` completed, where it
died of `OutOfMemoryError: Metaspace` on 2026-10-19.

**A trap when running `build_release.ps1` from an agent shell:** do not pipe it
as `*>&1 | Tee-Object`. PowerShell 5.1 wraps a native command's stderr in
`NativeCommandError`, and the script sets `$ErrorActionPreference = 'Stop'`, so
flutter's harmless "upgrade your Gradle version" warning becomes a terminating
error. The build itself finishes and the artefact is written, but the script
dies before printing its "Built:" summary and its symbols listing — so it looks
like a failed build that actually succeeded. Run it without merging stderr.

### Phase 4 · Ship

| # | ID | Task | Status |
|---|---|---|---|
| 14 | F32-T14 | **(owner)** Upload to Play Production, 100% rollout, with T09's notes | TODO |
| 15 | F32-T15 | PR `release/1.0.1` → `develop`; merge `develop` → `main` (265 commits behind); tag `v1.0.1+2` | TODO |
| 16 | F32-T16 | 72-hour watch: Gemini's quota **by hand** (nothing counts OCR calls), the `error_reports` table, Play vitals and reviews | TODO |

## Deferred, and why

**M6 — reminders under OEM battery savers.** Deferred by the owner on
2026-10-20, to be its own feature after this release.

The substance: reminders are scheduled `inexactAllowWhileIdle` by decision
(F09-T10), because `SCHEDULE_EXACT_ALARM` is reserved by Play for alarm-clock
apps and asking for it without grounds risks the listing. Minutes of slip are
fine for a day-scale reminder. What is not known is whether the OEM battery
managers on realme/ColorOS, MIUI, EMUI and One UI **drop the alarm entirely** —
the distinction is late versus never, and nobody has watched a single reminder
arrive on a phone with one of those managers switched on. It has been deferred
twice already (F25 → F27-T18 → here), and the matrix is ready: E1–E14 in
`F27-T18-device-pass.md`.

The reason this is uncomfortable rather than routine: the owner's own phone is
a realme, and the Egyptian market is overwhelmingly realme, Oppo, Xiaomi and
Samsung. If alarms are being dropped, a core promise of the app is broken for
most of its users. It is deferred on the grounds that it is **already** broken
in the published version if it is broken at all, so holding finished fixes
behind an open-ended investigation helps nobody — not on the grounds that it
is minor.

A middle option was offered and declined: folding E4–E7 into T13 for about
half an hour on the owner's own phone.

**Also carried forward, unchanged:** the device performance profile
(F12-T05 with F22-T09 folded in), the `base-config` that would refuse
cleartext on API 24–27, Gemini's uncounted 500/day quota (owner's accepted
risk, F27-T06), and iOS (F27-T23/T24, blocked on having no Mac).
