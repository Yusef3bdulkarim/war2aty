import '../../../../core/error/app_failure.dart';
import '../../domain/entities/camera_capabilities.dart';
import '../../domain/entities/camera_flash_mode.dart';
import '../../domain/entities/captured_photo.dart';

/// Where the viewfinder stands.
///
/// Sealed so the screen must handle every case — the design gives loading, a
/// live preview, and an error each its own distinct look.
sealed class CameraCaptureState {
  const CameraCaptureState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Opening the camera. The screen shows the dark backdrop with a spinner.
final class CameraInitializing extends CameraCaptureState {
  const CameraInitializing();
}

/// The live preview is on screen — armed ([CameraReady]) or mid-shot
/// ([CameraCapturing]). Both draw the same dock, so both carry what it shows.
sealed class CameraLive extends CameraCaptureState {
  const CameraLive({
    this.flashMode = CameraFlashMode.off,
    this.capabilities = CameraCapabilities.none,
  });

  /// The flash the shot fires with. Always [CameraFlashMode.off] when the
  /// camera has just opened (F24).
  final CameraFlashMode flashMode;

  /// What the open camera can do — whether to offer the flash button, and
  /// whether a tap on the preview focuses.
  final CameraCapabilities capabilities;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is CameraLive &&
      other.flashMode == flashMode &&
      other.capabilities == capabilities;

  @override
  int get hashCode => Object.hash(runtimeType, flashMode, capabilities);
}

/// The live preview is running; the shutter is armed.
final class CameraReady extends CameraLive {
  const CameraReady({super.flashMode, super.capabilities});
}

/// A shot is being taken. The shutter is disabled so a second tap cannot fire
/// a second capture over the first.
final class CameraCapturing extends CameraLive {
  const CameraCapturing({super.flashMode, super.capabilities});
}

/// A photo was written to disk; the screen hands [photo] on to the next stage.
final class CameraCaptured extends CameraCaptureState {
  const CameraCaptured(this.photo);

  final CapturedPhoto photo;

  @override
  bool operator ==(Object other) =>
      other is CameraCaptured && other.photo == photo;

  @override
  int get hashCode => photo.hashCode;
}

/// The camera could not be opened, or a shot failed. The screen shows the
/// error with a retry that re-opens the camera from scratch.
final class CameraCaptureError extends CameraCaptureState {
  const CameraCaptureError(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is CameraCaptureError && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
