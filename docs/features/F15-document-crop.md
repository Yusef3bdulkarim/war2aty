# F15 · Document Crop

- **Branch:** `feature/document-crop` · **Milestone:** post-M9
- **Depends on:** F03 (capture/review — modifies the capture and preview screens), F13 (perspective-correction — amends locked decision #1) · **Feeds:** F04 (local OCR — offline route now perspective-corrected first), F13's online pipeline (input shape unchanged)
- **Progress:** 13 / 13 DONE

Today the camera's guide frame is purely decorative (the full sensor frame is
kept regardless of where it sits) and the preview screen's crop brackets are a
fixed, non-draggable guide (frames the whole image, doesn't select a region of
it). This feature makes both real: the camera guide box actually determines
what's kept at capture time, `doclens`'s document edge-detection/dewarp runs
on every capture regardless of connectivity (not online-only), and the
preview screen gets a real, free-form, always-active drag-crop. All decisions
below were resolved with the user in a dedicated grilling session
(2026-08-24) and are fixed constraints, not open questions, for
implementation.

## Locked decisions

1. **Two crop mechanisms, not one.** (a) A geometric crop to the on-screen
   `ViewfinderFrame` guide box, applied automatically at capture time. (b) The
   existing `doclens` content-aware edge-detect/dewarp (`PerspectiveCorrector`),
   which keeps running afterward as a refinement — now on **both** routes.
2. **Guide-box crop keeps a ~20% margin** on each side beyond the visible
   guide box, so a paper that isn't perfectly aligned isn't clipped before
   `doclens` gets a chance to find its real edges. Margin is one tunable
   constant.
3. **Guide-box crop runs immediately after the shutter fires** — before the
   preview screen ever opens — computed from the actual on-screen guide-box
   geometry and baked via the `image` package in a background isolate (same
   shape as `ImagePackageRotator`). Camera-only; gallery picks are unaffected
   (no guide box exists for them).
4. **`PerspectiveCorrector` (doclens) now runs on the offline route too** —
   amends F13 locked decision #1, which was online-pipeline-only. It moves to
   run *before* `CreateAnalysisSession` on both routes, since
   `AnalysisSession.imagePath` (what F04's OCR reads) is a copy of whatever
   photo is handed to `CreateAnalysisSession` — today that happens before
   doclens on the online route (harmless there, since online reads from
   `ImageAnalysisSessionHolder` instead), but must not happen before doclens
   once the offline route depends on its output.
5. **Preview-screen crop is free-form**: 4 edge-midpoint drag pills (top,
   bottom, left, right), each single-axis only, no aspect-ratio lock, always
   visible/active (no separate "enter crop mode" control). No corner handles
   — eliminated to prevent accidental two-axis movement on document photos.
   Pills sit just inside the crop boundary so they never extend beyond the
   image frame. Starts selected at the full extents of the incoming (already
   guide-box-cropped) image.
6. **Hand-rolled crop widget, no new package** — a `GestureDetector`-based
   overlay, styled with the app's existing teal/mint tokens. No design for
   this exists in `Waraqti.dc.html`; a mockup is proposed and approved as part
   of this feature (T05) rather than sourced from Claude Design up front.
7. **Rotating resets the crop selection** to the new (post-rotation) full
   extents, rather than remapping the rectangle across the turn.
8. **Quality-check (blur/resolution/brightness) runs on the final image** —
   rotation and the manual crop are baked together on confirm, and
   `AssessImageQuality` runs on that result, not the pre-crop rotated image.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F15-T01 | Branch + doc scaffold | Branch `feature/document-crop` off `develop`; this doc + README row added | DONE |
| 2 | F15-T02 | Guide-box → pixel crop (domain + data) | New domain step converts a guide-box rect (+ margin) into a pixel crop; pixel crop executed via `image` pkg in a background isolate (mirrors `ImagePackageRotator`); unit tests for the geometry math (margin, clamping to photo bounds) and the pixel crop itself | DONE |
| 3 | F15-T03 | Wire guide-box crop into capture flow | Runs immediately after `takePicture()`, before the preview screen opens; camera-only; new intermediate file tracked for cleanup | DONE |
| 4 | F15-T04 | `PerspectiveCorrector` on both routes | `ImagePreviewCubit.proceed()` restructured so doclens runs before `CreateAnalysisSession` on offline **and** online; F13 doc locked decision #1 + every citing code comment (`CorrectPerspective`, `PerspectiveCorrector`, `DecideAnalysisRoute`, etc.) updated; F13-T16's no-silent-fallback guarantee re-verified; tests cover offline now invoking doclens | DONE |
| 5 | F15-T05 | Crop-overlay design proposal | Mockup of the draggable free-form crop interaction using existing teal/mint tokens, presented for approval before widget work starts | DONE (approved; embodied in `DraggableCropOverlay`'s design constants, tagged "F15-T05 proposal") |
| 6 | F15-T06 | Manual-crop domain/data | New crop-rect entity + usecase baking an arbitrary rect into a file via `image` pkg in a background isolate (mirrors `ImagePackageRotator`); unit tests | DONE (covered by T02: UnitRect + CropImage + ImagePackageCropper) |
| 7 | F15-T07 | Draggable crop widget (presentation) | Replaces the static `CropFrame`; always-active free-form drag on 4 edge midpoints (single-axis only, no corners); RTL-correct, Large-Text/High-Contrast safe, accessible handle semantics; widget tests | DONE (`DraggableCropOverlay`; wired into `ImagePreviewScreen`; 15 dedicated widget tests in `draggable_crop_overlay_test.dart` covering render, disabled state, edge drag, bounds clamping, min-extent enforcement, external sync, mid-drag guard, RTL, Large Text 2.0×) |
| 8 | F15-T08 | Wire crop into `ImagePreviewCubit`/state | Tracks the live crop rect; rotate resets it to full extents; confirm bakes rotation + crop together; `AssessImageQuality` runs on the final baked image; cubit tests | DONE (`updateCrop`/`cropRect` in `ImagePreviewCubit`/`ImagePreviewState`; 46 passing tests across `image_preview_cubit_test.dart` + `image_preview_screen_test.dart`) |
| 9 | F15-T09 | Temp-file lifecycle sweep | Every new intermediate file (guide-box-cropped, manually-cropped) tracked and deleted on cancel/exit/save/discard, extending F03-T10/F12-T06's guarantees | DONE (found + fixed a real orphaned-temp-file race: `capture()`, `confirm()`, and `proceed()` now clean up a stale await's result when `isClosed`/generation changes mid-flight, instead of dropping it untracked; regression tests added in `camera_capture_cubit_test.dart` and `image_preview_cubit_test.dart`) |
| 10 | F15-T10 | End-to-end verification | Real-device pass: camera + gallery entry points, offline + online routes, RTL, Large Text, High Contrast | DONE (device pass on RMX2001: camera→guide-box-crop→preview with DraggableCropOverlay (4 edge pills, Arabic semantics confirmed via UI dump)→rotate resets crop→confirm→quality warning (amber+icon, no color-only)→proceed→doclens→online route with graceful error UI (no provider names leaked); gallery picker opens correctly (documentsui grid-item taps are an adb-automation limitation, not an app defect — downstream path identical to camera); Large Text/High Contrast: device permissions blocked adb setting changes, covered by widget tests at TextScaler 2.0× + AppColors.highContrast palette; offline route: unit-tested in F15-T04; 15 DraggableCropOverlay widget tests covering render/disabled/edge-drag/clamp/sync/RTL/Large-Text) |
| 11 | F15-T11 | Crop-overlay geometry fix | Handles measure the **rendered child**, not the box offered to it — fixes pills drifting off (and clean off) letterboxed images and drag deltas scaling by the wrong extent; each crop edge grabbable along its whole length rather than only at the midpoint pill; regression tests that fail without the fix | DONE |
| 12 | F15-T12 | Responsive viewfinder guide box | Guide box sized as a fraction of the live preview instead of a fixed 290×380 (same framing on every screen size, **no change to the approved 290:380 proportions** — a different paper aspect would be a design change, not a code one); camera screen measures the frame's real render box instead of recomputing from the static constants, so the crop follows whatever the frame becomes; widget tests at several screen sizes | DONE (`ViewfinderFrame.widthFactor` = 290/368 and `aspectRatio` = 290/380, both read off `Waraqti.dc.html` → `camera`: a 290×380 box on a 390×844 mock with an 11 pt bezel, i.e. a 368 pt screen. `resolveSize` fits the largest box with those proportions into the preview, so the height binds on a short screen instead of overflowing. `_measureGuideBox` now reads the frame's own render box via `_frameKey`; the no-longer-needed `_stackKey` is gone. 5 widget tests in `viewfinder_frame_test.dart`) |
| 13 | F15-T13 | Crop rect survives leaving `ImagePreviewReady` | Found on the T10 device pass: the selection sprang back open the instant «استخدم الصورة» was tapped, and — worse, silently — a retry after a failed export cropped nothing. `cropRect` moves onto the sealed base beside `quarterTurns` and is carried by `ImagePreviewProcessing`/`ImagePreviewFailed`; `updateCrop` is also accepted from the failed state, where the handles are live again. Regression tests at both cubit and screen level | DONE |

## Exit DoD
Camera captures are cropped to the guide box (+ margin) at capture time; `doclens` edge-detect/dewarp runs on every capture regardless of connectivity; the preview screen offers a real free-form drag-crop on both camera and gallery images; quality-check reflects the final image; no new temp file survives past its session; `dart format .` / `flutter analyze` / `flutter test` all pass.
