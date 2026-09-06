import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/camera_frame.dart';
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
  ///
  /// Stops any running frame stream first — on several Android devices a live
  /// image stream and `takePicture` contend for the same hardware, and the
  /// shutter is the one that must never lose (F16-T04).
  Future<Result<CapturedPhoto, AppFailure>> capturePhoto();

  /// Starts delivering preview frames to [onFrame], for the live edge
  /// detection that aims the viewfinder's guide (F16).
  ///
  /// Frames are **dropped, never queued**: a frame that arrives while the
  /// previous [onFrame] future is still pending, or sooner than the
  /// implementation's minimum interval, is discarded. The consumer therefore
  /// never falls behind the camera, and memory never grows with a backlog.
  ///
  /// Failing to start is not a user-facing error (F16 locked decision #4) —
  /// the caller simply carries on with no guide drawn.
  Future<Result<void, AppFailure>> startFrameStream(
    Future<void> Function(CameraFrame frame) onFrame,
  );

  /// Stops the frame stream. Idempotent, and safe to call when none is
  /// running.
  Future<void> stopFrameStream();

  /// Releases the camera. Idempotent — calling it twice is harmless.
  Future<void> dispose();
}
