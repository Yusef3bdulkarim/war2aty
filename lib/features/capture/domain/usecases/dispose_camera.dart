import '../services/camera_service.dart';

/// Releases the camera when the viewfinder closes.
///
/// Returns nothing to react to: tearing the camera down cannot meaningfully
/// fail from the user's point of view, and there is no UI left to show an error
/// on by the time it runs.
final class DisposeCamera {
  const DisposeCamera(this._service);

  final CameraService _service;

  Future<void> call() => _service.dispose();
}
