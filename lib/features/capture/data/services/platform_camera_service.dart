import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/camera_frame.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/services/camera_service.dart';
import '../../presentation/camera_preview_port.dart';
import 'frame_throttle.dart';

/// [CameraService] on top of the `camera` plugin.
///
/// The only place the plugin is touched. It also satisfies the presentation's
/// [CameraPreviewPort] so the viewfinder can render the live feed without ever
/// importing the plugin itself. Every hardware error is caught here, at the
/// boundary, and mapped to a typed failure — a camera problem is an on-device
/// image-processing failure, which the analysis taxonomy already names, so no
/// new leaf is invented for it.
final class PlatformCameraService implements CameraService, CameraPreviewPort {
  PlatformCameraService({FrameThrottle? throttle})
    : _throttle = throttle ?? FrameThrottle();

  CameraController? _controller;

  /// The lens currently open — kept so a streamed frame can carry the sensor
  /// orientation and mirroring the presentation layer needs to map a detected
  /// quad onto the preview (F16-T05).
  CameraDescription? _description;

  /// Admits one frame at a time and drops the rest (F16 locked decision #3:
  /// frames are used and forgotten, never accumulated).
  final FrameThrottle _throttle;

  /// Bumped every time a session is opened or torn down. Opening the camera
  /// takes several awaits; if [dispose] (app backgrounded, route popped) runs
  /// during that window it advances the epoch, and the in-flight [initialize]
  /// sees it has been superseded and throws its controller away instead of
  /// leaking the native camera handle.
  int _epoch = 0;

  @override
  Future<Result<void, AppFailure>> initialize() async {
    final epoch = ++_epoch;
    try {
      // Re-initialising: drop any controller a previous attempt left behind
      // (e.g. the OS reclaimed the camera while backgrounded) before opening a
      // fresh one, so a controller is never leaked.
      await _releaseController();

      final cameras = await availableCameras();
      final back = _backCamera(cameras);
      if (back == null) return const Err(ImageProcessingFailure());

      final controller = await openAtBestPreset(
        ladder: presetLadder,
        open: (preset) => _openController(back, preset),
        isSuperseded: () => _epoch != epoch,
      );
      // Every rung refused, or a dispose landed between rungs: either way
      // there is no session to adopt.
      if (controller == null) return const Err(ImageProcessingFailure());

      // Cancelled while we were opening — release this controller rather than
      // adopt it, so a suspend/close mid-open cannot leave the camera held.
      if (_epoch != epoch) {
        await controller.dispose();
        return const Err(ImageProcessingFailure());
      }
      // Adopted before the orientation lock, not after, so that a lock which
      // throws is released by the `on Object` below instead of leaking the
      // handle it just opened.
      _controller = controller;
      _description = back;
      // The whole app is portrait; lock capture so a photo taken with the
      // phone slightly rotated is still saved upright.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      return const Ok(null);
    } on Object {
      await _releaseController();
      return const Err(ImageProcessingFailure());
    }
  }

  @override
  Future<Result<CapturedPhoto, AppFailure>> capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Err(ImageProcessingFailure());
    }
    // The shutter always wins: a live image stream and `takePicture` contend
    // for the same hardware on several Android devices, and edge detection is
    // only guidance (F16 locked decision #1). The cubit restarts the stream
    // afterwards if the viewfinder is still up.
    await stopFrameStream();

    try {
      final file = await controller.takePicture();
      return Ok(CapturedPhoto(file.path));
    } on Object {
      return const Err(ImageProcessingFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> startFrameStream(
    Future<void> Function(CameraFrame frame) onFrame,
  ) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Err(ImageProcessingFailure());
    }
    if (controller.value.isStreamingImages) return const Ok(null);

    final epoch = _epoch;
    try {
      _throttle.reset();
      await controller.startImageStream((image) {
        // Superseded by a dispose/re-initialize while the stream was being
        // torn down — drop the frame rather than feed a dead session.
        if (_epoch != epoch) return;
        if (!_throttle.tryAcquire()) return;

        final frame = _frameFrom(image);
        if (frame == null) {
          _throttle.release();
          return;
        }
        unawaited(onFrame(frame).whenComplete(_throttle.release));
      });
      return const Ok(null);
    } on Object {
      return const Err(ImageProcessingFailure());
    }
  }

  @override
  Future<void> stopFrameStream() async {
    final controller = _controller;
    _throttle.reset();
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isStreamingImages) return;
    try {
      await controller.stopImageStream();
    } on Object {
      // Nothing to recover: the stream is either already stopped or the
      // controller is gone, and either way no more frames will arrive.
    }
  }

  /// Capture resolutions to try, best first.
  ///
  /// A portrait A4 page filling the frame is ~185-260 DPI at `ultraHigh`
  /// (3840x2160, 8.29 MP) against ~60-110 DPI at `high` (1280x720, 0.92 MP),
  /// and 0.92 MP is below this app's own quality gate —
  /// `DartImageQualityService` scores anything under 1 MP as `poor`, so a
  /// `high` capture fails the bar the app judges it against (F17 Phase 1).
  /// `max` is deliberately absent: it is unbounded, and on a large sensor it
  /// produces a file over the backend's `max_image_bytes`, which is rejected
  /// only *after* the user has waited through capture.
  ///
  /// It is a ladder rather than a single preset because the `camera` plugin
  /// guarantees nothing here — its own doc notes platform implementations
  /// "may fall back to a lower resolution if a specific preset is not
  /// available", and devices that do not fall back throw instead. The bottom
  /// rung stays below the quality gate on purpose: a 720p camera still lets
  /// the user get a reading (and be told it is poor), which beats a device
  /// with no camera at all (F17-T06).
  @visibleForTesting
  static const presetLadder = <ResolutionPreset>[
    ResolutionPreset.ultraHigh,
    ResolutionPreset.veryHigh,
    ResolutionPreset.high,
  ];

  /// Walks [ladder] top-down and returns the first session [open] accepts, or
  /// `null` if every rung is refused — or if [isSuperseded] reports a dispose
  /// landed before a rung could be tried, since stepping down would then open
  /// a camera nobody is going to adopt.
  ///
  /// Generic and controller-free on purpose: the part that actually goes wrong
  /// — the order rungs are tried in, and stopping once the attempt has been
  /// superseded — is then unit-testable without a camera, the same split
  /// [buildFrame] uses. [open] owns its own cleanup: a rung it refuses must
  /// leave nothing behind, because this walker never sees that session.
  @visibleForTesting
  static Future<T?> openAtBestPreset<T>({
    required List<ResolutionPreset> ladder,
    required Future<T> Function(ResolutionPreset preset) open,
    required bool Function() isSuperseded,
  }) async {
    for (final preset in ladder) {
      if (isSuperseded()) return null;
      try {
        return await open(preset);
      } on Object {
        // This device refuses this preset — step down to the next rung.
        continue;
      }
    }
    return null;
  }

  /// Opens [description] at [preset], disposing the controller before
  /// rethrowing if the device refuses the preset, so a refused rung never
  /// leaves a native camera handle held for the next rung to contend with.
  Future<CameraController> _openController(
    CameraDescription description,
    ResolutionPreset preset,
  ) async {
    final controller = CameraController(
      description,
      preset,
      enableAudio: false,
      imageFormatGroup: _streamableFormat,
    );
    try {
      await controller.initialize();
    } on Object {
      try {
        await controller.dispose();
      } on Object {
        // The session never came up; there is nothing left to release.
      }
      rethrow;
    }
    return controller;
  }

  /// The stream format each platform can actually deliver. The capture path's
  /// previous `jpeg` group cannot be streamed at all, which is why this is the
  /// one F16 change that touches the working shutter (F16-T04); it is a single
  /// line so it can be reverted alone.
  static ImageFormatGroup get _streamableFormat =>
      Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888;

  /// The first plane of [image] as a domain frame: brightness on Android
  /// (yuv420's plane 0 *is* luma), the raw BGRA buffer on iOS, which the
  /// detector converts inside its isolate rather than on the UI thread.
  CameraFrame? _frameFrom(CameraImage image) {
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;
    final description = _description;

    return buildFrame(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      format: image.format.group == ImageFormatGroup.bgra8888
          ? CameraFrameFormat.bgra8888
          : CameraFrameFormat.luma8,
      sensorOrientation: description?.sensorOrientation ?? 0,
      isMirrored: description?.lensDirection == CameraLensDirection.front,
    );
  }

  /// The plugin-free half of [_frameFrom], so the part that actually goes
  /// wrong — row stride and byte-length assumptions — is unit-testable without
  /// a camera. Returns `null` for a frame whose bytes cannot describe the
  /// geometry it claims, which the caller drops silently.
  @visibleForTesting
  static CameraFrame? buildFrame({
    required Uint8List bytes,
    required int width,
    required int height,
    required int? bytesPerRow,
    required CameraFrameFormat format,
    int sensorOrientation = 0,
    bool isMirrored = false,
  }) {
    final bytesPerPixel = format == CameraFrameFormat.bgra8888 ? 4 : 1;
    final minimumStride = width * bytesPerPixel;
    // Some platforms report no stride; a packed row is the only sane guess,
    // and `isConsistent` below rejects it if that guess cannot hold.
    final stride = (bytesPerRow == null || bytesPerRow < minimumStride)
        ? minimumStride
        : bytesPerRow;

    final frame = CameraFrame(
      bytes: bytes,
      width: width,
      height: height,
      bytesPerRow: stride,
      format: format,
      sensorOrientation: sensorOrientation,
      isMirrored: isMirrored,
    );
    return frame.isConsistent ? frame : null;
  }

  @override
  Future<void> dispose() async {
    // Supersede any initialize still in flight, then release what we hold.
    _epoch++;
    await _releaseController();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  CameraDescription? _backCamera(List<CameraDescription> cameras) {
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) return camera;
    }
    // Fall back to whatever exists (some devices report no explicit back
    // lens) rather than failing outright.
    return cameras.isEmpty ? null : cameras.first;
  }

  Future<void> _releaseController() async {
    final controller = _controller;
    _controller = null;
    _description = null;
    _throttle.reset();
    if (controller == null) return;
    // Stop the stream first: disposing a controller mid-stream leaves the
    // platform side delivering frames into a dead handle on some devices.
    if (controller.value.isInitialized && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } on Object {
        // Already gone — nothing to release beyond the controller itself.
      }
    }
    await controller.dispose();
  }
}
