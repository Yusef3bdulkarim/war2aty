# F28 · Splash redesign: a new concept, and the logo on screen from the first frame

- **Branch:** `feature/splash-redesign`, based on `develop` · **Milestone:** post-F27
- **Depends on:** F27-P01 (the splash this replaces), F27-T18 finding D-2 (the
  measurement this starts from), the brand generator `tool/branding/generate_brand_assets.dart`
- **Progress:** 2 / 9 DONE
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
| 2 | F28-T02 | Purge the old splash | as planned, plus a test file the coverage guard required — see "T02 record" | DONE 2026-10-08 |
| 3 | F28-T03 | **Design: 3 variants → owner approval gate** | `tool/branding/splash_preview_v2.html` — see "T03 record" | **AWAITING THE OWNER'S PICK** |
| 4 | F28-T04 | A sharper mark | upscale + sharpen in `generate_brand_assets.dart`; regenerated 1×/2×/3× plus every native splash size | |
| 5 | F28-T05 | Native splash carries the mark | Android pre-12 (light + night), API 31+ `values-v31` / `values-night-v31`, the exit-animation listener in `MainActivity`, iOS `LaunchImage` + storyboard (written blind) | |
| 6 | F28-T06 | The new Flutter splash | the approved variant; first frame pixel-matches the native splash; background fades in; the new idle animation | |
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

## T03 record (2026-10-08) — awaiting the owner's pick

Preview: **`tool/branding/splash_preview_v2.html`** (open in a browser). Replay,
0.5x / 0.25x, a reduced-motion switch, and a **Hold frame 0** button. It also
shows the handover proof: the system splash and Flutter's first frame side by
side, identical.

### The constraint that shaped all three

Decision 2 says Flutter's first frame must match the native splash exactly. That
rules out the obvious splash move — a logo that fades or scales in — because the
logo is already on screen, drawn by the system, before Flutter exists. So in all
three concepts **the mark never moves and never fades**. It is the fixed point,
and the paper world assembles around it. Only the background arrives, once.

### Palette: five brand values, nothing else

| Token | Hex | Role |
|---|---|---|
| `launch` | `#0A6C76` | the handover colour; frame 0, and the floor of every concept |
| `near` | `#0E7C86` | brand teal |
| `far` | `#0A5C64` | deep teal |
| `recess` | `#04454E` | the icon's own darker ground (P01 lifted it from the owner's artwork) |
| `mint` | `#34D0B4` | only ever a hairline, only ever at low alpha |

**Type: none.** The splash carries no text by decision 5, so there is no
typeface to choose. The preview's own chrome uses Cairo loaded from
`assets/fonts/` rather than Google Fonts, so the file works offline.

### The three

Each is a different *kind* of geometry, not three versions of one idea.

| | Concept | Geometry | The one moment |
|---|---|---|---|
| A | **«السطور»** Ruled lines | 1D — horizontal hairlines, grouped as a real form groups them, breaking around the mark | the rules draw in **from the right leftward**, the direction these users read |
| B | **«الطيّة»** The fold | 2D — a letter folded in three for an envelope, flat planes, no gradient | the two outer bands take the light; the middle band, where the mark sits, never changes at all |
| C | **«الشبكة»** The watermark | texture — the fine diagonal security lattice printed into official paper | it resolves into focus once, easing from very slightly oversized to exact |

### What the review pass changed

The plan was written, then checked against the brief for anything that was a
default rather than a choice. Three things failed that check, and two of them
only became obvious once the page was rendered and looked at:

1. **Evenly spaced rules in A** — hairline rules are on `frontend-design`'s list
   of generated-page tells. Fixed by grouping them irregularly, the way a form
   does, so the rhythm carries information instead of decorating.
2. **B was four quarters.** Rendered, it read as four hard colour blocks with a
   seam running straight behind the logo — not paper. Rebuilt as three bands
   (a letter folded for an envelope, which is how these papers are actually
   carried), with the value steps cut to a few percent and the middle band left
   at exactly the handover colour, so nothing ever changes behind the mark.
3. **C was the boxed grid of a bill.** Rendered, the outlined boxes read as a
   **loading skeleton** — the worst possible association for a splash, since it
   suggests the app is stuck. Replaced outright with the security lattice, which
   is also a different kind of geometry from A and B rather than a third
   rectilinear one.

Two further notes, from `ui-ux-pro-max`:

- Its database flags **continuous decorative animation** ("use for loading
  indicators only") and **more than 1–2 animated elements per view**. The old
  splash's infinitely breathing mark was exactly the first case. Every concept
  here plays **one finite moment and then stops**.
- Motion-duration guidance there explicitly warns against treating any single
  figure as universal, so the three differ (~900 / ~800 / ~920 ms) according to
  what each one is doing rather than sharing one number.

### Deliberately not in the preview

How the splash *leaves*. The exit is F28-T07's, and showing a guess at it would
invite judging something that has not been designed.

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
