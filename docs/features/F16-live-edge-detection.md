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
   > **Amended after T10 (2026-08-31).** F16-T08 read "the guide box" as the
   > *detected* quad and pointed the crop at it. On a real device a collapsed
   > detection then cropped a capture down to a strip and discarded ~85% of the
   > page. The crop is now always the **static** box; the quad is drawn over it
   > and never decides what is kept. Read this decision literally: the quad
   > drives what is drawn, and only that.
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
| 8 | F16-T08 | Crop follows the visible guide | When a quad is being shown, the guide-box crop uses **its bounding rect** (+ the existing 20% margin) so what was framed is what is kept; falls back to the static box otherwise. Extends F15-T12's render-box measurement rather than re-deriving geometry; tests | **REVERTED** — shipped, then undone after the T10 device pass found it cropping ~85% of a real page away. The crop is the static box again; `frameKey` rides on it whatever the detector sees. Tests now assert the inverse, including a regression test built from the collapsed quad T10 caught |
| 9 | F16-T09 | Perf & thermal guard | Detection auto-disables (silently, per locked decision #4) when frames are consistently late or the isolate can't keep up; measured frame budget documented; no jank on the shutter path | DONE (device numbers land in T10) |
| 10 | F16-T10 | Device verification | Real-device pass over real documents: white page on a light desk (the hard case), angled, partially shadowed, low light, a receipt, a page with a coloured border; RTL, Large Text, High Contrast; battery/heat sanity over a few minutes of continuous preview | **PARTIAL** — see [Device pass](#device-pass-f16-t10). All infrastructure legs pass (T04 shutter, live YUV stream, fallback, RTL/Large Text/High Contrast, thermals, perf guard). Found, fixed and re-verified on-device the blocking crop defect (T08 reverted). Detection quality characterised: shadow and skew are the real weak points; white-on-light — the *documented* weak point — is the best case. **Left:** low light, a receipt, and a coloured-border page; battery drain off-charge |

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

### Real-document scenes

Run over two handwritten notebook pages on three surfaces, ~20 preview frames
and 4 captures.

| Scene | What the guide did |
|---|---|
| Page on a cluttered surface (laptop + patterned fabric) | Locks on and tracks, but corners collapse inward — the quad is often a wedge covering 60% of the page rather than its rectangle |
| Page on a plain dark desk, hard shadow across it | **Worst case.** Same wedge failure, and unstable frame to frame: two samples three seconds apart on a near-static scene gave a large wedge and then a sliver over ~15% of the page |
| White page on a white textured surface, square-on, even light | **Best case** — a clean, accurate, stable rectangle inset a few percent from the page edge, holding steady across the burst |
| Dark/empty scene | Correct fallback to the static box, no wild quad |

The documented expectation is inverted: **low contrast was not the weak point.**
A white page on a white sheet gave the cleanest detection of the whole run. The
real weak points are a **hard shadow across the page** and **perspective skew**,
neither of which F16's Risks anticipated. The likely mechanism is the
largest-connected-component step swallowing the shadow boundary as if it were
part of the page outline, which then drags a hull vertex and survives the
reduce-to-four-corners step.

### Defect found: the crop can discard most of the document

**On a capture taken moments after a clean full-page detection, the kept image
was a narrow horizontal strip — the last two lines of the page. The top ~85%,
which held all of the content, was gone.**

The arithmetic leaves only one explanation: a collapsed quad drove the crop. The
static box would have produced a tall portrait region, and `UnitRect.full` would
have kept the whole photo; only a quad bounding rect can produce a ~4:1 strip.
T08's minimum-extent guard did not catch it, because a strip that spans most of
the frame's width and ~15% of its height clears a 10%-per-axis floor.

This is a **functional regression against F15**, where the crop was the static
box the user had aligned the paper to. It is not recoverable downstream: F15-T04
runs `doclens` *after* the guide-box crop, and the preview screen's drag handles
can only shrink the selection further, so the discarded pixels are gone before
anything else sees them. It is also silent — nothing tells the user their
document was cut.

The safety argument in F16 locked decision #1 (an imperfect quad is harmless
because the crop keeps a 20% margin) holds only while the quad is roughly
page-shaped. A 20% margin on a sliver is still a sliver. Two earlier captures on
visibly-wrong-but-page-sized quads did keep the whole page, which is why this
did not show up until a quad collapsed.

**This needs a decision before F16 ships** — see the Risks section.

### Fix verified on the device

After reverting T08, the same build was reinstalled on the RMX2001 and the
camera pointed at a page on a cluttered surface. The detector produced another
badly-wedged quad — and the guide now shows **both**: the static box the user
aligns to, with the detected quad painted over it. Firing the shutter on that
frame kept **the whole page**, margins and all. The failure mode that discarded
85% of a page is closed.

### Still open

- **The crop defect above** — open, and blocking. See Risks.
- **Battery drain off-charge** — the phone was on charge for the whole soak.
- **Remaining scenes** — low light, a receipt, and a page with a coloured
  border were not reached; the run stopped once the crop defect was reproduced,
  since that decides whether the feature ships at all.

Checklist: [`F16-plans/F16-T10.md`](F16-plans/F16-T10.md).

## Risks

- **The crop following the quad was unsafe at the detector's current quality
  (found in T10 — RESOLVED by reverting T08).** A collapsed detection cropped a real capture down to a
  narrow strip and silently discarded ~85% of the page. Whichever way this is
  resolved, it must be resolved before F16 ships. The options:
  1. **Revert T08** — the quad becomes purely what is *drawn*, and the capture
     crop goes back to the static guide box. Costs the "what was framed is what
     is kept" promise, restores F15's behaviour exactly, and is the smallest
     change.
  2. **Gate the crop on a plausible, settled quad** — require a minimum area
     against the *preview* (not just 10% per axis), a document-like aspect
     ratio, and N consecutive similar detections before the quad is allowed to
     drive the crop; otherwise fall back to the static box. Keeps the feature,
     adds a real stability requirement the current detector may not meet.
  3. **Fix the detector first** — the shadow/skew failure is the root cause;
     until corner accuracy and frame-to-frame stability improve, any crop built
     on it inherits the risk.

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
