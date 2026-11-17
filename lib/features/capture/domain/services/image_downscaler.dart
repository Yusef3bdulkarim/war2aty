import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';

abstract interface class ImageDownscaler {
  Future<Result<CapturedPhoto, AppFailure>> downscale(CapturedPhoto photo);
}
