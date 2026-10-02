import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';

/// The camera, as the capture flow needs it — a stateful device session.
///
/// Pure Dart: no plugin, no Flutter. The live preview is a UI concern and does
/// not belong here; it is a separate presentation port
/// (`CameraPreview`) satisfied by the same implementation. This interface
/// carries only the fallible actions, each returning a typed [AppFailure]
/// rather than throwing, so use cases and the cubit never see an exception.
abstract interface class CameraService {
  /// Opens the back camera in portrait and gets the preview running.
  ///
  /// Safe to call again after a failure or after the OS reclaimed the camera
  /// while the app was backgrounded.
  Future<Result<void, AppFailure>> initialize();

  /// Takes one photo and returns the file it was written to.
  Future<Result<CapturedPhoto, AppFailure>> capturePhoto();

  /// Releases the camera. Idempotent — calling it twice is harmless.
  Future<void> dispose();
}
