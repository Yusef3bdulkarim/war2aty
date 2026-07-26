import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../services/image_picker_service.dart';

/// Brings in a paper from an existing photo instead of the camera.
final class PickImageFromGallery {
  const PickImageFromGallery(this._service);

  final ImagePickerService _service;

  Future<Result<CapturedPhoto?, AppFailure>> call() =>
      _service.pickSingleImage();
}
