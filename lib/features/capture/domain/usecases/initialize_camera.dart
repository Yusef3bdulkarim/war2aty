import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../services/camera_service.dart';

/// Starts the camera when the viewfinder opens.
final class InitializeCamera {
  const InitializeCamera(this._service);

  final CameraService _service;

  Future<Result<void, AppFailure>> call() => _service.initialize();
}
