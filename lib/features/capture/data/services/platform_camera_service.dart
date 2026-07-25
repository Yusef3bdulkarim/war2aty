import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/services/camera_service.dart';
import '../../presentation/camera_preview_port.dart';

/// [CameraService] on top of the `camera` plugin.
///
/// The only place the plugin is touched. It also satisfies the presentation's
/// [CameraPreviewPort] so the viewfinder can render the live feed without ever
/// importing the plugin itself. Every hardware error is caught here, at the
/// boundary, and mapped to a typed failure — a camera problem is an on-device
/// image-processing failure, which the analysis taxonomy already names, so no
/// new leaf is invented for it.
final class PlatformCameraService implements CameraService, CameraPreviewPort {
  PlatformCameraService();

  CameraController? _controller;

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

      final controller = CameraController(
        back,
        // High enough for legible OCR without the memory cost of max — the
        // paper only has to be readable, not print-quality.
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      // The whole app is portrait; lock capture so a photo taken with the
      // phone slightly rotated is still saved upright.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

      // Cancelled while we were opening — release this controller rather than
      // adopt it, so a suspend/close mid-open cannot leave the camera held.
      if (_epoch != epoch) {
        await controller.dispose();
        return const Err(ImageProcessingFailure());
      }
      _controller = controller;
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
    try {
      final file = await controller.takePicture();
      return Ok(CapturedPhoto(file.path));
    } on Object {
      return const Err(ImageProcessingFailure());
    }
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
    if (controller != null) await controller.dispose();
  }
}
