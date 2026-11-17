import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../services/image_downscaler.dart';

final class DownscalePhoto {
  const DownscalePhoto(this._downscaler);

  final ImageDownscaler _downscaler;

  Future<Result<CapturedPhoto, AppFailure>> call(CapturedPhoto photo) =>
      _downscaler.downscale(photo);
}
