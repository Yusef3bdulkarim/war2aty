import '../services/camera_service.dart';

/// Stops the live edge detector's frame feed (F16).
///
/// Returns nothing to react to, like [DisposeCamera]: stopping a stream cannot
/// meaningfully fail from the user's point of view, and the fallback when
/// detection is not running is simply the static guide box.
final class StopFrameStream {
  const StopFrameStream(this._service);

  final CameraService _service;

  Future<void> call() => _service.stopFrameStream();
}
