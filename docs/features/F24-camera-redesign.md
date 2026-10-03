# F24 · Camera Redesign

- **Branches:** Phase 1 `refactor/remove-live-edge-detection`, based on `develop` · Phase 2 `feature/camera-redesign`, based on `develop` once Phase 1 is merged (or on the Phase 1 branch if design work starts first) · **Milestone:** post-F23
- **Depends on:** F03 (the capture screen), F16 (the live edge detection this feature removes)
- **Supersedes:** [F16 · Live edge detection](F16-live-edge-detection.md)
- **Progress:** Phase 1 — 7 / 7 DONE · Phase 2 — 12 / 12 DONE (T10 waived) · **F24 COMPLETE**
- **PRs:** two, both into `develop` — one for Phase 1 (cleanup, [#25](https://github.com/Yusef3bdulkarim/war2aty/pull/25)), one for Phase 2 (redesign)

The owner's rework of the camera screen, 2026-10-03, in two phases.

**Phase 1 removes the live document frame.** F16 drew corner brackets that
tracked the paper in real time, fed by a pure-Dart edge detector running on the
camera's frame stream. Since F16-T10 the frame no longer decides what the
capture keeps — the whole frame is kept and the user's own crop on the preview
screen is the only crop — so it was guidance only, at the cost of a continuous
frame stream (battery, heat, and contention with the shutter on some Android
devices). The camera becomes a plain, natural camera: the live preview, a close
control, and the shutter. What gets captured does not change.

**Phase 2 redesigns the camera screen** around three new controls, from three
HTML mockup variants the owner chooses between.

## Locked decisions

Resolved with the owner on 2026-10-03.

1. **Everything F16 added goes, not just the overlay.** The detector, its
   algorithm and tuning, the frame stream and its throttle, the perf budget,
   the frame → preview mapping, `DetectedDocument`, `DocumentQuad`,
   `UnitPoint`, `CameraFrame`, their use cases, their DI registrations and
   their tests. `CropToGuideBox` goes too: since F16-T10 every capture passed
   `UnitRect.full`, so it was already a no-op.
2. **Kept:** `UnitRect`, `ImageCropper` / `CropImage` (the preview screen's
   manual crop uses them) and `CleanupCaptureFiles`.
3. **The hint pill is dropped in Phase 1.** Its text («خلي الورقة كاملة داخل
   الإطار.») pointed at a frame that no longer exists. Whether the camera gets a
   hint back is Phase 2's call.
4. **`imageFormatGroup` reverts to the camera plugin's default.** It was set
   explicitly (yuv420 / bgra8888) only so frames could be streamed (F16-T04).
   A photo is written as JPEG either way; T06 re-verifies the shutter on a real
   device.
5. **Preview fit stays as it is:** letterboxed (aspect fit) on the dark
   backdrop, so what is seen is exactly what is captured.
6. **Phase 2 scope:** a flash/torch toggle, a gallery shortcut beside the
   shutter, and tap-to-focus. Pinch zoom and grid lines are out.
7. **Phase 2 design:** strictly Waraqti — its palette, Cairo, Arabic RTL, and
   large touch targets for older users. Three variants are delivered as a
   local standalone HTML file in the repository; the chosen variant is
   committed to `Waraqti.dc.html` **before** any Flutter UI work starts.
   > **Amended 2026-10-03 (owner, decision 1 b).** The committed final page,
   > `docs/design/F24-camera-mockups.html`, is the camera screen's design
   > source, as F23's approved mockups were for its pages. `Waraqti.dc.html` is
   > updated from it whenever convenient. This is no longer a gate on the
   > Flutter work.
8. **Flash on a phone without one (owner, decision 2 b, 2026-10-03).** iOS
   reports a missing flash (`setFlashMode` fails with `setFlashModeFailed`), so
   the button is hidden there. The camera plugin cannot tell on Android
   (CameraX), so Android always shows the button; on a phone without a flash it
   changes the mode and nothing fires. No native code is added.

## Phase 1 — Remove the live document frame

Each task leaves the build and the tests green. Removal runs from the screen
inward (screen → cubit → domain/data) so nothing is ever left pointing at a
deleted file.

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F24-T01 | Branch + docs | Branch `refactor/remove-live-edge-detection` off `develop`; this doc; F16 and `F16-plans/README.md` marked superseded by F24; `README.md` row and dependency note | DONE |
| 2 | F24-T02 | Screen: no overlay, no hint | `CameraCaptureScreen` draws the preview, the close control and the shutter only — no `ViewfinderFrame`, no preview measurement, no hint pill. `viewfinder_frame.dart`, `frame_preview_mapper.dart` and their tests deleted; `cameraViewfinderHint` removed from the strings and `app_strings_test`. Screen tests assert the bare viewfinder | DONE |
| 3 | F24-T03 | Cubit/state: no detection, no guide crop | `CameraReady` carries no document; the cubit no longer starts/stops a frame stream, detects, budgets or crops; `capture()` takes no `guideBox` and hands the photo on unchanged, still cleaning up a stale run's file. `detection_budget.dart`, `detected_document.dart` and the budget test deleted; cubit tests updated | DONE |
| 4 | F24-T04 | Domain/data/DI: no frame stream, no detector | `CameraService` and `PlatformCameraService` lose the frame stream (and the throttle, and the explicit `imageFormatGroup`); the detector, algorithm, tuning, `CameraFrame`, `DocumentQuad`, `UnitPoint` and the `DetectDocumentEdges` / `StartFrameStream` / `StopFrameStream` / `CropToGuideBox` use cases deleted with their tests and DI registrations; the test fake updated (`platform_camera_service_test.dart` only covered the frame builder, so it is deleted whole) | DONE |
| 5 | F24-T05 | Quality gate | `dart format .`, `flutter analyze`, `flutter test` clean; no leftover references to the removed code anywhere in `lib/` or `test/`; `/flutter-code-review` passes. The sweep also caught `UnitRect.expanded`/`clamped` (the guide crop's margin, dead once `CropToGuideBox` went), removed with their tests | DONE |
| 6 | F24-T06 | Device check | On a physical phone: the camera opens, the shutter takes an upright, sharp photo that reaches the preview screen, background → resume re-opens the camera, and coming back from the preview screen re-arms it. Results recorded below — all 9 checks pass (2026-10-03) | DONE |
| 7 | F24-T07 | PR #1 | Phase 1 PR into `develop` — [#25](https://github.com/Yusef3bdulkarim/war2aty/pull/25) | DONE |

## Device pass (F24-T06)

Phone: RMX2001 (Android 11), dev flavor, local Supabase over `adb reverse`.
Run by the owner on 2026-10-03; all nine checks pass.

| # | Check | Expected | Result |
|---|---|---|---|
| 1 | Home → «صوّر ورقتك» | The camera opens to a plain live feed: no corner brackets, no hint pill; close (top-start) and the shutter only | ✅ |
| 2 | Point at a paper and hold still for a few seconds | Nothing is drawn over the feed; no lag or stutter | ✅ |
| 3 | Tap the shutter | One photo; the preview/crop screen opens with the **whole** frame, upright and sharp | ✅ |
| 4 | Back from the preview screen | The camera re-opens live (not stuck on a spinner or a frozen frame) | ✅ |
| 5 | Shutter → crop → continue to analysis | The analysis runs as before (the photo format change does not affect OCR) | ✅ |
| 6 | With the camera open, press Home, then return to the app | The camera releases and re-opens live | ✅ |
| 7 | Lock the screen on the camera, then unlock | Same as #6 | ✅ |
| 8 | Close (✕) | Leaves the camera | ✅ |
| 9 | Large Text (system font size max) | Camera screen unchanged, nothing overflows | ✅ |

## Phase 2 — Camera redesign

Three HTML mockup variants → the owner's choice → `Waraqti.dc.html` updated →
the task table for the Flutter work. No Flutter UI is written before T10.

Mockups: [`docs/design/F24-camera-mockups.html`](../design/F24-camera-mockups.html)
— open it in a browser. All three phones are interactive, and the toolbar puts
them in the same state (ready, light on, focusing, capturing, opening, phone
without a flash, camera error, Large Text ×1.5). A URL hash such as
`#flash,large` preselects a state.

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 8 | F24-T08 | Branch + three mockups | Branch `feature/camera-redesign` off `develop` (after #25). One local standalone HTML file holds three Waraqti variants (A native minimal, B labelled elderly-first, C floating capsule), each with the light toggle, the photos shortcut beside the shutter and tap-to-focus. The feed stays Fit. Every control is ≥ 48 × 48 and no state is shown by colour alone; states are RTL, Large Text, opening, error and no flash | DONE |
| 9 | F24-T09 | The owner's pick | The owner chooses a variant (or a mix) and answers the open behaviour questions listed at the bottom of the mockup page | DONE — see [T09 decisions](#t09-decisions-2026-10-03) |
| 10 | F24-T10 | Waraqti design updated | The final design is committed to `Waraqti.dc.html` | **WAIVED** — locked decision #7 amended: the committed page is the design source; `Waraqti.dc.html` is updated from it whenever convenient |
| 11 | F24-T11 | Domain: flash, focus, capabilities | `CameraFlashMode` (off / auto / on), `CameraCapabilities` (has a flash, can focus) and a normalised `FocusPoint` (0..1, validated). `CameraService.initialize` returns the capabilities and gains `setFlashMode` and `focusAt`. New `SetCameraFlash` and `FocusCamera` use cases; `InitializeCamera` passes the capabilities through. Pure Dart; tests for `FocusPoint` and the use cases; the test fake updated. Until T13, `PlatformCameraService` reports `CameraCapabilities.none` and refuses flash/focus, which matches today's screen | DONE |
| 12 | F24-T12 | Cubit/state | `CameraReady` carries the flash mode, whether there is a flash, and whether focus is supported. `start()` always lands on flash off, so a retake resets it. `cycleFlash()` moves off → auto → on (a no-op without a flash; a failure keeps the old mode). `focusAt()` is ignored unless ready and supported, and its failure is silent (guidance only). Both keep the generation guard. Cubit tests. `CameraReady` and `CameraCapturing` share a `CameraLive` parent, so the dock reads the same fields mid-shot | DONE |
| 13 | F24-T13 | Data: `PlatformCameraService` | After every open, the controller is set to `FlashMode.off`: the plugin starts in auto. Flash support: iOS detects it from a failing `setFlashMode`; Android always reports a flash (locked decision #8). Focus support comes from `focusPointSupported`; `focusAt` sets the focus point, and the exposure point where supported. `CameraException` maps to a typed failure, never thrown. The plugin-free mapping is unit-tested. The probe is the same `setFlashMode(off)` call that forces the flash off: iOS refuses every mode, off included, on a lens without a flash | DONE |
| 14 | F24-T14 | Shared icons + strings | `StrokeGlyph.flash`, `flashOff` and `flashAuto` join the shared icon set. New strings: «الفلاش: مطفي / تلقائي / شغال», the focus hint «المس الورقة علشان تبقى واضحة», and «اختار صورة من الموبايل» on the camera. `actionBack` and `StrokeGlyph.gallery` are reused. `app_strings_test` updated. `cameraCloseLabel` goes in T15, when the back arrow replaces the ✕ | DONE |
| 15 | F24-T15 | Screen | `CameraCaptureScreen` rebuilt to the final design: `TealTopBar`, the full-width Fit feed, and the dock (status line + capsule) floating over the feed's bottom (layout option b, below), with a soft grey shadow around the capsule. Also: the focus brackets at the tapped point; the hint once per visit (screen state, so a retake or retry does not bring it back); the flash chip for 2 s; no flash button without a flash, with the shutter kept centred; the error page with «اختار صورة من الموبايل»; the bar on the opening and error states. Widget tests: RTL, Large Text, no flash, flash cycle, the tap → normalised point, hint once per visit across `didPopNext`, the error buttons. Split into `FocusablePreview`, `CameraStatusLine` and `CameraCapsule` under `presentation/widgets/`. `cameraCloseLabel` is removed | DONE |
| 16 | F24-T16 | Router | The photos shortcut and the error page's button replace the camera route with the gallery route (`pushReplacement`, as the permission sheet already does), so Back returns Home. Landed in the T15 commit, since the screen's new callback would not compile without it | DONE |
| 17 | F24-T17 | Quality gate | `dart format .`, `flutter analyze`, `flutter test`; `/flutter-code-review`; `@code-reviewer`. The self-review fixed the disc buttons' screen-reader tap and the hint showing where focus does not work. `@code-reviewer` passed; its two nits were fixed (the flash label now fades out, and the hidden hint is not read) | DONE |
| 18 | F24-T18 | Device check | Real phone: flash off / auto / on actually fires (or doesn't); reset to off after a retake; tap-to-focus sharpens the tapped area; hint once per visit; the photos shortcut; no-flash handling; error page; RTL, Large Text. Owner's pass on the RMX2001: 12 / 12 ✅ | DONE |
| 19 | F24-T19 | PR #2 | Phase 2 PR into `develop` — [#26](https://github.com/Yusef3bdulkarim/war2aty/pull/26) | DONE |

### T09 decisions (2026-10-03)

The owner picked **variant C** as the base, with these changes:

- **Smaller controls:** shutter 78 → 68; photos and flash discs 52 → 44, keeping 48 × 48 tap areas.
- **Top bar:** C's top row is replaced with the app's `TealTopBar` (the analysis and failure pages' bar: colour and style).
- **The space around the feed:** proposals for making it look purposeful, plus colour suggestions for the bar and the bottom area.

Answers to the six behaviour questions:

1. **Flash**, not a torch: off / auto / on, firing with the shutter.
2. **Photos button:** a plain icon, so there is no early photo-library permission.
3. **Hint:** yes — a subtle, auto-hiding focus hint.
4. **Camera error page:** «اختار صورة من الموبايل» goes under «حاول تاني».
5. **Phone without a flash:** the flash button is hidden completely.
6. **After a shot:** the flash resets to off on returning to the camera.

Final picks on the refined page:
- **Layout:** C2, edge-to-edge.
- **Top bar:** brand teal, exactly as `TealTopBar`.
- **Bottom:** glass capsule.
- **Hint:** **once per camera visit**, not again after a retake.

`docs/design/F24-camera-mockups.html` now shows only this final design, with its spec. The earlier A / B / C and option pages are in git history (`64026cd`, `c7a0ab0`).

### Layout decision after the first device run (2026-10-03)

On Android the camera plugin gives a 16:9 picture (`ResolutionPreset.high`, 1280×720), not the 3:4 the mockup assumed. No usable 4:3 preset exists: `low` is 320×240, and `max` is the RMX2001's full 64 MP sensor. At full width, a 16:9 feed leaves too little room below it for the dock.

The two options were:
- **(a)** shrink the feed, which leaves bands down the sides
- **(b)** keep the feed full width and float the dock over its bottom

**The owner chose (b).** The feed stays Fit, full width under the bar, and the status line and capsule sit over roughly the bottom 100dp of the picture.

The owner then removed the dark fade that sat behind the dock, so the controls float straight on the feed. Instead, the capsule has a soft shadow in the backdrop grey (`#111417` at 22%, blur 12, outside the shape only). The grey strip below a 16:9 feed is kept as it is: filling it would crop the preview's sides, and the owner chose not to.

The mockup page still shows the C2 3:4 frame. This section overrides it for the feed's height.

## Device pass (F24-T18)

Phone: RMX2001 (Android 11), dev flavor, local Supabase over `adb reverse`.

| # | Check | Expected | Result |
|---|---|---|---|
| 1 | Home → «صوّر ورقتك» | Teal bar with the back arrow; the feed full width under it; the capsule (photos · shutter · flash) floating over the feed's bottom | ✅ |
| 2 | Wait on the camera | The hint «المس الورقة علشان تبقى واضحة» shows and fades after ~4 s | ✅ |
| 3 | Tap a spot on the paper | White corner brackets at that spot; the area sharpens | ✅ |
| 4 | Tap ⚡ three times | Icon: slashed → bolt with «A» → bolt on mint, then back to slashed. «الفلاش: …» spelled out for ~2 s each time | ✅ |
| 5 | Flash **on** → shutter | The flash fires; the photo reaches the crop screen upright and sharp | ✅ |
| 6 | Flash **auto** → shutter, in a dim room and then a bright one | Fires in the dark, not in bright light | ✅ |
| 7 | Back from the crop screen (retake) | The camera re-opens with the flash **off**, and the hint does **not** come back | ✅ |
| 8 | The photos button | The phone's photo picker opens; Back from it returns Home, not to the camera | ✅ |
| 9 | Back arrow in the teal bar | Leaves the camera | ✅ |
| 10 | Home button / lock, then return | The camera re-opens live, the flash off | ✅ |
| 11 | TalkBack: swipe to the flash and photos buttons, double-tap | Each is read («الفلاش: مطفي», «اختار صورة من الموبايل») and works | ✅ |
| 12 | Large Text (system font size max) | Nothing overflows | ✅ |
