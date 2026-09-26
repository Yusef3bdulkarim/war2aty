# F17 · OCR Accuracy — Capture Fidelity & Handwriting Awareness

- **Branch:** `feature/ocr-accuracy` (off `develop`) · **Milestone:** post-F16
- **Depends on:** F13 (Azure `prebuilt-read`, the confidence/verification pipeline), F04 (`ImageQualityService`), F15 (`PerspectiveCorrector`, on `doclens`'s `detectInImage`/`warpImage` — unaffected, see Context §4) · **Feeds:** nothing — this raises the fidelity of an already-working pipeline
- **Progress:** 0 / 4 phases DONE
- **Gate protocol:** no phase begins until the previous phase's gate is **signed off by the user**. See [Gate protocol](#gate-protocol).

The app reads Egyptian paperwork. It reads printed bills acceptably. It reads
**handwritten** pages badly, and — more dangerously — it has no way of knowing
that it read them badly, so it presents an unreliable reading with the same
confidence as a reliable one.

This feature does **not** add an image-enhancement stage. Investigation
(2026-09-09) found that the enhancement work originally proposed would have
*lowered* accuracy, and that the two real causes lie elsewhere: the camera
captures at roughly a tenth of the resolution the OCR model needs, and the
confidence machinery that already exists uses a single threshold that
collapses on handwriting.

---

## Context

Three findings, all verified against the code on 2026-09-09, reframe the work.

### 1 · Arabic handwriting is already supported — by the exact model we call

Azure Document Intelligence **v4.0** added Arabic to the handwritten-text
language set. The app is already on that version and model:

| Setting | Value | Source |
|---|---|---|
| Model | `prebuilt-read` | [`azure-client.ts:31`](../../supabase/functions/_shared/azure/azure-client.ts#L31) |
| API version | `2024-11-30` (v4.0 GA) | [`azure-client.ts:30`](../../supabase/functions/_shared/azure/azure-client.ts#L30) |
| Locale forced? | No — auto-detect | [`azure-client.ts`](../../supabase/functions/_shared/azure/azure-client.ts) sends no `locale` |

Handwritten languages in v4.0: `en`, `zh-Hans`, `fr`, `de`, `it`, `th`, `ja`,
`ko`, `pt`, `es`, `ru`, **`ar`**. v3.1 and earlier had no Arabic — being on
v4.0 is what makes this feature possible at all.

Not forcing a locale is correct and must stay that way. Microsoft's guidance:

> *"Don't provide the language code as the parameter unless you are sure of the
> language and want to force the service to apply only the relevant model.
> Otherwise, the service may return incomplete and incorrect text."*

Egyptian paperwork is routinely mixed Arabic/English, so a forced locale would
actively hurt. **No task in this feature adds a locale parameter.**

### 2 · The camera captures at ~90 DPI

[`platform_camera_service.dart:63`](../../lib/features/capture/data/services/platform_camera_service.dart#L63):

```dart
final controller = CameraController(
  back,
  // High enough for legible OCR without the memory cost of max — the
  // paper only has to be readable, not print-quality.
  ResolutionPreset.high,
```

The comment's premise is wrong. `ResolutionPreset.high` is **720p**:

| Preset | Pixels | A4 equivalent | Verdict for handwriting |
|---|---|---|---|
| `high` ← **current** | 1280×720 (0.92 MP) | ~90 DPI | Unusable |
| `veryHigh` | 1920×1080 (2.07 MP) | ~130 DPI | Marginal |
| `ultraHigh` | 3840×2160 (8.29 MP) | ~270 DPI | Good |
| `max` | Sensor maximum | Varies wildly | Unbounded — see risk below |

The arithmetic, which needs no vendor claim to stand: a portrait A4 page is
11.69 inches tall, so filling a 720-line frame puts it at roughly **60–110 DPI**
depending on orientation, against **185–260 DPI** at `ultraHigh`. Arabic
handwriting at 90 DPI resolves to roughly 15–25 pixels of x-height — the range
where stroke joins and dot placement, which is what distinguishes ب/ت/ث and
ج/ح/خ, stop being separable at all. No post-processing recovers information the
sensor never recorded.

> An earlier draft of this document asserted that Azure requires a text line
> "at least ~50 px tall". That conflated the documented minimum *image* size
> (50×50 px) with a line-height recommendation, and is withdrawn. The DPI
> arithmetic above is the argument; it does not depend on it.

This also puts the capture pipeline in direct contradiction with its own
quality gate. [`dart_image_quality_service.dart:41-46`](../../lib/features/capture/data/services/dart_image_quality_service.dart#L41):

```dart
static const _resGood = 2000000;        // 2 MP
static const _resAcceptable = 1000000;  // 1 MP
```

A 0.92 MP capture scores **below `_resAcceptable`**, and `_worst()` takes the
minimum across blur/resolution/brightness — so on Android `overall` may be
permanently `poor`. The constants carry the comment *"educated guesses, tuned
later against real Egyptian documents"*; that tuning never happened.

> ⚠️ **Unconfirmed on iOS.** `AVCaptureSessionPresetHigh` can yield a
> higher-resolution still than its preview. On-device testing should confirm
> both platforms before thresholds are changed.

### 3 · The confidence pipeline is built — and has one global threshold

An earlier reading of this codebase claimed per-word confidence was discarded.
That was wrong. It is wired end to end:

| Layer | Location | Status |
|---|---|---|
| Per-word confidence extraction | [`azure-client.ts:94`](../../supabase/functions/_shared/azure/azure-client.ts#L94) `flattenWords()` | Built |
| Per-field verdicts | [`field-verification.ts`](../../supabase/functions/_shared/verification/field-verification.ts) (F13-T06) | Built |
| `needsUserReview` decision | [`cross-provider-validator.ts`](../../supabase/functions/_shared/verification/cross-provider-validator.ts) (F13-T08) | Built |
| UI treatment | [`confidence_band.dart`](../../lib/core/documents/confidence_band.dart), [`value_caveat.dart`](../../lib/core/widgets/value_caveat.dart), [`caveat_badge.dart`](../../lib/core/widgets/caveat_badge.dart) | Built |

What is genuinely missing is **one signal**: Azure returns
`analyzeResult.styles[].isHandwritten`, and a repo-wide search finds **zero**
references to `styles` or `isHandwritten` anywhere in `supabase/` or `lib/`.

That omission hides a latent defect in
[`field-verification.ts:58`](../../supabase/functions/_shared/verification/field-verification.ts#L58):

```ts
export const VERIFIED_CONFIDENCE_THRESHOLD = 0.85;
```

One global threshold. Arabic handwriting routinely scores **0.60–0.80 while
being read correctly**. On a handwritten page every field therefore falls to
`unverified`, every value gets a caveat, and the UI's careful distinction
between a trustworthy amount and a doubtful one carries no information.

**A warning on everything is a warning on nothing.** This defect is invisible
on printed documents, which is why it has not surfaced.

### 4 · F16's on-screen paper-edge guide is cancelled — its frame pipeline stays for Phase 3

**Decision (2026-09-11, this session):** the guide cannot be made to land on
the paper's real edges reliably — on-device it drifts and snaps to a sliver
often enough that it misleads more than it helps. So the **user-visible
guide** is cancelled: `ViewfinderFrame` (the animated mint-bracket overlay),
the quad-matching algorithm behind it (`DocumentEdgeAlgorithm` /
`DartDocumentEdgeDetector` / `DocumentQuad`), the `detect_document_edges` and
`crop_to_guide_box` use cases, and the sensor-to-widget mapping that draws it
(`frame_preview_mapper.dart`) are all removed. This is an F16 decision,
recorded here because it touches a premise Phase 3 of *this* feature depends
on.

**What stays, and must be made correct rather than deleted:** the live
camera-frame pipeline underneath the guide —
[`platform_camera_service.dart`](../../lib/features/capture/data/services/platform_camera_service.dart)'s
`startFrameStream`/`CameraFrame`/`FrameThrottle` — is general-purpose, not
specific to edge-matching, and Phase 3 needs exactly this: per-frame access to
compute sharpness. Nothing here removes it; T20 builds on it.

This also resolves the open question Phase 3 was blocked on. F16 locked
decision #2 already committed to **pure Dart, no new package** — the
edge-matching algorithm ran entirely on the app's own `camera`-plugin frames,
never on `doclens`'s native detection stream (a repo-wide search confirms
`DoclensPlatform.detectionEvents()` is called **nowhere** in `lib/`; `doclens`
is only ever used for `detectInImage`/`warpImage`, both pure file operations
with no camera session — so F15's `PerspectiveCorrector` is untouched by any
of this). With the app's own frame stream being kept anyway, T20 computes
sharpness (variance-of-Laplacian) directly on those frames — no second,
parallel native camera session needed.

### What this feature deliberately does not do

`warpImage()` in
[`doclens_perspective_corrector.dart:40`](../../lib/features/capture/data/services/doclens_perspective_corrector.dart#L40)
is called without an `enhancement` argument, so it defaults to
`ImageEnhancement.none`. **This is correct for the OCR path and stays.**

Adaptive thresholding, "magic color", and binarisation are pre-deep-learning
techniques built for engines like Tesseract that classify glyph shapes after
binarisation. Azure v4.0 is trained on natural photographs, and binarising
destroys the two signals handwriting recognition depends on most: pen-pressure
stroke gradient, and faint strokes (pencil, dry ink) that fall below the
threshold and vanish outright.

Enhancement appears in this feature exactly once — in Phase 4, on a **separate
rendition shown to the user**, never on the bytes sent to Azure.

---

## Locked decisions

1. **No image enhancement on the OCR path, ever.** The bytes sent to Azure are
   geometry-corrected only (perspective + rotation). No binarisation, no
   thresholding, no "magic color", no sharpening. Phase 4 introduces a second
   rendition for display; a test must prevent it from reaching the wire.
2. **No forced locale.** `prebuilt-read` auto-detects. Egyptian paperwork is
   mixed-script and a locale parameter would degrade it.
3. **Every change is justified and tested.** No threshold, preset, or constant
   in this feature is chosen by judgement alone. Every number is justified by
   documented reasoning, and every change is verified by the test suite.
4. **One phase at a time, user-gated.** See [Gate protocol](#gate-protocol).
   Phases are sequenced so each is independently shippable and revertible.
5. **Test material never leaves the machine.** Any real documents used for
   manual verification are git-ignored, never uploaded, never logged.
6. **Handwriting lowers trust; it never raises it.** Phase 2 relaxes the
   *verification* threshold for handwritten words so the signal stays
   informative — but a handwritten date or amount is always surfaced for
   review regardless of score. This preserves F13-T06's invariant that
   verification only ever lowers trust.

---

## Gate protocol

**No phase begins until the previous phase's gate is signed off by the user.**

Every gate requires all four, with no exceptions:

| # | Requirement |
|---|---|
| **G1 · Numbers agreed** | Every constant introduced or changed is justified by documented reasoning or on-device observation, not judgement alone. |
| **G2 · Results verified** | The test suite passes and the change has been verified (code inspection, on-device test, or unit test as appropriate). |
| **G3 · Code proven** | `dart format .` · `flutter analyze` · `flutter test` all pass. Backend phases add `deno test`. Output is shown, not summarised. |
| **G4 · Explicitly approved** | The user reviews the above and says to continue. Silence is not approval. |

Failing a gate is a normal outcome, not a setback. If Phase 1 does not move
the numbers, that is a finding: the phase is reverted or reworked, and the
plan is amended before anything else proceeds.

Per `CLAUDE.md` §8, each phase additionally runs `/flutter-code-review`, then
`@code-reviewer`, then `/explain-feature`, then `@git-expert` — before its gate
is presented.

---

## Phase 1 · Capture fidelity — *a defect fix; the accuracy gain is unproven*

> **Reprioritised 2026-09-09.** This phase was written as "the largest expected
> gain". The one experiment available to test that claim did not support it —
> see [The resolution experiment](#the-resolution-experiment-2026-09-09) below.
> It is now sequenced **after Phase 2** and justified as a correctness fix, not
> an accuracy improvement.

### The resolution experiment — 2026-09-09

No masters above 1.92 MP will be available, so the planned 0.92 → 8.3 MP
comparison cannot be run. What could be run: downscale the six owner-verified
masters to 0.92 MP — exactly what `ResolutionPreset.high` produces today — and
score both sets against the same ground truth. `HighQualityBicubic`, JPEG
quality 95, so resolution is the only variable.

```
                    1.92 MP    0.92 MP     delta
form_handwritten
  CER                 35.0%  →   41.5%     +6.5   worse
  WER                 52.0%  →   58.8%     +6.8   worse
  mean confidence     74.3%  →   75.1%     +0.8   better
handwritten_prose
  CER                 58.9%  →   55.5%     −3.4   BETTER at lower res
printed_clean
  CER                  0.0%  →    0.0%        —
ALL
  CER                 27.3%  →   30.0%     +2.7   worse
  mean confidence     81.6%  →   82.2%     +0.6   better
  date+amount         50.0%  →   50.0%        —
```

**This is a null result, and it was called as one in advance** — a positive
result would have been strong evidence, a null one weak. One category degraded
by 6.5 CER points on n=3, comfortably inside noise; another *improved* at lower
resolution; the verdict metric did not move; and mean confidence — the only
figure here that depends on no transcription at all — did not fall.

It does not show resolution is irrelevant. The step tested is 2×, not the 9×
the phase proposes, and both points may sit in the same flat low region with
any gain appearing only above ~4 MP. **It removes the evidence for the phase
without supplying evidence against it.**

What it does settle is where the handwriting problem is *not*:

```
                 1.92 MP    0.92 MP
printed           97.2%  →   97.6%
handwritten       74.3%  →   75.1%
                        ↑
        the gap, and the 0.85 threshold inside it, are unchanged
```

Azure's confidence in handwriting is intrinsically low and does not move with
resolution. **The handwriting failure is a thresholding problem, not a pixel
problem** — which is Phase 2. `verified` also fell 33.3% → 0% on the same three
documents purely from downscaling, further evidence that verification is
unstable rather than merely mis-tuned.

### Remaining justification for this phase

The camera is configured to produce **0.92 MP** while the app's own quality gate
sets `_resAcceptable` at **1.00 MP**. Capture cannot satisfy the bar capture is
judged against. That is a self-contradiction in the codebase and is worth fixing
on its own terms — but the change must not be described as an accuracy
improvement, because no measurement supports that.

Risks stay unverified without devices: a ~5× payload on weak connections, OOM on
low-end Android, and presets a device refuses. They are handled defensively (a
descending fallback ladder and a byte ceiling), and recorded here as **accepted
assumptions, not verified results**.

### Minimal fix applied — 2026-09-10 (user decision)

The user chose to fix the contradiction directly rather than wait for Phase 2. Scope was deliberately kept
smaller than the full T06–T12 table below:
[`platform_camera_service.dart`](../../lib/features/capture/data/services/platform_camera_service.dart#L63)
now requests `ResolutionPreset.veryHigh` (~1080p, ~2.07 MP) instead of `.high`
(~720p, ~0.92 MP).

`veryHigh`, not `ultraHigh`, on purpose:

- It clears both `_resAcceptable` (1 MP) and `_resGood` (2 MP) — the
  contradiction this was meant to fix — without the payload, OOM, and
  per-device-support risk `ultraHigh`/`max` carry and that T06/T10/T11 below
  still exist to handle.
- The one resolution experiment run so far (0.92 vs 1.92 MP) was a
  null result, not a positive one — so this is not sold as an accuracy fix.
  The code comment at the call site says so explicitly, to stop a future
  reader citing this change as evidence resolution was fixed.
- No fallback ladder was added. `veryHigh` (~1080p) is supported on
  essentially every camera Flutter's `camera` plugin runs on, unlike
  `ultraHigh`, where the plugin's own doc string ("platform implementations
  may fall back... if a specific preset is not available") is the reason
  T06 specifies a ladder at all.

Verified: `dart format`, `flutter analyze` on the changed file (no issues), the
file's own unit test (7/7 — it tests `buildFrame`, not the preset, so this
change could not have been expected to move it), and the full capture feature
suite (298/298). No thresholds changed; the fix is one line plus its
justifying comment.

**T08–T12 below remain open** — the 2026-09-10 fix attempted neither the
`ultraHigh` step nor the fallback ladder (both are T06, applied below), and
still leaves the payload ceiling and the threshold retuning untouched. Those
need on-device testing. T07 is verified below and needed no capture change.

### T06 applied — 2026-09-11

`initialize()` no longer names a single preset. It walks
`PlatformCameraService.presetLadder` — `ultraHigh` → `veryHigh` → `high` — and
adopts the first rung the device accepts, which lifts the normal case from
~2.07 MP to ~8.29 MP (~185–260 DPI on A4) while keeping a working camera on a
device that refuses either higher preset.

The walk is factored out as `openAtBestPreset<T>`, generic and
controller-free, for the same reason `buildFrame` is: the part that actually
goes wrong — rung order, and not opening a camera after a `dispose` has
superseded the attempt — is then unit-testable without a camera. Nine tests cover it
(rung order, `max` absent, top rung taken, one step down, down to the bottom
rung, every rung refused, superseded mid-ladder, superseded before the first
rung, empty ladder).

Two leaks are closed along the way:

- A rung the device refuses disposes its own controller before rethrowing
  (`_openController`), so a refused preset never leaves a native handle for
  the next rung to contend with.
- The controller is adopted into `_controller` *before*
  `lockCaptureOrientation`, not after. Previously a throwing orientation lock
  fell into the `on Object` handler, which released `_controller` — still
  `null` at that point — and leaked the controller it had just opened.

**Still unverified, and gating Gate 1's G2:**

- **No on-device run.** `ultraHigh` support, the actual file size it
  produces, and decode cost are all device-dependent; nothing here was run on
  hardware.
- **T10 is now load-bearing.** The client applies no size bound —
  [`default_analysis_repository.dart:234`](../../lib/features/analysis/data/repositories/default_analysis_repository.dart#L234)
  base64-encodes whatever the file holds, and `max_image_bytes` is enforced
  only server-side in
  [`analyze-request.ts:458`](../../supabase/functions/_shared/analyze/analyze-request.ts#L458).
  A document photo at 8.29 MP normally lands well under 8 MB, but the ceiling
  is now reachable, and exceeding it fails *after* the user has waited.
- **The preset governs the frame stream too**, not only stills. An
  `ultraHigh` session streams ~8.3 MB luma planes, ~9× the previous per-frame
  cost, which Phase 3's T20 sharpness computation inherits. `FrameThrottle`
  bounds how many are in flight, not how expensive each one is.

Raising the acceptance bar without raising the capture resolution would tell
users their photo is inadequate while giving them no way to succeed. **These
must ship together.**

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T06 | Raise `ResolutionPreset` with a **graceful descending fallback** (`ultraHigh` → `veryHigh` → `high`) for devices that reject the higher preset — mirroring the existing epoch-guarded init in [`platform_camera_service.dart:47`](../../lib/features/capture/data/services/platform_camera_service.dart#L47) | **DONE** (2026-09-11) — ladder + 9 tests; on-device verification outstanding |
| 2 | F17-T07 | Verify `takePicture()` keeps the highest JPEG quality available; confirm the frame stream still starts at the new preset (F16's detector reads the luma plane) | **DONE** (2026-09-11) — verified against plugin source; warp quality pinned |
| 3 | F17-T08 | Retune `_resGood` / `_resAcceptable` to match the chosen `ResolutionPreset` — **per platform if on-device testing shows they differ** | TODO |
| 4 | F17-T09 | Retune `_blurGood` / `_blurAcceptable` — current values (100 / 50) are unmeasured guesses; calibrate on-device | TODO |
| 5 | F17-T10 | **Payload bound** — enforce a ceiling below `max_image_bytes` (8,000,000; [migration](../../supabase/migrations/20260801120000_bump_schema_version_v2.sql#L21)). Base64 inflates by ~33%, so 8 MB decoded ≈ 10.7 MB on the wire | TODO |
| 6 | F17-T11 | Memory + thermal check on a low-end Android device — 8 MP decode in [`DartImageQualityService`](../../lib/features/capture/data/services/dart_image_quality_service.dart) must not OOM | TODO |
| 7 | F17-T12 | Tests for the fallback ladder, the new thresholds, and the payload bound | TODO |

### T07 verified — 2026-09-11

Read against the resolved plugin sources on this machine (`camera` 0.12.0+2,
`camera_android_camerax` 0.7.2, `camera_avfoundation` 0.10.2, `doclens` 0.0.8),
not against documentation.

**`takePicture()` has no quality knob, and the app lowers nothing.**
[`camera_controller.dart:465`](file:///C:/Users/Darwish/AppData/Local/Pub/Cache/hosted/pub.dev/camera-0.12.0+2/lib/src/camera_controller.dart)
takes no arguments and forwards straight to
`CameraPlatform.instance.takePicture(_cameraId)`. The platform interface
exposes only `setImageFileFormat` (JPEG/HEIF) — no quality — and the app never
calls it, so JPEG stands. Per platform:

| Platform | What sets still quality | Value | Reachable from Dart? |
|---|---|---|---|
| Android | `ImageCapture(resolutionSelector, targetRotation)` — no capture mode, no `setJpegQuality` | CameraX default for `CAPTURE_MODE_MINIMIZE_LATENCY` | No |
| iOS | `AVCapturePhotoSettings()` plain; the quality branch is `if imageQuality < 100` and `imageQuality` defaults to 100, so it is skipped | AVFoundation default | No |

So "highest available" is already in force on both, and raising it would mean
forking the plugin. **Nothing to change at capture.**

**Where quality can actually be lost is after capture**, and that chain is in
better shape than expected. Each stage either hands the file back untouched or
re-encodes once:

| Stage | Re-encodes? | Quality |
|---|---|---|
| [`ImagePackageRotator`](../../lib/features/capture/data/services/image_package_rotator.dart#L33) | Only when `turns != 0` — returns the input otherwise | 92 |
| [`ImagePackageCropper`](../../lib/features/capture/data/services/image_package_cropper.dart#L34) | Only when the crop is not full-extent | 92 |
| [`DoclensPerspectiveCorrector`](../../lib/features/capture/data/services/doclens_perspective_corrector.dart#L40) | Only when a quad is found | **100** |

The common path — no rotation, no crop, quad found — is therefore **exactly one
re-encode, at quality 100**. `warpImage`'s `jpegQuality` was previously left to
`doclens`'s default; T07 pins it at the call site, because the default is a
dependency's choice that a version bump could lower, and because it is the lever
T10 turns if the payload has to come under `max_image_bytes` (trading quality
beats discarding the resolution T06 just added). Two tests now assert the warp
asks for quality 100 and `ImageEnhancement.none`.

> **Open, and cheap to settle:** quality 92 on the rotate/crop paths is an
> unmeasured inherited constant. The benchmark tool and the owner-verified
> masters are both on this machine, so a 92-vs-100 comparison is runnable
> whenever the user wants it. Not run here — it costs live OCR calls, and T07
> did not ask for it. Left as-is rather than bumped by judgement (locked
> decision #3).

**The frame stream starts at the new preset — and inherits its cost.** On
Android the preset builds one `ResolutionSelector` that is handed to *all
three* use cases — `Preview`, `ImageCapture` **and** `ImageAnalysis`
([`android_camera_camerax.dart:415-480`](file:///C:/Users/Darwish/AppData/Local/Pub/Cache/hosted/pub.dev/camera_android_camerax-0.7.2/lib/src/android_camera_camerax.dart))
— so the `ultraHigh` rung requests 3840×2160 YUV frames, ~8.3 MB of luma each.
On iOS both come off one `AVCaptureSession` at `.hd4K3840x2160`, and the stream
is BGRA: ~33 MB per frame.

Three consequences, none of which needed a code change:

1. **Detection cost does not scale with the preset.** The algorithm strided-
   samples to `targetWidth = 160` before any pixel work
   ([`document_edge_algorithm.dart:87`](../../lib/features/capture/data/services/document_edge_algorithm.dart#L87)),
   so it reads ~160×120 samples out of the large buffer regardless of frame
   size. What scales is the per-frame *buffer*, and `FrameThrottle` holds that
   to one in flight. `DetectionBudget` already disables detection if frames get
   slow — the degradation path exists.
2. **Stride handling is what would break**, not throughput: 4K rows are likelier
   to be hardware-padded than 720p rows were. Two tests now cover the new
   geometry (3840×2160 luma at a 3904 stride, and the iOS BGRA frame).
3. **The ladder earns its keep on Android specifically.** Binding three 4K use
   cases can exceed CameraX's guaranteed stream combination, which surfaces as a
   throw from `bindToLifecycle` → `controller.initialize()` → T06 steps down to
   `veryHigh`. This is the concrete failure the ladder was written for.

**A limit of the ladder, found here and worth recording:** on iOS the native
side runs its *own* descending fallback —
`hd4K3840x2160` → `.high` → `hd1920x1080` → `hd1280x720` → VGA → CIF, throwing
only when nothing can be set
([`DefaultCamera.swift:271`](file:///C:/Users/Darwish/AppData/Local/Pub/Cache/hosted/pub.dev/camera_avfoundation-0.10.2/ios/camera_avfoundation/Sources/camera_avfoundation/DefaultCamera.swift)).
A device that cannot do 4K therefore **succeeds at the `ultraHigh` rung while
silently running lower**, and the Dart ladder never sees a throw. The app cannot
know the resolution it actually got; the only thing that observes it is
`DartImageQualityService`, after the fact, from the decoded pixels. That makes
T08's thresholds the real feedback loop rather than a cosmetic retune — and it
is why `isHighResolutionPhotoEnabled` being set only for `.max`
(`DefaultCamera.swift:710`) does not help us: we are not on `.max`.

**Not verified:** no on-device run. Which rung each device lands on, the actual
still size, and the per-frame allocation at 4K are exactly what T11 exists to
measure.

### Why `ultraHigh`, not `max`

`max` is unbounded — on a 108 MP sensor it produces a file far over
`max_image_bytes`, and the request is rejected with `400 INVALID_REQUEST`
*after* the user has waited through capture. `ultraHigh` is ~270 DPI on A4,
comfortably above Azure's 50 px line-height guidance, and predictable in size.

If T10 shows even `ultraHigh` exceeds the bound on some devices, the resolution
is a **bounded re-encode** — reduce JPEG quality toward a byte target while
holding pixel dimensions. Downscaling pixels is the last resort, because pixels
are exactly what this phase exists to add.

**Risk:** a ~5× larger payload on a weak Egyptian mobile connection. T10 must
record upload time on a throttled connection, not only on Wi-Fi.

### Gate 1
G1 every new constant justified · G2 tests pass and on-device smoke test
confirms capture works · G3 format + analyze + test green · G4 user approves.

---

## Phase 2 · Handwriting awareness — *the largest gain in trustworthiness*

This phase does not improve OCR accuracy. It makes the app **honest about**
its accuracy, which is what `CLAUDE.md` §7 requires: *"الثقة على مستوى
المعلومة لا المستند"*.

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T13 | Parse `analyzeResult.styles[]`; extend `AzureReadResult` with handwritten spans. Follow `flattenWords()`'s tolerant shape — a malformed `styles` yields `[]`, never an error | TODO |
| 2 | F17-T14 | Map each word to printed/handwritten via span offsets (`AzureWord.offset`/`length` already carry them) | TODO |
| 3 | F17-T15 | Split `VERIFIED_CONFIDENCE_THRESHOLD` into `VERIFIED_PRINTED` (0.85, unchanged) and `VERIFIED_HANDWRITTEN` — value justified by Azure's documented confidence ranges for Arabic handwriting | TODO |
| 4 | F17-T16 | Carry a document-level "contains handwriting" flag to the client via `analyze-response.ts` → [`analysis_response_mapper.dart`](../../lib/features/analysis/data/mappers/analysis_response_mapper.dart). Note F13 locked decision #6: `VerificationStatus` itself never crosses the wire — only this boolean does | TODO |
| 5 | F17-T17 | Arabic banner in [`ar_strings.dart`](../../lib/core/localization/ar_strings.dart) + `en_strings.dart`: «الورقة دي مكتوبة بخط اليد — راجع الأرقام والتواريخ كويس». Reuse the existing banner widget; do not add a new one | TODO |
| 6 | F17-T18 | **Handwritten dates and amounts always surface for review**, whatever their score — they drive reminders and money | TODO |
| 7 | F17-T19 | Unit tests for both thresholds, span mapping, and the always-review rule | TODO |

**Backend deploy required.** Phase 2 changes Edge Functions, so its gate
includes a dev-project deploy and an end-to-end run before production.

### Gate 2
G1 `VERIFIED_HANDWRITTEN` justified by Azure's confidence ranges · G2 printed
pages' verification unchanged · G3 `deno test` + Flutter suite green · G4 user
approves.

---

## Phase 3 · Sharpness gate at capture

> **Reads on the app's own camera frames, not `doclens`.** An earlier draft of
> this phase assumed reuse of F16's live-detection pipeline; that pipeline's
> user-visible guide is now cancelled because it could not track the paper's
> edges reliably (Context §4), but the frame-streaming plumbing underneath it
> (`startFrameStream`/`CameraFrame` in `platform_camera_service.dart`) stays
> and is exactly what T20 needs. No second native camera session required.

`doclens` computes variance-of-Laplacian per frame and publishes it on
`DetectionEvent.sharpness` ([`platform_interface.dart:27`](file:///C:/Users/Darwish/AppData/Local/Pub/Cache/hosted/pub.dev/doclens-0.0.8/lib/src/platform_interface.dart)),
but nothing in the app subscribes to that stream, and this phase does not
start doing so. Preventing a blurred capture is cheaper and more reliable
than detecting one afterwards.

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T20 | Compute variance-of-Laplacian sharpness on frames from the app's own `startFrameStream`/`CameraFrame` pipeline (kept from F16 for exactly this; see Context §4) — no `doclens` native session | TODO |
| 2 | F17-T21 | Smooth over ~5 frames — a raw per-frame value flickers and would strobe the UI | TODO |
| 3 | F17-T22 | Calibrate the threshold on-device | TODO |
| 4 | F17-T23 | Shutter shows a **visual warning** — «ثبّت الموبايل شوية» — while unsteady | TODO |
| 5 | F17-T24 | **The shutter is never disabled.** Older users and users with tremor may be unable to satisfy it; blocking them entirely is worse than a slightly blurred read (F16 locked decision #4 — graceful degradation is the default) | TODO |
| 6 | F17-T25 | RTL, Large Text, and never colour-alone (design-system rule) | TODO |
| 7 | F17-T26 | Widget tests for the warning state | TODO |

### Gate 3
G1 threshold measured · G2 fewer blur-rejected captures with no drop in capture
success · G3 suite green + on-device check · G4 user approves.

---

## Phase 4 · Split the display rendition from the OCR rendition

What the user looks at and what the model reads are different images with
different goals. This is what CamScanner actually does, and it is the *only*
place enhancement belongs.

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T27 | Split the paths in [`doclens_perspective_corrector.dart:40`](../../lib/features/capture/data/services/doclens_perspective_corrector.dart#L40) | TODO |
| 2 | F17-T28 | **OCR rendition** — `ImageEnhancement.none`, unchanged (locked decision #1) | TODO |
| 3 | F17-T29 | **Display rendition** — `ImageEnhancement.enhanced` for the on-screen and saved image | TODO |
| 4 | F17-T30 | User choice: **ألوان محسّنة · أبيض وأسود · أصلي**, matching the approved design | TODO |
| 5 | F17-T31 | Display rendition is AES-256-GCM encrypted on save; the OCR rendition and every temp file are deleted immediately after the read (§7) | TODO |
| 6 | F17-T32 | **Regression test: the enhanced rendition must never reach `analyzeImage()`.** This is the guard that keeps locked decision #1 true as the code evolves | TODO |

> ⚠️ Two renditions means two files on disk at once. T31 must prove both are
> cleaned up on the success path, the failure path, and the cancel path.

### Gate 4
G1 no accuracy-affecting constants introduced · G2 OCR metrics **unchanged**
from Phase 3 — any movement means enhanced bytes leaked into the OCR path ·
G3 suite green, T32 proven to fail if the paths are swapped · G4 user approves.

---

## Phase 5 · Illumination flattening — *conditional; likely unnecessary*

> **Do not start this phase unless Phases 1–4 are complete and the measurements
> still show a specifically illumination-related failure mode.** This is the
> one phase that can make things worse.

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T33 | Re-examine Phase 4 results: are the remaining errors actually shadow/lighting failures, or something else? | TODO |
| 2 | F17-T34 | If yes: illumination flattening (background division) on the OCR rendition — **grayscale preserved, no binarisation** | TODO |
| 3 | F17-T35 | Mandatory A/B test on sample documents | TODO |
| 4 | F17-T36 | **If the gain is < 5 points, revert and delete the code.** Unmeasured image processing is a liability, not an asset | TODO |

### Gate 5
G1 measured gain ≥ 5 points, or the phase is reverted · G2 full A/B shown ·
G3 suite green · G4 user approves.

---

## Sequence

```
Phase 1  Capture fidelity           camera + payload fixes
   │
   └── Gate 1 ─── user sign-off required
Phase 2  Handwriting awareness      ⭐ largest trustworthiness gain · backend deploy
   │
   └── Gate 2 ─── user sign-off required
Phase 3  Sharpness gate            reads the kept F16 frame-stream, not doclens
   │
   └── Gate 3 ─── user sign-off required
Phase 4  Display / OCR split
   │
   └── Gate 4 ─── user sign-off required
Phase 5  Illumination flattening    conditional — expected to be skipped
   │
   └── Gate 5
```

---

## Verification

Per phase, before its gate is presented:

```bash
dart format .
flutter analyze
flutter test
```

Backend phases (Phase 2) additionally:

```bash
deno test supabase/tests/unit/
```

On-device, Phases 1 and 3: physical Android **and** physical iOS, per the
`dev-run-on-physical-device` constraint (LAN `SUPABASE_URL` override plus a
running local Supabase, or the splash never completes).

---

## Resolved with the user — 2026-09-09

1. **Expectations — agreed.** 100% is not achievable by any OCR system.
   Realistic bands: printed clean 96–99%, printed poor 85–93%, **handwritten
   Arabic 70–88%**. The goal is to reach the top of those bands *and to be
   honest whenever we fall outside them* — not to eliminate error. This is what
   Phase 2 exists for.
2. **Rollout — no feature flag.** The app is not published and has no real
   users, so there is nobody to protect from a bad capture change and a
   `RuntimeConfig` entry would be unused complexity. The resolution is set
   directly in [`platform_camera_service.dart`](../../lib/features/capture/data/services/platform_camera_service.dart).
   > **Revisit before launch.** Capture resolution has device-dependent failure
   > modes (OOM on low-end Android, slow upload on weak connections, presets a
   > device refuses) that two test devices cannot cover. If this ships to real
   > users, promoting the tier to `RuntimeConfig` turns a store-review cycle
   > into a database update.

---

## Sources

- [Language and locale support for Read and Layout — Azure Document Intelligence v4.0](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/language-support/ocr?view=doc-intel-4.0.0)
- [Read model OCR data extraction](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/prebuilt/read?view=doc-intel-4.0.0)
