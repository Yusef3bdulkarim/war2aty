# Building War2aty

How to produce a build that is safe to give to someone. Written for whoever has
a checkout and needs an artifact — a tester's APK, or the bundle Play takes.

Produced by F27-T13. Companion documents: `docs/OPERATIONS.md` for running the
backend, `docs/RELEASE.md` for versioning, tagging and rollout (F27-T25).

---

## The short version

```powershell
./tool/build_release.ps1 -Artifact aab          # what Play takes
./tool/build_release.ps1 -Artifact apk          # install directly, every ABI
./tool/build_release.ps1 -Artifact apk -Arm64Only   # half the size, 64-bit phones
```

Use the script rather than typing the command. A release build is a list of
flags that are **silent when forgotten**, which is the whole reason it exists:

| Flag | Forgotten, you get |
|---|---|
| `--dart-define-from-file=config/prod.json` | an app that launches, finds no backend, and tells every user the service is unavailable |
| `--obfuscate` | Dart class and function names shipped in `libapp.so` |
| `--split-debug-info=build/symbols/<version>` | no mapping, so a future obfuscated stack trace is unreadable for ever |
| `-t lib/main_prod.dart` | a build failure — there is no `lib/main.dart` — which at least is loud |

The release key is the one thing you cannot forget: a prod release **fails**
without it (below).

---

## The release key

`android/key.properties` (git-ignored) with four entries, and the keystore it
names next to it in `android/app/`:

```properties
storeFile=war2aty-release.jks
storePassword=…
keyAlias=…
keyPassword=…
```

`storeFile` resolves **relative to `android/app/`**, not to the repo root.

**A prod release build fails without a usable key** (F27-H7). It used to fall
back to the debug key and say nothing, which produces an artifact that installs,
runs, looks correct, and is rejected by Play with a signature error — or worse,
is handed to a tester and trusted. The check is in
`android/app/build.gradle.kts` and names what is wrong:

```
A prod release build needs the real release key, and android/key.properties does not exist.
```

It fires on `assembleProdRelease`, `bundleProdRelease`, `packageProdRelease`,
`packageProdReleaseBundle` and `installProdRelease`, and on nothing else. In
particular a **dev** release still builds on a machine with no keystore, signed
with the debug key, because `flutter run --release` on the dev flavor is an
everyday thing and the dev app has its own `applicationId` that is never
published.

**The keystore is currently on one machine.** Losing it means losing the ability
to update the app — unless Play App Signing is enrolled (Q14), which makes a
lost *upload* key recoverable. Back it up somewhere off this machine.

---

## Symbols: keep them

`build/symbols/<version>+<build>/app.android-arm64.symbols` (~5 MB per ABI) is
the mapping from obfuscated names back to real ones. **Keep it for as long as
that build is installed anywhere**, archived next to the artifact. Without it an
obfuscated crash report is unreadable, and it cannot be regenerated — a later
build produces different names.

**Where they are archived is not solved yet.** `build/` is git-ignored, so the
symbols exist on the machine that built the artifact and nowhere else — the same
single point of failure as the keystore. They are small enough to attach to a
GitHub release asset on the version tag, which is free on a public repo and puts
the mapping next to the build it belongs to; that pairs with the tagging scheme
F27-T25 owns, so the decision is recorded there rather than invented here. Until
then: **copy `build/symbols/<version>/` off this machine by hand whenever a
build is given to anyone.**

To read a stack trace from a build:

```powershell
flutter symbolize -i stack.txt -d build/symbols/1.0.0+3/app.android-arm64.symbols
```

**Not yet verified end to end.** Obfuscation's effect cannot be demonstrated by
inspecting the binary on this engine version — Flutter's release AOT already
strips Dart class names, so an obfuscated and a non-obfuscated `libapp.so` both
contain none of them. What is verified is that the flags are accepted and the
mapping is produced and archived. The symbolize path itself needs a real
obfuscated stack trace, which this app has no way to produce on purpose: the
error reporting added in F27-T12 deliberately carries **no** stack traces (§7),
so the first one will come from Play's own crash reporting after launch
(F27-T21/T26). Verify it then, on the first real crash, while the symbols for
that build are still to hand.

---

## What ships, and what does not

- **The dev-only mock fixtures do not.** `assets/fixtures/analysis/` backs
  `MockAnalysisRemoteDataSource`, reachable only when
  `env.isDev && USE_MOCK_ANALYSIS`. pubspec has no per-flavor asset list, so
  they are deleted from the merged assets of every **prod** variant after the
  Flutter plugin copies them in (F27-M4). A dev build keeps them, which is what
  makes the mock work.
  - Verify after a build: `unzip -l <apk> | grep fixtures` — 0 lines for prod,
    6 for dev.
- **Only the ABIs you asked for.** `--target-platform` drives both Flutter's
  engine libraries and the plugins' prebuilt `.so` files (Tesseract, OpenCV),
  which otherwise ship for every architecture — about 10 MB of code the device
  cannot run. Deliberately **not** pinned for the `.aab`: Play splits per device
  itself, and pinning one ABI would drop every 32-bit phone from the listing.
- **R8 with keep rules**, and `isShrinkResources`. One trap already paid for:
  shrinking strips resources named only from Dart strings, so
  `res/raw/keep.xml` holds `ic_stat_notify` (F27-P02). A resource referenced
  only from Dart needs an entry there.

Sizes, measured 2026-10-06 at `1.0.0+3`:

| Artifact | Size |
|---|---|
| prod APK, arm64 only, obfuscated | **34.9 MB** |
| dev APK, every ABI | 96.5 MB |

---

## Gradle memory (F27-M8)

`android/gradle.properties` is sized from what actually crashed, and the reason
matters because the obvious fix is the wrong one.

Three Gradle crash dumps were sitting in `android/`. Every one is a **native**
allocation failure — `malloc failed … Chunk::new` — with the machine at 835 MB
free of 16 GB and the page file down to **2 MB** available, while the Gradle
daemon's own working set peaked at 759 MB. The build did not run out of Java
heap. **The machine ran out of memory**, with Docker, an emulator and the IDE
running alongside.

So raising `-Xmx` would have made it worse: a larger Java heap reserves more
address space and squeezes the native heap that failed. The settings go the
other way, and remove one whole JVM from the build:

```properties
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=256m
kotlin.compiler.execution.strategy=in-process
```

`-XX:+HeapDumpOnOutOfMemoryError` was removed: it cannot fire on a native OOM,
and when it does fire it writes a multi-gigabyte file on a machine that is
already out of memory.

**If a release build fails for memory**, read the error before changing
anything:

- `OutOfMemoryError: Java heap space` → genuinely the heap. Raise `-Xmx`.
- `insufficient memory for the Java Runtime Environment` / `malloc failed` →
  the machine. Close Docker, the emulator and Android Studio, and build again.
  A prod release APK takes about 2.5 minutes on this hardware with those shut.

---

## Checks before handing a build to anyone

```powershell
flutter analyze; flutter test
./tool/build_release.ps1 -Artifact apk -Arm64Only
```

Then, on the artifact:

```bash
# signed with the release key, not the debug key
apksigner verify --print-certs <apk>     # expect CN=…, O=War2aty — never "Android Debug"
# dev fixtures absent
unzip -l <apk> | grep -c fixtures        # expect 0
# symbols archived alongside
ls build/symbols/<version>/
```

A debug-signed artifact is the failure this document exists to prevent, and
`apksigner` is the one check that cannot be fooled by the build succeeding.
