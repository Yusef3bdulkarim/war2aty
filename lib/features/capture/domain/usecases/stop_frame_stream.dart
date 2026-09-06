import '../services/camera_service.dart';

/// Stops the live edge detector's frame feed (F16).
///
/// Returns nothing to react to, like [DisposeCamera]: stopping a stream cannot
/// meaningfully fail from the user's point of view, and the viewfinder with
/// detection stopped simply shows no guide.
final class StopFrameStream {
  const StopFrameStream(this._service);

  final CameraService _service;

  Future<void> call() => _service.stopFrameStream();
}
