# F28 · Splash redesign: a new concept, and the logo on screen from the first frame

- **Branch:** `feature/splash-redesign`, based on `develop` · **Milestone:** post-F27
- **Depends on:** F27-P01 (the splash this replaces), F27-T18 finding D-2 (the
  measurement this starts from), the brand generator `tool/branding/generate_brand_assets.dart`
- **Progress:** 5 / 9 DONE
- **PR:** TBD (one per task batch: after T04, after T07, after T09)

The owner asked for a dedicated splash task on 2026-10-07, recorded at the end
of [F27-T18 finding D-2](F27-T18-device-pass.md). T18 shipped the cheap half of
the fix — bringing the mark's fade forward — and deliberately left the rest of
the launch look undecided, because "whether the native splash should carry the
mark at all is a design decision" and a device-pass task is the wrong place to
make it. This is that task.

Two things are being changed at once, and they are independent:

1. **The concept.** The P01 splash (brand gradient + soft radial glow + a
   breathing mark) is replaced outright — not revised. The owner's words:
   *"replace and change the concept/idea completely."*
2. **The flicker.** The logo must be on screen from the moment the app starts,
   not ~775 ms later.

## The measured baseline

From F27-T18, release build on the RMX2001. These are measured numbers, not
estimates, and they are what this feature has to beat:

| Moment | When | Why |
|---|---|---|
| System starting window — **flat teal, no mark** | ~100 ms | by design: `splash_icon.xml` is transparent, `launch_background.xml` is one flat colour |
| Flutter's first frame | **~440 ms** | engine + Dart VM + framework init; still flat teal, mark opacity 0 |
| Entrance starts | +2 frames (~33 ms) | deliberate: the costliest frame lands on a still screen |
| Mark solid | **~775 ms** | after T18's `_span(0, 0.30)` fix (was ~1,220 ms) |
| Splash leaves | **~3.2 s minimum** | 1.8 s entrance hold + 350 ms settle + ≤600 ms content wait + 400 ms fade — even when init finishes instantly |

The ~440 ms before Flutter's first frame **cannot be removed from Dart**. The
only way to the logo appearing at ~100 ms is to put it in the native splash.

## Locked decisions

Resolved with the owner on 2026-10-08.

1. **There is no concept. The screen is the background colour and the icon.**
   Settled by the owner on 2026-10-08, after three concepts were proposed and
   all three were discarded: *"no additional frames, lines, or background
   patterns whatsoever... only the background color and the icon, with nothing
   else added."* This **supersedes** the brief's original call for a subtle
   geometric pattern, and it is the instruction that governs. The old
   `feature/animated-splash` concept was likewise never consulted, and its
   branch was deleted unexamined (SHA recorded below).
2. **The native splash carries the mark** on all three paths, reversing P01's
   decision to show the teal alone. The handover is built as a **pixel-identical
   frame**: Flutter's first frame draws the same mark at the same size, in the
   same place, on the same flat colour, at full opacity — so the ~440 ms
   substitution is invisible.
   - Android pre-12: `launch_background.xml` layer-list, centred bitmap at 128 dp,
     density-bucketed.
   - Android 12+: `splash_icon` as a **288 dp canvas with the mark at 128 dp
     centred** (Android requires content inside the inner 192 dp circle).
   - iOS: `LaunchImage` at 128 pt @1x/2x/3x; the storyboard already centres it.
3. **The API 31+ system splash exit animation is suppressed**
   (`splashScreen.setOnExitAnimationListener { it.remove() }`, guarded by
   `SDK_INT >= 31`) or it fades/scales its icon out and reintroduces the jump.
   **No new dependency** — the platform API, not `androidx.core:core-splashscreen`.
4. **Nothing arrives after the handover.** The earlier plan had the Flutter
   splash start flat and fade a background in over ~300 ms, so the design could
   use a pattern the native layer cannot draw. Decision 1 removed the pattern,
   so that mechanism is removed with it: the Flutter splash is the same flat
   colour and the same mark, and it simply stays that way. This makes the
   pixel-identical handover trivially true rather than carefully arranged.
5. **No text on screen.** Logo only. The app name stays a `Semantics` label, as
   it is today — it is the screen-reader label and the task-switcher title
   (F27-T14).
6. **The hand-off is rebuilt from scratch.** `SplashHandOff`, `LaunchReveal`,
   `splash_timing.dart` and `BootstrapCubit`'s entrance handshake
   (`splashEntranceFinished`, `splashEntranceTimeout`) are all deleted, not
   adapted. They solved real defects — the splash cutting to Home, and
   animations freezing during Home's first build — so the rebuilt mechanism
   must still solve those, and the tests that prove it are rewritten rather
   than carried over.
7. **Timing is optimised for launch speed, not for a brand moment.** The fixed
   1.8 s hold goes. Hand off as soon as init is done **and** a ~500 ms floor
   since the first frame has passed, keeping a capped "wait for Home's content"
   gate so the reveal never lands on a skeleton. Target: **~1.2 s to Home**
   instead of ~3.2 s, with the logo visible for essentially all of it.
8. **Design comes from the brand colours**, not from `Waraqti.dc.html` — the
   design file ships no splash comp (the P01 splash was invented from a local
   HTML preview, which is why CLAUDE.md's "stop if no design exists" rule is
   being satisfied by an approval gate at T03 instead).
9. **The mark is upscaled in the generator.** No higher-resolution source
   exists — `assets/branding/icon.jpg` is a 1024×559 mockup whose symbol is
   ~315 px tall, so the 3× mark (384 px) is already a ~1.2× upscale. The
   generator gains an upscale-and-sharpen step rather than waiting for artwork
   that is not coming.
10. **Skills used:** `frontend-design` and `ui-ux-pro-max`, both installed
    globally by the owner on 2026-10-08 for the design work (T03).

## Tasks

| # | ID | Task | Output | Status |
|---|---|---|---|---|
| 1 | F28-T01 | Feature doc, branch, stale-branch cleanup | this doc + `README.md` row; PR #29 merged to `develop`; `feature/splash-redesign` cut from `develop`; three stale branches deleted | DONE 2026-10-08 |
| 2 | F28-T02 | Purge the old splash | as planned, plus a test file the coverage guard required — see "T02 record" | DONE 2026-10-08 |
| 3 | F28-T03 | **Design → owner decision** | three concepts proposed and all three discarded; the screen is the background colour and the icon — see "T03 record" | DONE 2026-10-08 |
| 4 | F28-T04 | A sharper mark | unsharp mask in `_resize`; every splash mark regenerated, +49–62 % edge contrast — see "T04 record" | DONE 2026-10-08 |
| 5 | F28-T05 | Native splash carries the mark | all three paths wired, 13 guards, mutation-proved, verified in the APK's resource table — see "T05 record" | DONE 2026-10-08 |
| 6 | F28-T06 | The Flutter splash | the mark at 128 dp on `kLaunchBackground`, centred, full opacity, static — and a test that it matches the native splash | |
| 7 | F28-T07 | The new hand-off | replaces `SplashHandOff` / `LaunchReveal`; ~500 ms floor, capped content gate, reveal fade, reduced-motion path | |
| 8 | F28-T08 | Tests + gate + device verification | new test suite (seam guard, timing guard, reduced motion, error state, RTL + large text); `dart format` / `flutter analyze` / `flutter test`; installed on the RMX2001 with `am start -W` numbers recorded here | |
| 9 | F28-T09 | Review and close | `/flutter-code-review` → `@code-reviewer` → `/explain-feature`; F27-T18's D-2 note updated to point here; PR | |

## T02 record (2026-10-08)

**Deleted** (6 files): `splash_screen.dart`, `splash_timing.dart`,
`splash_hand_off.dart`, `launch_reveal.dart`, `splash_screen_test.dart`,
`splash_hand_off_test.dart`. The `presentation/widgets/` directory went with
them — it held nothing else.

**Added**: `launch_error_screen.dart` (the old `_LaunchError`, moved out
unchanged) and `launch_screen.dart`, the interim host that switches on
`BootstrapState` and draws a flat frame. The flat colour is now a named
constant, `kLaunchBackground` (`#0A6C76`), because T05 and T06 both have to
agree with it exactly or the handover becomes visible — it is the one value
Android's `splash_bg`, `windowSplashScreenBackground`, the iOS storyboard and
Flutter's first frame all have to share.

**Unwired, deliberately left in place for T07** — each of these was a real
mechanism, and the notes say so where they used to be rather than in this file
alone:

| What | Where it was | What it did | State now |
|---|---|---|---|
| `splashEntranceTimeout` / `splashEntranceFinished` | `BootstrapCubit` | held `BootstrapSuccess` back until the splash's entrance had played out | gone; nothing paces the launch |
| `LaunchReveal.contentReady` | router → `HomeScreen.onContentLoaded` | let the splash reveal Home whole instead of mid-skeleton | `onContentLoaded` survives on the screens, unwired |
| `LaunchReveal.revealed` | `ReminderNotificationOpener` | held a tapped reminder back so its page did not slide in under the fade | not passed; the parameter was already optional, so no API churn |
| `finishLaunch()` after the reveal | `app.dart` | ran the deferred launch steps once nothing was animating | moved to `_FinishLaunchOnMounted`, a post-frame call on the app's first frame |
| `_precacheSplashMark` | `bootstrap.dart` | decoded the mark before the splash's first frame | gone with the asset constant it referenced |

**The launch now ends in a visible cut.** That is the defect the old hand-off
existed to prevent, and it is back between T02 and T07 by design rather than by
oversight. It is recorded in `app.dart`'s own doc comment so it cannot be
mistaken for the finished behaviour.

**One thing the plan did not anticipate.** `ui_audit_coverage_test` failed: it
enumerates every screen in the app and refuses any without an
`auditScreenLayout` entry, so the two new screens had to be covered before the
gate could go green. `launch_screen_test.dart` (23 tests) does that and carries
over what the purge preserved rather than what it removed — the state switch,
the failure's retry, the app-name label, the stage live region, the light
status-bar icons, and an assertion that the frame is exactly
`kLaunchBackground`. Nothing about how the launch *looks* is tested; T06 brings
the design and T08 the suite that pins it.

Worth knowing for anyone writing tests against this screen: the old splash's
live-region test passed with a single `pump()` because its animation controller
always had a frame pending. A screen with nothing moving has no such frame, so
the stage reaches the cubit during the first pump and the rebuild lands on the
next one — two pumps, and the test says why.

**Gate:** `dart format` 0 changed (707 files), `flutter analyze` **0 errors /
0 warnings** (18 infos, the standing baseline), `flutter test` **2,417 passed**.
`flutter build apk --flavor dev --debug` succeeds, so the app still compiles for
a device as well as for the test VM.

## T03 record (2026-10-08) — three concepts proposed, all three discarded

Three were built and shown as a live preview: hairlines grouped like a printed
form drawing in right-to-left, a letter folded in three for an envelope, and the
diagonal security lattice printed into official paper. The owner discarded all
three and settled the screen directly:

> no additional frames, lines, or background patterns whatsoever... only the
> background color and the icon, with nothing else added.

This **supersedes the original brief**, which asked for a subtle geometric
pattern and said to avoid a flat colour. The later instruction governs, and it
is recorded here because the two read as contradictory to anyone coming to this
file cold.

### The settled specification

| | |
|---|---|
| Background | solid `kLaunchBackground` `#0A6C76`, full bleed |
| Mark | `brand_mark.png`, 128 dp, centred, full opacity |
| Everything else | nothing — no gradient, no glow, no pattern, no lines, no frame, no text |
| Motion | none |
| Status bar | light icons on the teal |
| Reduced motion | no separate path needed: nothing moves in either case |

**Motion reads as none.** The owner asked earlier for "elegant animations", and
this instruction does not mention motion either way. It resolves to a still
screen for two reasons rather than by preference: the only thing left on screen
is the mark, and animating the mark is precisely what decision 2 forbids, since
the system has already drawn it before Flutter starts. A still screen is also
the strict reading of "nothing else added". If the owner wants a subtle moment
after all, it is a small addition to T06 — but it would have to animate
something, and there is nothing left to animate without reopening decision 2.

### What this simplifies

- The ~300 ms background fade (old decision 4) is gone, and with it the only
  part of the Flutter splash that had to be choreographed.
- T06 shrinks to drawing one image on one colour. `_LaunchFrame` from T02
  already paints that colour; T06 adds the mark.
- The pixel-identical handover stops being something to arrange carefully and
  becomes true by construction: both layers are one flat colour and one centred
  image, from one constant and one asset.
- **T04 matters more, not less.** The mark is now the only thing on the screen,
  so its softness is the only visual flaw left anywhere in the launch.

### What was removed

`tool/branding/splash_preview_v2.html` is deleted rather than kept. It renders
three concepts that are now void, and a preview of rejected designs sitting in
`tool/branding/` next to the P01 one would mislead whoever opens it next. It
remains in history at commit `8de449d` if it is ever wanted.

## T04 record (2026-10-08)

The mark is now the only thing on the launch screen (decision 1), so its
softness was the only visual flaw left anywhere in the launch.

**Why it was soft, measured rather than assumed.** The generator prints its own
numbers: `tile 448px at (288, 56); symbol box Rectangle (67, 64) 314 x 323`. So
`squareSymbol` is about **355 px**, and from it the pipeline asks for 384 px at
3x (a 1.08x enlargement) and 512 px at Android xxxhdpi (1.44x). There is no
better source — `assets/branding/icon.jpg` is the owner's 1024x559 mockup, and
the owner confirmed on 2026-10-08 that none is coming.

**What was done.** `cubic` is already the sharpest interpolation the `image`
package has, so the gain had to come from after the resample. `_resize` gained
an optional unsharp mask (`sharpen`, default **0**), applied on the
premultiplied pixels before alpha is divided back out, with blur radius 1 — the
narrowest available, which keeps any halo inside a pixel of the edge. It
sharpens alpha along with colour, because a light symbol on flat teal is read
mostly by its silhouette, and the silhouette lives in alpha.

`_markSharpen = 0.55`. Measured as variance-of-the-Laplacian on both luminance
and alpha:

| asset | luminance | alpha |
|---|---|---|
| 1x (128 px) | +62 % | +62 % |
| 2x (256 px) | +49 % | +49 % |
| 3x (384 px) | +51 % | +51 % |

The number was then checked by eye against the two things it could have broken,
on the real `#0A6C76`: no dark ringing where the white document meets the teal,
and the ring's deliberate soft outer fade still soft rather than hardened into
a line. At 1x the gain is the most visible — the document's rules and the check
mark go from mushy to legible.

**Nothing else moved.** `sharpen` defaults to 0, so every launcher and app-icon
target resampled byte-for-byte identically; `git status` after regenerating
listed only the splash marks. That was the point of putting the default at 0
rather than sharpening all enlargements: the launcher and iOS icons are
owner-approved from P01 and are not this task's to change. The same helper
would improve the iOS 1024 px icon, which P01 recorded as a 2.3x enlargement —
left alone deliberately, and noted here for T23.

**New files, for F28-T05 to wire up.** The mark now exists as native bitmaps,
all from the one `_splashMarkDp = 128` so the four layers cannot drift:

- `android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/splash_mark.png`
  (128/192/256/384/512 px, **392 KB** across all five);
- `ios/.../LaunchImage.imageset/LaunchImage{,@2x,@3x}.png` (128/256/384 px),
  replacing the 1x1 transparent placeholders that made the iOS launch screen
  show the teal alone.

**Size, stated rather than buried.** A universal APK carries all five Android
densities: **+392 KB on ~34.9 MB, about +1.1 %**. An App Bundle would ship one.
Dropping `xxxhdpi` alone would save 181 KB at the cost of a softer mark on 4x
devices — not done, because the owner has not asked to trade the thing this
task just fixed for 0.5 % of the download.

**Gate:** format 0 changed, analyze **0 errors / 0 warnings** (18 standing
infos), **2,417 tests** green.

## T05 record (2026-10-08)

This is the task that actually removes the flicker. P01 is reversed on all
three paths: the native splash now draws the mark, so it is on screen at
~100 ms instead of ~775 ms.

**Android before 12** — `launch_background.xml`, in both `drawable/` and
`drawable-v21/`: the teal, then `@drawable/splash_mark` at `gravity="center"`,
drawn at its intrinsic size, which the generator cuts to 128 dp per density.

**Android 12 and up** — the sizing is the whole trick, and getting it wrong is
invisible on this machine. The system draws `windowSplashScreenAnimatedIcon`
into a **288 dp canvas** and expects content inside the inner 192 dp circle.
Hand it a bare bitmap and it is scaled to fill 288 dp — **more than twice**
the size Flutter draws the mark at, so the handover becomes a jump. So
`splash_icon.xml` is a `layer-list` that supplies the canvas and pins its one
item to `128dp × 128dp`, centred. No `windowSplashScreenIconBackgroundColor`
is set, which is what makes the canvas 288 dp rather than 240 dp; 128 dp is
inside either safe zone, so the mark is never clipped.

**The system splash's own exit animation** would have undone all of it.
By default Android plays its icon out, fading and scaling it, while Flutter's
identical mark sits underneath — so the mark would appear to shrink away and
come back. `MainActivity.removeSystemSplashExitAnimation` takes the splash off
instantly instead, guarded on API 31 where `Activity.getSplashScreen()`
arrives. Removing it with no animation is only correct because Flutter's first
frame is already a copy of it. Deliberately the platform API, not
`androidx.core:core-splashscreen` — three lines, no new dependency.

**iOS** — the `LaunchImage` files stopped being 1×1 transparent placeholders in
T04, which is what had made the iOS launch screen show the teal alone. The
storyboard already centred the image on the right colour; its stale
`<image name="LaunchImage" width="168" height="185"/>` declaration is corrected
to 128×128. **Still written blind** — no Mac, so none of the iOS half has been
built or seen (see "Known limits").

### The guard, and proof it works

`test/app/native_splash_test.dart`, 13 tests. The one that matters most reads
`kLaunchBackground` out of the Dart source and asserts Android's
`colors.xml` **and** the iOS storyboard's sRGB floats resolve to the same
value. Four layers draw this launch and none of them can see the others;
nothing else in the suite reads that XML.

Mutation-proved rather than assumed — each of these was applied, the suite
run, and the change reverted:

| Mutation | Caught |
|---|---|
| `#FF0A6C76` → `#FF0A6C77` in `colors.xml` (one step, invisible by eye) | yes |
| dropped the `128dp` pin from `splash_icon.xml`, letting the system scale the icon | yes |
| removed `setOnExitAnimationListener`, restoring the default play-out | yes |

### Verified in the artefact, not just in the source

`aapt2 dump resources` on the built APK:

- `color/splash_bg` → `#ff0a6c76`, the same value as `kLaunchBackground`;
- `drawable/splash_icon` → the layer-list XML;
- `drawable/splash_mark` → present at mdpi, hdpi, xhdpi, xxhdpi and xxxhdpi;
- both v31 themes carry `windowSplashScreenBackground` and
  `windowSplashScreenAnimatedIcon`.

The build itself is part of the proof: `aapt2` fails on an unresolved
reference, so a compiling APK means every `@drawable/splash_mark` resolves.

**Gate:** format clean, analyze **0 errors / 0 warnings**, **2,430 tests**
green (+13), `flutter build apk --flavor dev --debug` succeeds.

### What is still not true

Flutter's first frame does **not** yet draw the mark — T06 does that. Until
then the launch shows the mark natively and then *loses* it when Flutter takes
over at ~440 ms, which is worse than before this task on its own. T05 and T06
only make sense together, and nothing should be put in front of a user between
them.

## Deleted branches (F28-T01)

Recorded before deletion so they are identifiable in the reflog. All three were
unmerged; the owner authorised deleting each one.

| Branch | SHA | Remote | Why it went |
|---|---|---|---|
| `feature/animated-splash` | `24f67d1776a5e30337a7851de79ce5cefd1f3472` | local only | superseded — the concept is being replaced outright, so it was deleted unexamined (decision 1) |
| `backup/animated-splash-prerebase` | `24f67d1776a5e30337a7851de79ce5cefd1f3472` | local only | the backup of the above, same head |
| `feature/splash-startup-latency` | `38d7b959f5892e1d0caa4d2b2d75ad43df5ff33d` (origin `e1fac5f4d6be3e55ccd8d5acc8a581e7f372d86c`) | yes | PR #19 already closed; its one valuable commit was cherry-picked as `90efdc8`; the rest tunes a 6 s entrance that no longer exists |

## Known limits, written down rather than papered over

- **The Android 12+ path cannot be verified on the available hardware.** The
  RMX2001 is **API 30**, so it exercises the pre-12 path only. `values-v31`, the
  288 dp icon canvas and the exit-animation listener will be built to spec and
  marked **unverified**. The owner's standing rule is no emulators; it stands
  unless they make an exception for this one check.
- **iOS is written blind.** No Mac, so the `LaunchImage` and storyboard changes
  can be written but never built or seen — the same limit P01 recorded and T23
  still owns.
- **The mark stays slightly soft.** T04 improves it by upscaling; only a square
  ≥1024 px source or an SVG actually fixes it, and none exists.

## Exit DoD

- The logo is on screen from the system starting window (~100 ms), and there is
  **no visible change** when Flutter takes over.
- The launch is **one unchanging image** from the system starting window
  until Home: the same colour, the same mark, in the same place. The
  original brief forbade a flat colour here; decision 1 reversed that, and
  the test of success is now that nothing on screen changes at all until
  the app itself appears.
- Cold start to Home is materially faster than the ~3.2 s floor it replaces.
- Nothing of the old splash remains: no `SplashHandOff`, no `LaunchReveal`, no
  `splash_timing.dart`, no gradient-and-glow screen.
- The defects the old hand-off existed to prevent — a cut to Home, a frozen
  animation during Home's first build — are still prevented, and tests prove it.
- Reduced motion, RTL and large text all handled; gate green.
