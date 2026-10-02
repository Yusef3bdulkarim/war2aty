# F24 · Camera Redesign

- **Branches:** Phase 1 `refactor/remove-live-edge-detection`, based on `develop` · Phase 2 `feature/camera-redesign`, based on `develop` once Phase 1 is merged (or on the Phase 1 branch if design work starts first) · **Milestone:** post-F23
- **Depends on:** F03 (the capture screen), F16 (the live edge detection this feature removes)
- **Supersedes:** [F16 · Live edge detection](F16-live-edge-detection.md)
- **Progress:** Phase 1 — 3 / 7 DONE · Phase 2 — not yet planned
- **PRs:** two, both into `develop` — one for Phase 1 (cleanup), one for Phase 2 (redesign)

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

## Phase 1 — Remove the live document frame

Each task leaves the build and the tests green. Removal runs from the screen
inward (screen → cubit → domain/data) so nothing is ever left pointing at a
deleted file.

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F24-T01 | Branch + docs | Branch `refactor/remove-live-edge-detection` off `develop`; this doc; F16 and `F16-plans/README.md` marked superseded by F24; `README.md` row and dependency note | DONE |
| 2 | F24-T02 | Screen: no overlay, no hint | `CameraCaptureScreen` draws the preview, the close control and the shutter only — no `ViewfinderFrame`, no preview measurement, no hint pill. `viewfinder_frame.dart`, `frame_preview_mapper.dart` and their tests deleted; `cameraViewfinderHint` removed from the strings and `app_strings_test`. Screen tests assert the bare viewfinder | DONE |
| 3 | F24-T03 | Cubit/state: no detection, no guide crop | `CameraReady` carries no document; the cubit no longer starts/stops a frame stream, detects, budgets or crops; `capture()` takes no `guideBox` and hands the photo on unchanged, still cleaning up a stale run's file. `detection_budget.dart`, `detected_document.dart` and the budget test deleted; cubit tests updated | DONE |
| 4 | F24-T04 | Domain/data/DI: no frame stream, no detector | `CameraService` and `PlatformCameraService` lose the frame stream (and the throttle, and the explicit `imageFormatGroup`); the detector, algorithm, tuning, `CameraFrame`, `DocumentQuad`, `UnitPoint` and the `DetectDocumentEdges` / `StartFrameStream` / `StopFrameStream` / `CropToGuideBox` use cases deleted with their tests and DI registrations; the test fake updated | TODO |
| 5 | F24-T05 | Quality gate | `dart format .`, `flutter analyze`, `flutter test` clean; no leftover references to the removed code anywhere in `lib/` or `test/`; `/flutter-code-review` passes | TODO |
| 6 | F24-T06 | Device check | On a physical phone: the camera opens, the shutter takes an upright, sharp photo that reaches the preview screen, background → resume re-opens the camera, and coming back from the preview screen re-arms it. Results recorded below | TODO |
| 7 | F24-T07 | PR #1 | Phase 1 PR into `develop` | TODO |

## Phase 2 — Camera redesign

Planned after Phase 1: three HTML mockup variants → the owner's choice →
`Waraqti.dc.html` updated → the task table for the Flutter work.
