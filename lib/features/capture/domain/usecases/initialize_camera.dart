import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/camera_capabilities.dart';
import '../services/camera_service.dart';

/// Starts the camera when the viewfinder opens, and learns what it can do.
final class InitializeCamera {
  const InitializeCamera(this._service);

  final CameraService _service;

  Future<Result<CameraCapabilities, AppFailure>> call() =>
      _service.initialize();
}
