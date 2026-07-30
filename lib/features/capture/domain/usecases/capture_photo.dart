import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../services/camera_service.dart';

/// Takes the single photo the shutter button asks for.
final class CapturePhoto {
  const CapturePhoto(this._service);

  final CameraService _service;

  Future<Result<CapturedPhoto, AppFailure>> call() => _service.capturePhoto();
}
