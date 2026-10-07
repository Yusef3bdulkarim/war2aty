# F28 · Splash redesign: a new concept, and the logo on screen from the first frame

- **Branch:** `feature/splash-redesign`, based on `develop` · **Milestone:** post-F27
- **Depends on:** F27-P01 (the splash this replaces), F27-T18 finding D-2 (the
  measurement this starts from), the brand generator `tool/branding/generate_brand_assets.dart`
- **Progress:** 1 / 9 DONE
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

1. **The concept is replaced, not revised.** Three completely different design
   variants are proposed as an HTML preview and one is chosen. The old
   `feature/animated-splash` concept ("paper dart flies in and opens into the
   logo") was deliberately **not** consulted — the owner ruled the idea must be
   new, so that branch was deleted unexamined (SHA recorded below).
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
4. **Background comes in after the handover (owner chose option B).** The native
   splash can only show a flat colour, so the Flutter splash starts flat and
   fades its background in over ~300 ms. There is no visible seam, and the
   design is free to use a pattern the native layer cannot draw.
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
| 2 | F28-T02 | Purge the old splash | `splash_screen.dart`, `splash_timing.dart`, `splash_hand_off.dart`, `launch_reveal.dart` and both test files deleted; splash wiring stripped from `app.dart`, `service_locator.dart`, `bootstrap_cubit.dart`, `app_router.dart`; `_LaunchError` extracted to its own file, visually unchanged; app still builds and launches on a plain placeholder; gate green | |
| 3 | F28-T03 | **Design: 3 variants → owner approval gate** | HTML preview in `tool/branding/`, three completely different concepts, brand colours, logo only, each with its own motion idea; written design plan reviewed for genericness before any code (per `frontend-design`) | |
| 4 | F28-T04 | A sharper mark | upscale + sharpen in `generate_brand_assets.dart`; regenerated 1×/2×/3× plus every native splash size | |
| 5 | F28-T05 | Native splash carries the mark | Android pre-12 (light + night), API 31+ `values-v31` / `values-night-v31`, the exit-animation listener in `MainActivity`, iOS `LaunchImage` + storyboard (written blind) | |
| 6 | F28-T06 | The new Flutter splash | the approved variant; first frame pixel-matches the native splash; background fades in; the new idle animation | |
| 7 | F28-T07 | The new hand-off | replaces `SplashHandOff` / `LaunchReveal`; ~500 ms floor, capped content gate, reveal fade, reduced-motion path | |
| 8 | F28-T08 | Tests + gate + device verification | new test suite (seam guard, timing guard, reduced motion, error state, RTL + large text); `dart format` / `flutter analyze` / `flutter test`; installed on the RMX2001 with `am start -W` numbers recorded here | |
| 9 | F28-T09 | Review and close | `/flutter-code-review` → `@code-reviewer` → `/explain-feature`; F27-T18's D-2 note updated to point here; PR | |

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
- No flat-colour-only stretch at any point in the launch.
- Cold start to Home is materially faster than the ~3.2 s floor it replaces.
- Nothing of the old splash remains: no `SplashHandOff`, no `LaunchReveal`, no
  `splash_timing.dart`, no gradient-and-glow screen.
- The defects the old hand-off existed to prevent — a cut to Home, a frozen
  animation during Home's first build — are still prevented, and tests prove it.
- Reduced motion, RTL and large text all handled; gate green.
