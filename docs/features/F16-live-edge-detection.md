# F16 · Live Document Edge Detection

- **Branch:** `feature/live-edge-detection` (off `feature/document-crop`) · **Milestone:** post-M9
- **Depends on:** F15 (the guide box and the guide-box crop it feeds), F03 (the capture screen), F13 (`PerspectiveCorrector`/`doclens`, which stays the source of geometric truth) · **Feeds:** nothing — this is a guidance layer on top of an already-working pipeline
- **Progress:** 9 / 10 DONE
- **Per-task plans:** [`F16-plans/`](F16-plans/README.md) — one implementation plan per task, written before work starts

F15-T12 made the camera's guide box *responsive* — the same share of the
preview on every screen. It still does not know where the paper is: it sits in
the middle of the screen and the user moves the paper to it. This feature
turns that around, so the guide follows the document in real time, the way a
scanner app does.

The safety of doing this rests on one observation, which is what makes it an
additive feature rather than a rewrite: **`doclens` already re-detects the
real edges on the captured file and dewarps them (F15 locked decision #4).**
The live detector therefore only has to be good enough to *aim the user*, not
to be exact — nothing downstream trusts its numbers.

## Locked decisions

Decisions 1–5 were resolved with the user in the session that opened this
feature (2026-08-28) and are fixed constraints. The rest of the design lives
in the task rows.

1. **Guidance, not geometry.** The detected quad drives what is *drawn*. The
   capture crop stays a `UnitRect` (the guide box's bounding rect + the 20%
   margin of F15 locked decision #2), and `doclens` keeps doing the real
   edge-detect/dewarp on the file afterwards. F15's pipeline is not
   restructured.
2. **Pure-Dart detector, no new package.** Detection runs on the camera's luma
   plane in-process. No OpenCV, no native detector, and specifically no
   third-party scanner package — those ship their own full-screen camera UI,
   which would replace this app's Arabic/RTL capture screen and re-open F13
   locked decision #10.
3. **Nothing touches the disk.** Frames are read from the stream, used, and
   dropped in memory. No temp files, no JPEG encoding, nothing to clean up —
   the privacy contract gains no new surface. (This is what rules out the
   otherwise-attractive option of calling `doclens`'s file-based
   `detectInImage` on sampled frames.)
4. **Graceful degradation is the default, not an error path.** "No document
   found", an unsupported format, a stream that won't start, or detection
   being switched off all fall back to F15-T12's static responsive box. The
   user is never shown a detection failure.
5. **The detector sits behind a domain interface** (`DocumentEdgeDetector`),
   mirroring `PerspectiveCorrector`: interface in `domain/services`,
   implementation in `data/services`, reached from the cubit through a use
   case. Never called from a widget.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F16-T01 | Branch + doc scaffold | Branch `feature/live-edge-detection` off `feature/document-crop`; this doc + `docs/features/README.md` row added | DONE |
| 2 | F16-T02 | `DocumentQuad` entity + detector interface | Immutable 4-corner quad in normalised (0..1) frame coordinates, with `boundingRect` → `UnitRect` and ordering/validity helpers (convex, non-degenerate, corners sorted TL/TR/BR/BL); `DocumentEdgeDetector` interface in `domain/services`, pure Dart, returns `Result<DocumentQuad?, AppFailure>`; unit tests for the geometry helpers | DONE |
| 3 | F16-T03 | Pure-Dart detector | Luma plane → downscale (~160×120) → blur → Sobel → binarise → largest convex quad; runs in a background isolate; deterministic, injectable thresholds; unit tests against synthetic luma buffers (clean page, rotated page, no page, low contrast) rather than real photos | DONE |
| 4 | F16-T04 | Camera stream plumbing | `imageFormatGroup` switched to a streamable format per platform (yuv420 / bgra8888) in `PlatformCameraService` with `takePicture` re-verified against the change; stream started/stopped with the existing lifecycle wiring; stream stopped before the shutter fires; frames throttled and **dropped** while a detection is in flight (never queued) | DONE (device shutter re-verification carried into T10 — a runtime pass needs the LAN Supabase dev setup; `flutter build apk --debug` passes with the new format group) |
| 5 | F16-T05 | Frame → preview coordinate mapping | Detector output is in sensor space; map it into the preview widget's rect accounting for sensor orientation, front/back mirroring, and how `CameraPreview` fits the feed. Shares the preview-rect measurement already used by `_measureGuideBox`. Unit tests per orientation | DONE |
| 6 | F16-T06 | Guide box follows the quad | `ViewfinderFrame` draws the detected quad (brackets on its corners) and interpolates toward each new detection so it doesn't jitter; a detection that drops out briefly holds the last quad instead of snapping; falls back to the F15-T12 static box per locked decision #4. Widget tests incl. RTL, Large Text, High Contrast | DONE |
| 7 | F16-T07 | Cubit/state wiring | Detection state exposed through the capture cubit via a use case (locked decision #5); no `BuildContext` in the cubit; detection lifecycle tied to the camera's; cubit tests | DONE |
| 8 | F16-T08 | Crop follows the visible guide | When a quad is being shown, the guide-box crop uses **its bounding rect** (+ the existing 20% margin) so what was framed is what is kept; falls back to the static box otherwise. Extends F15-T12's render-box measurement rather than re-deriving geometry; tests | DONE |
| 9 | F16-T09 | Perf & thermal guard | Detection auto-disables (silently, per locked decision #4) when frames are consistently late or the isolate can't keep up; measured frame budget documented; no jank on the shutter path | DONE (device numbers land in T10) |
| 10 | F16-T10 | Device verification | Real-device pass over real documents: white page on a light desk (the hard case), angled, partially shadowed, low light, a receipt, a page with a coloured border; RTL, Large Text, High Contrast; battery/heat sanity over a few minutes of continuous preview | **PARTIAL** — see [Device pass](#device-pass-f16-t10). Verified on RMX2001/Android 11: T04's carried-over shutter check passes, the YUV frame stream is genuinely live (~30 fps, 9,061 frames over 5 min), the no-document fallback holds, RTL/Large Text/High Contrast all pass, thermals plateau near 40 °C, and the perf guard never fired. **Open:** the eight real-paper scenes — the detector has never been observed locking onto an actual document, only its no-document fallback — and battery drain off-charge |

## Measured budget (F16-T09)

The guard's numbers, and what they were set against.

| | |
|---|---|
| Frame budget | **120 ms** — one detection, matched to F16-T04's throttle interval (~8 frames/s admitted, the rest dropped) |
| Downscale | ~160×120, nearest-neighbour, stride-aware |
| Algorithm, desktop (Windows, 1280×960 frame) | **~1.7 ms** median |
| Algorithm + `Isolate.run` round trip, same machine | **~1.9 ms** median |
| Isolate strategy | `Isolate.run` per frame, bytes shipped as `TransferableTypedData`. The measured spawn+transfer overhead is ~0.2 ms — about 0.2% of the budget — so a persistent worker isolate was **not** needed. If the device pass shows otherwise, only `DartDocumentEdgeDetector` changes; T03 keeps the algorithm in a separate pure file for exactly this |
| Auto-disable | median over budget across 10 detections, **or** 5 consecutive detections over 2× budget. Silent: stream stops, guide returns to the static box, nothing shown or logged (locked decision #4). Reopening the camera clears it |
| Device numbers (RMX2001, Android 11) | camera screen at 266% of 800% CPU on a profile build (276% on debug — so this is the camera pipeline, not Dart); YUV stream sustained ~30 fps for 5 min with the guard never firing; thermals plateau near 40 degrees C. The detection work was not isolated from the camera baseline, so that figure is the screen total, not F16 cost |

## Device pass (F16-T10)

Run on **RMX2001, Android 11**, dev flavor, against the local Supabase stack
reached over USB via `adb reverse tcp:54321` (the phone's Wi-Fi was on a
different network, and the reverse tunnel removes the LAN dependency from the
dev-run recipe entirely). Both a **debug** and a **profile** build were
exercised.

### Verified on the device

| Check | Result |
|---|---|
| Launch → splash → home | Passes; anonymous auth reaches the local stack |
| Live preview under the new `imageFormatGroup` | Runs; no error in logcat |
| **T04's carried-over shutter check** | **Passes** — shutter fires, the JPEG comes back upright and correctly sized, and the crop screen opens on it. This was the one real regression risk in F16 |
| Guide-box crop still applied | The captured image is the guide box + the 20% margin, as before F16 |
| Frame stream genuinely live | `dumpsys media.camera` shows three output streams: `ImageReader 1280×720 format 0x11` (YUV_420_888 — the detection stream), `0x21` (JPEG still), `0x23` (preview). The YUV stream produced **9,061 frames over 5 minutes (~30 fps)** |
| Throttle behaviour | The camera offers ~30 fps; `FrameThrottle` admits ~8/s and drops the rest, exactly as designed |
| No-document fallback (locked decision #4) | The scene held no paper, and the guide stayed as F15-T12's static box for the whole run — never a flicker, never an error |
| RTL | Correct throughout |
| Large Text («كبير جدًا») | Guide geometry unchanged; the Arabic hint scales and still fits its pill; no overflow. Set through the app's own setting (F11-T05) rather than system settings, which is what F15-T10 could not do |
| High Contrast («تباين عالي») | Brackets take the high-contrast palette; state is still carried by the brackets' shape and position, never by colour alone |
| Perf-guard did **not** fire | The YUV stream never stopped across the 5-minute soak, so `DetectionBudget` never silently disabled detection — the phone kept inside budget |

### Thermal / battery soak — 5 minutes of continuous preview + detection

| t | battery temp | YUV frames |
|---|---|---|
| 0 min | 38.1 °C | 1,889 |
| 1 min | 38.7 °C | 3,701 |
| 2 min | 39.3 °C | 5,447 |
| 3 min | 39.8 °C | 7,258 |
| 4 min | 40.0 °C | 9,129 |
| 5 min | 40.2 °C | 10,950 |

The rise flattens (+0.6, +0.6, +0.5, +0.2, +0.2 °C per minute) — a plateau near
40 °C rather than a runaway — and the phone fell back to 39.1 °C within a
minute of leaving the camera. **Battery drain was not measurable on this run:
the phone was on charge throughout (24% → 28%), so that half of the check is
still open.**

App CPU on the camera screen: **266%** of 800% (8 cores) on the profile build,
276% on debug — the closeness of the two says this is the camera pipeline and
the YUV stream delivery, not Dart. On the home screen the app sits at 0%. The
detection work itself was not isolated from the camera baseline (that would
need a build with the stream removed), so this number is *the camera screen's
total*, not the cost F16 adds.

### Still open — needs paper in front of the lens

The eight real-document scenes are the heart of this task and **cannot** be
substituted by anything above: white page on a light desk (the hard case F16's
Risks names), angled, partially shadowed, low light, a receipt, a page with a
coloured border, and a no-document control. Nothing in this run ever put a
document in frame, so **the detector has never been observed locking onto a
real page** — only its correct no-document fallback. Whether the quad tracks,
jitters, or flickers is unmeasured. Battery drain off-charge is likewise still
open. Checklist: [`F16-plans/F16-T10.md`](F16-plans/F16-T10.md).

## Risks

- **Accuracy on low contrast** (a white page on a pale surface) is the known
  weak point of a hand-rolled detector and cannot be settled before T10.
  Locked decision #4 is what keeps that from being a functional regression —
  the worst case is the box we ship today.
- **`imageFormatGroup` (T04)** is the only change that touches the working
  capture path. It is isolated in its own task so it can be reverted alone.
- **Thermal/battery** — continuous per-frame work on a preview is the classic
  source of both; T09 exists to bound it.

## Exit DoD
The guide follows a document on the preview and stops following it cleanly
when there is none; the capture crop matches what the guide showed; no frame
is ever written to disk; no new package; detection failure is invisible to the
user and leaves today's behaviour intact; `dart format .` / `flutter analyze` /
`flutter test` all pass.
