import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/focus_point.dart';
import '../services/camera_service.dart';

/// Focuses the camera where the user tapped the preview (F24).
final class FocusCamera {
  const FocusCamera(this._service);

  final CameraService _service;

  Future<Result<void, AppFailure>> call(FocusPoint point) =>
      _service.focusAt(point);
}
