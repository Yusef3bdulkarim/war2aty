import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../entities/unit_rect.dart';
import '../services/image_cropper.dart';

/// Bakes a fractional crop region into a file.
final class CropImage {
  const CropImage(this._cropper);

  final ImageCropper _cropper;

  Future<Result<CapturedPhoto, AppFailure>> call(
    CapturedPhoto photo,
    UnitRect region,
  ) => _cropper.crop(photo, region);
}
