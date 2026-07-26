import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../services/image_rotator.dart';

/// Applies the rotation the user chose in the preview, producing the upright
/// image the next stage works from.
final class RotateImage {
  const RotateImage(this._rotator);

  final ImageRotator _rotator;

  Future<Result<CapturedPhoto, AppFailure>> call(
    CapturedPhoto photo,
    int quarterTurns,
  ) => _rotator.rotate(photo, quarterTurns);
}
