import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/camera_capabilities.dart';
import '../entities/camera_flash_mode.dart';
import '../entities/captured_photo.dart';
import '../entities/focus_point.dart';

/// The camera, as the capture flow needs it — a stateful device session.
///
/// Pure Dart: no plugin, no Flutter. The live preview is a UI concern and does
/// not belong here; it is a separate presentation port
/// (`CameraPreview`) satisfied by the same implementation. This interface
/// carries only the fallible actions, each returning a typed [AppFailure]
/// rather than throwing, so use cases and the cubit never see an exception.
abstract interface class CameraService {
  /// Opens the back camera in portrait and gets the preview running, and
  /// reports what it can do.
  ///
  /// Every open starts with the flash off, whatever the last session left it
  /// on (F24: a retake starts dark).
  ///
  /// Safe to call again after a failure or after the OS reclaimed the camera
  /// while the app was backgrounded.
  Future<Result<CameraCapabilities, AppFailure>> initialize();

  /// Takes one photo and returns the file it was written to.
  Future<Result<CapturedPhoto, AppFailure>> capturePhoto();

  /// Sets the flash for the next shot. Fails on a camera without a flash.
  Future<Result<void, AppFailure>> setFlashMode(CameraFlashMode mode);

  /// Focuses (and meters, where the lens supports it) on [point] of the
  /// preview. Fails on a lens that cannot focus on a chosen point.
  Future<Result<void, AppFailure>> focusAt(FocusPoint point);

  /// Releases the camera. Idempotent — calling it twice is harmless.
  Future<void> dispose();
}
