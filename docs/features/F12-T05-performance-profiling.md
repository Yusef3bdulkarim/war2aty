# F12-T05 — Performance profiling (heavy work off UI thread; jank check)

Full-app sweep against the two acceptance criteria: every CPU-heavy
operation runs off the UI thread, and nothing in the interactive paths does
unnecessary work that risks a dropped frame. No profiler/DevTools trace was
available in this environment (same constraint T01–T04 noted for a
real-device pass) — this is a code-level sweep: every `async` boundary that
touches a file, an image, or a cipher was read to its actual implementation
(including two third-party packages' own source, not just their public API)
and classified by whether the CPU-bound part of the work provably runs on
the calling isolate or is provably offloaded.

Method: grepped and read every site that (a) spawns or could spawn a
background isolate (`Isolate.run`, `compute(`), (b) does file/image/crypto
work triggered from a Cubit or widget (`FileEncryptor`, `ImageRotator`,
`ImagePreprocessor`, `ImageQualityService`, `OcrEngine`, `PerspectiveCorrector`),
and (c) drives a continuous animation (`AnimationController`) or a
routinely-rebuilding `BlocBuilder`, then read each one against the
established reference pattern already in this codebase (see "Checked, no
change needed" below) rather than against a generic checklist.

## Fixed

**`AesGcmFileEncryptor.encrypt`/`.decrypt`** — encrypted and decrypted a
saved document's picture entirely on the calling isolate. `package:cryptography`
is used here without `cryptography_flutter` (not a project dependency — confirmed
by grepping `pubspec.yaml`), so `AesGcm.with256bits().encrypt()`/`.decrypt()` run
the pure-Dart cipher loop synchronously inside the `Future`, with no yield
point — CPU-bound work that blocks the isolate's event loop for as long as
it runs. This is the exact hazard the capture/OCR pipeline already guards
against in three sibling services — `ImagePackageRotator`, `DartImagePreprocessor`,
`DartImageQualityService` — each of which reads bytes on the calling isolate
and does only the CPU-heavy part inside `Isolate.run`, with a doc comment
explaining why. The encryptor was the one place doing comparably heavy work
(a full-resolution page photo, potentially several MB) that never got the
same treatment.

Reachable from user interaction: `SaveDocumentCubit.save()` emits
`SaveDocumentSaving()` and awaits `SaveDocumentWithImage` → `DocumentsRepository
.saveWithImage` → `FileDocumentImageStore.encryptAndStore` → `_encryptor.encrypt`
directly off the result screen's «حفظ الورقة» tap — a real, user-triggered
path, not a background job.

Fix: moved only the pure cipher computation into `Isolate.run`, matching the
sibling pattern exactly — `key.extractBytes()` (needed to reach secure
storage, a platform channel, so it must stay on the calling isolate) hands
raw key bytes across the isolate boundary; the static `_encryptBytes`/
`_decryptBytes` functions rebuild a fresh `AesGcm`/`SecretKey` from plain
bytes inside the isolate rather than capturing `this` or the `SecretKey`
object, so only sendable data crosses. Output format is unchanged (`nonce ‖
ciphertext ‖ tag`), so nothing else in the encryption contract moved.

All 8 pre-existing tests in
[`aes_gcm_file_encryptor_test.dart`](../../test/core/crypto/aes_gcm_file_encryptor_test.dart)
and both device-store round-trip tests in
[`file_document_image_store_test.dart`](../../test/core/documents/file_document_image_store_test.dart)
pass unchanged against the refactor — the isolate boundary is invisible to
the public `FileEncryptor` contract, same as it is for the rotator/
preprocessor's own tests.

**`SystemImagePickerService.pickSingleImage`** — a gallery-picked photo had
no size ceiling before being decoded to display the crop/rotate preview
(`image_preview_screen.dart`'s `Image.file`, `_imageMaxWidth = 320`). Unlike
a camera capture — already capped by `ResolutionPreset.high` in
`PlatformCameraService`, a deliberate choice with its own comment — a photo
from the user's camera roll can be an original at full sensor resolution
(commonly 12+ MP). Decoding a 4000×3000 JPEG to show it inside a
320-logical-px-wide box means Flutter allocates and paints a raw bitmap
roughly 100× larger than anything actually drawn (4000×3000×4 bytes ≈ 48 MB
for one frame's worth of pixels nothing downstream uses), on the very next
screen after the user picks a photo — a real jank/memory-pressure risk on
budget hardware, the same category of problem `DartImageQualityService`'s
own doc comment names.

Fix: capped `ImagePicker.pickImage()`'s `maxWidth`/`maxHeight` to 4096 —
matching `kMaxOcrDimension` in `dart_image_preprocessor.dart`, the ceiling
OCR itself resizes down to later, so this loses no recognition quality, only
the wasted read/decode/store of pixels nothing downstream ever uses. The
resize happens on the native picker side (off the Dart isolate entirely),
so it also shrinks every later step for a gallery-sourced document: the
crop preview decode, the quality-assessment isolate call, the OCR
preprocessor's own resize, and — if the user saves with image — the
encryption step fixed above.

No test existed for this service before this task (a coverage gap, not
introduced here). Added
[`system_image_picker_service_test.dart`](../../test/features/capture/system_image_picker_service_test.dart),
faking `ImagePickerPlatform` (`MockPlatformInterfaceMixin`, the standard
seam for this plugin family) to assert the resize options reach the
platform call without a real device or gallery — confirmed failing against
the pre-fix source (`maxWidth`/`maxHeight` both `null`) and passing after.
`image_picker_platform_interface`, `plugin_platform_interface`, and
`cross_file` were already resolved transitively through `image_picker`;
declared directly in `pubspec.yaml` `dev_dependencies` since the test now
imports them itself.

## Checked, no change needed

- **The three existing `Isolate.run` sites** — `ImagePackageRotator`,
  `DartImagePreprocessor`, `DartImageQualityService` — all correctly read
  bytes on the calling isolate and confine only the pure `image`-package
  computation to the spawned isolate, each with a doc comment naming the
  reason. These are the reference pattern the encryptor fix above was
  brought in line with, not something this task needed to change.
- **`DoclensPerspectiveCorrector`** — calls the `doclens` plugin's platform
  interface (`detectInImage`/`warpImage`) over a method channel; the actual
  edge-detection/dewarp work happens natively, not in Dart, so there is
  nothing on the Dart UI isolate to offload here regardless of image size.
- **`TesseractOcrEngine.extractText`** — read the plugin's own Android
  source (`flutter_tesseract_ocr` 0.4.31,
  `FlutterTesseractOcrPlugin.java`): `onMethodCall` dispatches recognition
  through an `AsyncTask` (`doInBackground`), Android's own background-thread
  primitive — the native side already keeps this off the UI thread on its
  own, independent of anything the Dart side does. (iOS side not
  independently read; no reason from the Android implementation to expect a
  different threading model, but noted rather than assumed.)
- **Every `AnimationController`** in the app (`PulsingDots`, `ViewfinderFrame`'s
  `_ScanLine`, `AnalysisProgressView`'s `_ProgressBar`, `Shimmer`,
  `camera_capture_screen.dart`'s own controller) — all five are disposed in
  `dispose()`, and every `AnimatedBuilder` that has a static subtree passes
  it through the `child:` parameter rather than rebuilding it every tick
  (`PulsingDots`'s dot `Container`, `Shimmer`'s `content`) — the standard
  Flutter pattern for keeping a continuous animation cheap. `Shimmer` also
  already stops itself under `MediaQuery.disableAnimationsOf` (reduced
  motion) rather than burning frames no one sees. Nothing here needed a
  performance fix; T01's accessibility audit already covers the
  reduced-motion behavior itself.
- **`BlocBuilder` scope** — `AudioReaderCubit`'s two listeners
  (`analysis_result_screen.dart`'s `_MiniPlayerSlot`,
  `document_details_screen.dart`'s equivalent) are already split into their
  own small `StatelessWidget` rather than folded into the page's own
  `builder`, with a comment pointing at the F10-T08 decision that shaped
  it — exactly the CLAUDE.md §8 "smallest widget that needs the state"
  rule, already applied by construction to the one cubit in this app that
  updates on a timer-like cadence (playback progress). Every other
  `BlocBuilder` wraps a screen `body:` for a cubit that only emits on
  discrete events (load complete, save complete, error) — appropriate at
  that scope since there is no high-frequency emission to guard against.
- **No polling loops** — zero hits for `Timer.periodic`/`Stream.periodic`
  anywhere in `lib/`, so no source of unforced rebuild churn to chase.
- **List rendering** — `documents_list_screen.dart` and
  `reminders_list_screen.dart` (the two screens that render a
  possibly-long, user-generated list) both use `ListView.separated` for the
  actual item list; `SingleChildScrollView` only wraps their empty/error
  states, confirmed by reading both files. `candidate_chips.dart`'s
  `.map().toList()` builds a `Wrap` of a single field's OCR candidates — a
  small, bounded count, and `Wrap` isn't a windowing widget regardless, so
  eager building is correct there, not an oversight.

## Flagged for cleanup (not resolved here)

- **No `RepaintBoundary` anywhere in `lib/`** — every continuously-animating
  widget (`PulsingDots`, `ViewfinderFrame`'s scan line, `AnalysisProgressView`'s
  progress bar, `Shimmer`) repaints without one. Each is already cheap to
  paint on its own (a handful of shapes/gradients, not a complex subtree),
  and `ViewfinderFrame` sits over a live `CameraPreview` that is very
  likely its own compositor layer already (a `Texture` widget) rather than
  something these repaints would touch — but neither claim was verified
  against an actual frame trace, so this is not proven to cause a dropped
  frame today. Adding boundaries around these four is a safe, low-risk
  follow-up if a real-device trace (Exit DoD) ever shows otherwise; not
  applied speculatively here per CLAUDE.md's smallest-change rule.
- **`image_preview_screen.dart`'s `Image.file` for a camera-sourced photo**
  has no `cacheWidth`, same shape as the gallery-picker bug fixed above —
  but the source is already bounded by `ResolutionPreset.high` (a
  deliberate, already-reasoned-about choice per its own comment), so unlike
  the gallery path this was not proven to over-decode by a concrete margin.
  Worth the same `cacheWidth` treatment as a follow-up for defense in depth,
  but not fixed unilaterally here without a proven case, matching the
  gallery fix's evidence bar rather than its remedy.

## Out of scope (deferred)

- **A real-device profiler/DevTools timeline pass** — this task is a
  code-level sweep, same constraint T01–T04 already noted for their own
  device-only checks; belongs to the Exit DoD's "real-device pass on
  Android + iOS" line, not this task.
- **iOS-side `flutter_tesseract_ocr` threading** — not independently read
  (see above); if a future iOS-specific jank report surfaces around OCR,
  start there.
- **Analysis JSON parsing** (`jsonDecode` in `analysis_remote_data_source.dart`
  and the mock/validator siblings) — every payload here is one page's worth
  of structured analysis (a few KB at most, never a multi-page document),
  so there is no realistic input size where this becomes CPU-heavy enough
  to matter; not swept further.
