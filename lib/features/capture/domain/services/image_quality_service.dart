import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../entities/image_quality_result.dart';

/// Evaluates a captured photo for blur, resolution, and brightness to decide
/// whether it is suitable for OCR.
///
/// Pure Dart: no Flutter, no plugin. Implementations run the pixel math in an
/// isolate so the UI thread stays free.
abstract interface class ImageQualityService {
  Future<Result<ImageQualityResult, AppFailure>> assess(CapturedPhoto photo);
}
