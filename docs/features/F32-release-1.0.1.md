# F32 · Release `1.0.1+2` — the first update to a published app

- **Branch:** PR #34 merges to `develop` first, then `release/1.0.1` cut from
  `develop` · **Milestone:** post-F31
- **Depends on:** F30 (reading aloud), F31 (the voice sample), PR #34 (the
  camera fixes), F27-T19 (`tool/check_play_compliance.dart`), F27-T13
  (`tool/build_release.ps1`)
- **Progress:** 12 / 16
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

**Resolved in T07.** Both warnings were fixed in `0b99afc`, and
`FileDocumentImageStore.load` turned out to be a real defect rather than a
lint: it returned the decrypt future without awaiting it, so the future left
the `try` before completing and a throwing encryptor reached the caller as an
unhandled exception instead of an `AppFailure` — the one thing §5 exists to
prevent. Verified to reproduce (remove the `await` and the new test fails with
`FormatException` escaping through `load`), and `load` had no test group at all
before. The auth site is a latent fix with no reproducing test, stated as such:
`signInAnonymously` is total today.

CI is green on 3.47.7 at `8a0f2a3`, run 39353477134 — format 0 changed,
19 infos, **2,901 tests passed**, backend green. The pin took effect
(`FLUTTER_ROOT: .../stable-3.47.7-x64/flutter`), the 3.47.7 formatter changed
nothing, and the 19 infos agree across CI, the owner's machine and this one.

The baseline is **not** "all in test files", as both the old 16-info comment and
its first replacement claimed: it is 15 in `test/` and 4 in `lib/`, now named in
`ci.yml` (`8a0f2a3`). One has a deadline — `expandable_panel.dart:162` uses
`axisAlignment`, deprecated after v3.41.0-1.0.pre in favour of `alignment`, so
it is an info now and a compile error whenever Flutter removes the member.

Also still outstanding from the build, not blocking: `flutter build` warns that
support for this project's Gradle 8.14.0 will be dropped in favour of 9.1.0+.

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
| 7 | F32-T07 | Raise the CI Flutter pin to 3.47.7 and **prove CI green on it** before any further work | DONE |
| 8 | F32-T08 | `docs/RELEASE.md` — F27-T25: versioning, tags, changelog, `minimum_app_version` policy, rollback via the kill switches, and the `develop` → `main` merge | DONE |
| 9 | F32-T09 | Play "What's new" in Egyptian Arabic, under §7 (no provider named, no claim about who sees the image or the text) | DONE |

### Phase 2 · Backend

| # | ID | Task | Status |
|---|---|---|---|
| 10 | F32-T10 | Deploy `report-error` to production (nine TTS codes, not eight; `EXTERNAL_LINK` and the `20261010120000` migration were **already live**); verify | DONE |

### Phase 3 · Build and verify

| # | ID | Task | Status |
|---|---|---|---|
| 11 | F32-T11 | `./tool/build_release.ps1 -Artifact aab`; copy the symbols aside **immediately** (building an APK afterwards overwrites the bundle's arm64 symbols in the shared version-keyed directory — F27-T19's trap, which has bitten once already) | DONE |
| 12 | F32-T12 | Run **both halves** of `check_play_compliance.dart` — the bundle, and an APK from the same commit for the merged-manifest half | DONE |
| 13 | F32-T13 | Device pass on the RMX2001 from the same build: reading aloud in every mode, the voice sample and its stop, the camera from a clean install, and the Gemini online path | TODO |

### T11 / T12 record — 2026-10-20, at `02b4b0d`

**The bundle** — `build/app/outputs/bundle/prodRelease/app-prod-release.aab`,
82,660,042 bytes (78.8 MB), `jar verified.` against
`CN=Yusef Abdulkarim, O=War2aty, L=Cairo, C=EG`, the same key the APKs carry.
`bundleProdRelease` took 199 s and did not come near the metaspace ceiling
T05 raised.

**The bundle grew: 66.0 MB at F27-T19 → 78.8 MB here**, about 19%, with no
dependency added in between. The likeliest cause is the 3.47.7 engine, the same
upgrade that moved the analyzer and the Kotlin compiler. Not a blocker — Play
splits per device, so no user downloads this figure — but it is a real
consequence of the toolchain move and the number to compare against next time.

**Symbols**: all three ABIs copied to `build/symbols/1.0.1+2-aab-bundle/`
before anything else ran.

**What the trap actually does, now measured.** The full-ABI APK built from the
same commit wrote arm64 symbols **byte-identical** to the bundle's
(`f371a0f9…`, 5,333,560 bytes both), so *this* overwrite cost nothing. The
earlier **arm64-only** device-test APK is the one that differs
(`48a885b0…`, 5,333,552 bytes). So the hazard is not "an APK after a bundle" in
general — it is an APK built with *different flags*, and `-Arm64Only` is exactly
that. Copying aside first remains right, because the directory is keyed by
version alone and nothing in it records which flags produced it.

**Both compliance halves passed**, `✓ every check passed` and exit 0 each:

| Half | What it proved |
|---|---|
| Bundle | Every 64-bit `.so` (arm64-v8a, x86_64) aligned ≥ 16 KB; `libflutter.so` and `libapp.so` at 64 KB. `BundleConfig.pb`: `uncompressNativeLibraries.enabled = true`, `pageAlignment = PAGE_ALIGNMENT_16K`. The manifest section reports itself **skipped** — `aapt2` cannot read an `.aab`, which is the whole reason the APK half exists. |
| APK (same commit) | `targetSdkVersion = 36`, `debuggable = false`, `extractNativeLibs = false`, and all **8** permissions matched the justified allowlist — including the three contributed by plugins rather than by this project's manifest (`ACCESS_NETWORK_STATE` from connectivity_plus, `VIBRATE` from flutter_local_notifications, and androidx.core's signature-level `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`). Unchanged from F27-T19's review, so the 3.47.7 plugin set contributed nothing new. |

That last column is the point of F27-T19 holding: more than half of what Play
enforces here lives in prebuilt binaries this project does not own, and a
toolchain move is precisely when it could have changed. It did not.

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

## T09 · Play "What's new" — the approved copy

**Option C, approved by the owner 2026-10-20.** Three options were drafted; C
is the prose one, chosen as the easiest to read aloud. Note it does **not**
mention the camera fix — only option B had room for it, and the owner took C
anyway.

Play's release-notes field is **500 characters per language**, which is tighter
than it looks: the first two drafts came in at 710 and 645 and had to be cut.
Both texts below are under it. Neither names a provider, and neither says
anything about who can see the image or the text (§7).

**Release → Production → create release → Release notes → Arabic (الافتراضي)**
(475 characters):

```
بقينا نقرالك الورقة أحسن.

لو موبايلك مفيهوش صوت عربي، بنقولك ونفتحلك الإعدادات تضيفه — قبل كده كان بيقرا بالإنجليزي من غير ما يقولك. والكلام الإنجليزي جوه الورقة بقى يتقرا كلام، والقراءة تبدأ أسرع، والمبالغ والمواعيد تتقرا صح.

وكمان زرار يوقّف «تجربة الصوت».
```

**→ Release notes → English (United States)** (386 characters) — the listing
has an English translation (F27-T21 §3), so leaving this blank would show the
Arabic to an English-locale user:

```
We read your paper out to you better now.

If your phone has no Arabic voice installed, we tell you and open the settings so you can add it — before, it read in an English voice without saying so. English words inside the paper are now read as words, reading starts faster, and amounts and dates are read correctly.

We also added a button to stop the voice sample whenever you like.
```

Every claim was checked against the shipped behaviour rather than the task
list: the no-Arabic-voice screen exists with «الموبايل مفيهوش صوت عربي» and an
«افتح إعدادات الموبايل» action (F30-T07); the faster start is the engine warm-up
(F30-T06); amounts and times come from F30-T02/T21/T22; reading English inside
an Arabic paper as words is F30-T10/T11/T17; and the stop control is F31.

## T10 · what was actually missing, and what was already done

Two of T10's three parts were **already true before the task ran**, and finding
that out took one `migration list` and one `functions download`:

| Part | State found 2026-10-20 |
|---|---|
| Apply migration `20261010120000` | **Already applied** to production. Every local migration had a matching remote entry; nothing was pending. |
| `EXTERNAL_LINK` in the allowlist | **Already live.** |
| The TTS codes | **Missing** — production held only the legacy `TTS`. |

The deployed function was dated **2026-10-18**, a day *after* the codes landed
locally on 10-17, so the timestamps said it was fine. It was not: it had been
deployed from a tree without F30. The row says "8 TTS codes"; there are **nine**
— `TTS_NO_ARABIC_VOICE`, `TTS_NOT_INSTALLED_YET`, `TTS_NETWORK`,
`TTS_NETWORK_TIMEOUT`, `TTS_SYNTHESIS`, `TTS_SERVICE`, `TTS_OUTPUT`,
`TTS_INVALID_REQUEST`, `TTS_UNKNOWN`.

That is this release's ordering constraint confirmed with evidence rather than
reasoning: had the upload gone first, every TTS failure report would have been
refused with a 400 the client's sink swallows silently by design.

**Deployed** on the owner's authorization: `supabase functions deploy
report-error` → production `ivbpmzasxpphclundjyy`, **version 2 → 3**. Verified
by downloading the live source back: all nine codes present, `EXTERNAL_LINK`
present, and **no drift at all** from the committed source — the deployed
function is byte-for-byte the code on this branch.

No access had to be granted for any of this. The Supabase CLI on the owner's
machine (2.109.1) is already authenticated and linked to production; it is the
MCP connector that is unauthorized, and it was not needed.

**Not done:** an end-to-end probe. Confirming the allowlist from the live source
is read-only; sending a real report carrying a TTS code would write a synthetic
row into production's `error_reports`, and that was not authorized. The first
genuine confirmation will be a real report from a real phone — T16's watch.

## What T08 turned up: the version gate cannot see `+2`

Writing `docs/RELEASE.md` surfaced something that changes what a bad `1.0.1+2`
would cost, and it is worth knowing **before** T14 rather than during an
incident.

The app reports its version from `PackageInfo.fromPlatform()`, which yields the
version **name** only (`lib/bootstrap.dart`), and the backend validates it
against `/^\d+\.\d+\.\d+$/`. The build number never leaves the phone. So
`1.0.1+2` and `1.0.1+3` are indistinguishable to `minimum_app_version`:

> If `1.0.1+2` ships broken, setting `minimum_app_version = 1.0.1` does **not**
> lock it out. It locks out `1.0.0` and below — that is, everyone except the
> broken build.

The consequence for this release is narrow but real: **if `1.0.1+2` needs to be
gated out, the fix must be `1.0.2+3`, not `1.0.1+3`.** The version gate is
otherwise unusable against it, and the kill switches (`online_ocr_enabled`,
`analysis_enabled`) are the only other lever that works without an upload.

Also noted there: a `PackageInfo` read failure falls back to the compiled-in
`'1.0.0'`, so raising the floor above `1.0.0` also refuses any client whose
version read failed — a small tail on every build, accepted by design.

Two smaller findings: this repository had **no tags at all**, so `v1.0.1+2` is
the first and the published `1.0.0+1` is untagged (backfilling is the owner's
call, and inventing a commit for it would be worse than the gap); and `+` is
valid in a git ref, so the tag name works as the scheme assumes.

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
