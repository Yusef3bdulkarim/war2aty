# F27-T19 · Play compliance build

The first artefact built to be uploaded rather than installed: the signed App
Bundle, and the four things Play enforces on the artefact itself rather than on
the code.

Acceptance, from the F27 plan: *"Target SDK meets Play's current requirement;
16 KB page alignment checked for every native `.so`; permission list reviewed;
signed `.aab` built and its size recorded."*

It also closes **B6**, the audit's open question about the 16 KB memory-page
requirement — recorded on 2026-10-04 as *"The Tesseract plugin ships native
`.so` files. Unverified."*

## What was built

One commit, two artefacts, because neither answers everything. The bundle is
what Play takes; the APK is the only place the merged manifest and the 16 KB
packaging can be read at all (`aapt2` refuses an `.aab` — *"could not identify
format of APK"* — and Play does its own splitting, so an `.aab` has no
library offsets to measure).

| | App Bundle | APK (every ABI) |
|---|---|---|
| Path | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` | `build/app/outputs/flutter-apk/app-prod-release.apk` |
| Size | **69,251,944 bytes (66.0 MB)** | 95,911,793 bytes (91.5 MB) |
| SHA-256 | `95adca40…47c4eb75` | `7fe320c6…393f7da7` |
| Version | `1.0.0+6` (`versionCode=6`) | same |
| Built with | `./tool/build_release.ps1 -Artifact aab` | `./tool/build_release.ps1 -Artifact apk` |

Toolchain: Flutter 3.41.9, AGP 8.11.1, Gradle 8.14, NDK 28.2.13676358,
bundletool 1.18.1 (the version AGP embedded in `BundleConfig.pb`), build-tools
36.1.0 for `aapt2`.

Both are release builds with R8, resource shrinking and obfuscation, signed
with the real release key, and both carry F28's launch screen — this is the
candidate as it stands today, not a synthetic test build.

### The 66 MB is mostly not downloaded by anyone

The bundle's size is the number the acceptance asks for, and on its own it
misleads: **22.8 MB of it is `BUNDLE-METADATA`** — native debug symbols, the R8
mapping and the baseline profiles — which Play keeps and never ships to a
device. The rest is split per device.

| Part of the bundle | Compressed | Uncompressed |
|---|---|---|
| `BUNDLE-METADATA` (Play keeps, never shipped) | 22.8 MB | 79.3 MB |
| `lib/x86_64` | 13.0 MB | 31.0 MB |
| `lib/arm64-v8a` | 12.5 MB | 29.2 MB |
| `lib/armeabi-v7a` | 11.9 MB | 25.1 MB |
| `assets` (incl. `flutter_assets`) | 3.2 MB | 6.3 MB |
| `dex` | 1.6 MB | 3.7 MB |
| `res` (all densities) | 0.9 MB | 1.3 MB |

So a 64-bit phone downloads roughly **18 MB** and a 32-bit one roughly
**18 MB** as well (the arm64 engine is bigger, the arm Dart snapshot is), minus
the density splits it does not need. The install footprint is larger than the
download, because the libraries are stored uncompressed on purpose (§2 below):
about **29 MB of libraries** plus assets and dex on arm64.

Play Console will state the exact per-device numbers at T21. Nothing here is
near any Play size limit.

## 1 · Target SDK

**Pass.** `targetSdkVersion = 36` in the built artefact, read back with
`aapt2 dump badging`.

Play requires **API 36 (Android 16)** of a new app or an update since
**2026-08-31**, with an extension available to 2026-11-01 that this app does
not need. Existing apps must be at 35 to stay available to new users.
([Play target API requirements](https://developer.android.com/google/play/requirements/target-sdk))

The number is not written in this repo. `android/app/build.gradle.kts` has
`targetSdk = flutter.targetSdkVersion`, which T13 did deliberately — a pinned
literal goes stale while looking like a decision — and Flutter 3.41.9 resolves
it to 36. The consequence is that **the target API this app ships is decided by
whichever Flutter version is installed**, outside the repo and outside code
review. So T19 added the guard that was missing: `play_compliance_test` reads
`targetSdkVersion` out of the Flutter SDK's own `FlutterExtension.kt` and fails
if it ever drops below what Play requires. Mutation-checked by raising the
required level to 99:

```
Expected: a value greater than or equal to <99>
  Actual: <36>
this Flutter SDK targets API 36, and Play requires at least 99 of a new app or
an update. Either upgrade Flutter or set targetSdk explicitly — the build is
not publishable as it stands.
```

## 2 · 16 KB page alignment — B6 closed

**Pass, on both halves of the requirement, for all 33 native libraries.**

Play requires apps targeting Android 15+ to support 16 KB memory pages on
64-bit devices; non-compliant updates stop being publishable on
**2027-02-01**, and the requirement already applies to a new app targeting 35+.
([16 KB page sizes](https://developer.android.com/guide/practices/page-sizes))

Two independent things have to be true, and the audit's B6 only named the
first:

**(a) Every LOAD segment of every 64-bit `.so` is aligned to at least 16 KB.**
This is a property of binaries this project does not build: `libtesseract.so`,
`libleptonica.so`, `libjpeg.so`, `libpngx.so`, `libsqlite3.so`,
`libdartjni.so`, `libimage_processing_util_jni.so`,
`libdatastore_shared_counter.so` and `libsurface_util_jni.so` arrive prebuilt
inside plugin AARs, and `libapp.so` / `libflutter.so` come from the engine.

| ABI | Result |
|---|---|
| `arm64-v8a` (11 libraries) | **all ≥ 2\*\*14**; `libapp.so` and `libflutter.so` at 2\*\*16 |
| `x86_64` (11 libraries) | **all ≥ 2\*\*14**; same two at 2\*\*16 |
| `armeabi-v7a` (11 libraries) | 7 at 2\*\*14+, **4 at 2\*\*12** — `libjpeg`, `libleptonica`, `libpngx`, `libtesseract` |

The four 4 KB libraries are **not a problem and were not changed**: a 16 KB
page device is by definition 64-bit, `armeabi-v7a` code never runs on one, and
Google's own `check_elf_alignment.sh` only inspects `arm64-v8a` for the same
reason. Recorded rather than ignored, because the next person to read a 4 KB
number will want to know whether it was seen.

Cross-checked two ways on the same files: the project's own reader, and the
NDK's `llvm-objdump -p` from NDK 28.2.13676358. They agree on all 33.

**(b) The packaging that makes (a) reachable at runtime.** An aligned library
inside a compressed or misaligned APK entry is not mappable, so the alignment
is wasted. In the APK, every `.so` is **stored uncompressed at a 16 KB
boundary** (`libapp.so` at offset 1,687,552 = 103 × 16 KB, and so on for all
33), `extractNativeLibs=false`, and `zipalign -c -P 16 4` from build-tools
36.1.0 reports *Verification successful*. In the bundle, the equivalent is an
instruction to Play rather than a measurable offset, and it is in
`BundleConfig.pb`:

```
uncompressNativeLibraries.enabled       = true
uncompressNativeLibraries.pageAlignment = PAGE_ALIGNMENT_16K
```

`PAGE_ALIGNMENT_16K` is enum value 2, read from the enum compiled into
bundletool 1.18.1 rather than assumed. AGP 8.5.1+ writes it; this project is on
8.11.1.

## 3 · Permission list

**Pass. Eight permissions in the merged prod-release manifest, each justified.**

T16 cleaned the list and guarded it — but `android_permissions_test` reads
`android/app/src/main/AndroidManifest.xml`, and three of the eight do not
appear there at all: they are contributed by plugins and exist only after the
manifest merge, i.e. only inside a built artefact. Nothing had ever reviewed
that list.

| Permission | Source | Verdict |
|---|---|---|
| `CAMERA` | ours | used — the user photographs a paper |
| `INTERNET` | ours | used — Supabase auth, `ocr-document`, `analyze-document` |
| `POST_NOTIFICATIONS` | ours | used — reminder alerts on Android 13+ |
| `RECEIVE_BOOT_COMPLETED` | ours | used — re-arm reminders after a reboot |
| `WAKE_LOCK` | ours | used — deliver a reminder on a sleeping device |
| `ACCESS_NETWORK_STATE` | `connectivity_plus` | **used** — `ConnectivityPlusService` backs the online/offline route decision |
| `VIBRATE` | `flutter_local_notifications` | **used** — the reminder channel vibrates; `AndroidNotificationDetails` defaults to `enableVibration: true` and `FlutterLocalNotificationsPort` does not override it |
| `com.war2aty.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | `androidx.core:core:1.18.0` | **keep** — `protectionLevel="signature"`, declared by the library for its own non-exported receivers, prefixed with the application id, not grantable to anything else |

Provenance read from
`build/app/intermediates/manifest_merge_blame_file/prodRelease/…/manifest-merger-blame-prod-release-report.txt`,
and the final list from `aapt2 dump badging` on the APK.

Nothing was removed. The three plugin permissions are all genuinely used or
inert, and `tools:node="remove"` on a permission a plugin actually needs breaks
the plugin. T16's three removals (`RECORD_AUDIO`, `WRITE_EXTERNAL_STORAGE`,
`READ_EXTERNAL_STORAGE`) are confirmed **absent** from the merged manifest of
this artefact.

`application-debuggable` is absent, as it must be.

### The gap this closed, and the one it left

The allowlist now lives in the tool, which means a plugin upgrade that
contributes a new permission **fails the release check** instead of appearing
in the Play listing. Two guards keep the two lists from drifting apart:
every permission the source manifest declares must be in the tool's allowlist,
and the three permissions T16 removed must *never* be in it.

What is still not automatic: the check runs at release time, not in CI, because
it needs a signed release build (below).

## 4 · Signing

**Pass.** `apksigner` cannot read an `.aab`, so the bundle was verified with
`jarsigner`:

```
jar verified.
Signed by "CN=Yusef Abdulkarim, O=War2aty, L=Cairo, C=EG"
Signature algorithm: SHA256withRSA, 2048-bit key
```

`O=War2aty`, not `CN=Android Debug` — T13's gate did its job. The certificate
runs to **2054-01-22**. The two warnings `jarsigner` prints (self-signed, no
timestamp) are expected and correct for an Android upload key.

## The tool, and why there is one

`tool/check_play_compliance.dart` runs all of the above against a built
artefact:

```bash
dart run tool/check_play_compliance.dart build/app/outputs/bundle/prodRelease/app-prod-release.aab
dart run tool/check_play_compliance.dart build/app/outputs/flutter-apk/app-prod-release.apk
```

A one-off reading of the numbers would have satisfied the acceptance. It would
also have been worthless by the next `flutter pub upgrade`: more than half of
what Play checks here is a property of prebuilt binaries inside plugin AARs and
of the engine, so **compliance can break without a single line of this project
changing, and `flutter test` cannot see it** — the evidence exists only inside
a release artefact.

It is written in pure Dart with no new dependency (CLAUDE.md §B5) and no NDK on
`PATH`: a minimal ELF program-header reader, a minimal ZIP reader, and a
minimal protobuf field walker for `BundleConfig.pb`. The ZIP reader is
hand-written for one specific reason — the two things needed are the two things
a convenience API hides: whether an entry is stored or deflated, and the
**offset** its bytes begin at. That offset must come from the *local* header,
because the padding zipalign inserts to reach a 16 KB boundary lives in the
local extra field while the central directory keeps its own shorter copy. Using
the central one reports alignment that is not there.

`aapt2` (located via `ANDROID_HOME` or `android/local.properties`) answers the
manifest half; without it those checks report as **skipped**, not passed.

### Tested, because a binary reader fails in the wrong direction

A mis-written reader does not crash — it reports compliance it never verified.
So `test/app/play_compliance_test.dart` (20 tests) exercises each reader
against inputs with known answers, and three of its guards were
mutation-checked:

| Mutation | Caught by |
|---|---|
| `minimumLoadAlignment` returns the **maximum** instead of the minimum | *reports the weakest LOAD alignment, not the strongest* and *reads a 32-bit library too* |
| `dataOffsetOf` ignores the local extra field | *takes the data offset from the local header, not the central one* |
| Play's required target API raised to 99 | *the Flutter SDK this project builds with targets at least API 36* |

The `BundleConfig.pb` test is fixed to **the exact bytes AGP 8.11.1 wrote into
this bundle**, not to a message the test also built — a reader agreeing with
its own encoder proves nothing about the one Play reads. The other two cases it
covers are the ones that matter: a 4 KB bundle must not be mistaken for a 16 KB
one, and an unparsed or absent field must read as *unset*, never as compliant.

### What the self-review changed

`/flutter-code-review` on the finished tool found four things, all fixed before
the gate:

- **The one way this check could have passed a library it never examined.**
  Whether the 16 KB requirement applies was decided by `kAbis64Bit.contains(abi)`,
  so a `.so` the reader could not place — anything outside `lib/<abi>/` — was
  treated as 32-bit and exempt. An ABI in neither set is now a reported
  failure, with `abiOf` and both ABI sets under test.
- **A permission prefix that was not checked.** The androidx permission is
  matched on its suffix because the application id differs between flavors,
  but a bare `endsWith` would equally have accepted
  `com.someone.else.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` arriving from an
  unreviewed dependency. It now has to be exactly `<this package>.<suffix>`,
  with the package read from the artifact.
- **A false failure for a true reason.** A failing `aapt2 dump xmltree` left
  empty output, which read as "`extractNativeLibs` is not set" — a correct
  failure reported as the wrong problem. It now says aapt2 failed.
- A doc comment pointing at the wrong test file.

## Found along the way

**The two builds are bit-identical where it counts.** The `.aab` and the APK
were built separately, minutes apart, and `libapp.so` is **byte-identical in
all three ABIs** (`arm64-v8a`, `armeabi-v7a`, `x86_64`), as is the R8 mapping.
So Dart's AOT output and R8's renaming are deterministic for the same commit
and flags, which is worth knowing: it is what makes an obfuscated crash report
from one artefact readable with symbols archived from another.

**But the symbols directory is keyed by version, not by artefact.** Both builds
wrote to `build/symbols/1.0.0+6/`, so the second silently overwrote the first.
It was harmless here only because the inputs matched. An APK built with
`-Arm64Only`, or with different `--dart-define`s, produces a *different*
mapping into the same directory — and the mapping that no longer matches the
uploaded bundle is indistinguishable from the one that does. **For T25**
(symbol archival, still homeless since T13): archive per artefact and per
SHA-256, not per version.

## Not done here, deliberately

- **No upload.** Play Console is the owner's console and T21's work; nothing
  was uploaded, and no app exists in Play yet. Q14 (Play App Signing) and Q15
  (the package ID, `com.war2aty.app`, unchangeable after the first upload) are
  settled on paper and are T21's to execute.
- **The check is not in CI.** It needs a signed release build, which CI does
  not produce and should not: the keystore is on one machine and stays there.
  `docs/BUILD.md` carries it as a release step instead, which is the honest
  arrangement rather than a guard that pretends to run.
- **No device run of this artefact.** T18 put `1.0.0+6` on the RMX2001; this
  bundle is the same version and the same `libapp.so`. A 16 KB page device
  would be the only way to *observe* §2 rather than verify it statically, and
  no such phone is available (the RMX2001 is API 30). Recorded as a limit, not
  claimed as covered.

## Gate

`dart format` clean · `flutter analyze` 0 errors / 0 warnings (18 pre-existing
infos, none in the new files) · `flutter test` **2,468 green (+20)**.
