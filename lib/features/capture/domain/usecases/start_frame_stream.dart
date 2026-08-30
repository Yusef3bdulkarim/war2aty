import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/camera_frame.dart';
import '../services/camera_service.dart';

/// Starts feeding preview frames to the live edge detector (F16).
///
/// Exists so the cubit reaches the camera through a use case like everything
/// else it does (CLAUDE.md §B.2) rather than holding the service directly.
final class StartFrameStream {
  const StartFrameStream(this._service);

  final CameraService _service;

  Future<Result<void, AppFailure>> call(
    Future<void> Function(CameraFrame frame) onFrame,
  ) => _service.startFrameStream(onFrame);
}
