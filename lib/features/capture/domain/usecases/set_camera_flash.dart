import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/camera_flash_mode.dart';
import '../services/camera_service.dart';

/// Sets the flash the next shot fires with (F24).
final class SetCameraFlash {
  const SetCameraFlash(this._service);

  final CameraService _service;

  Future<Result<void, AppFailure>> call(CameraFlashMode mode) =>
      _service.setFlashMode(mode);
}
