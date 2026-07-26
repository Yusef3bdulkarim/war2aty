import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../entities/image_quality_result.dart';
import '../services/image_quality_service.dart';

/// Scores a photo's blur, resolution, and brightness for OCR readiness.
final class AssessImageQuality {
  const AssessImageQuality(this._service);

  final ImageQualityService _service;

  Future<Result<ImageQualityResult, AppFailure>> call(CapturedPhoto photo) =>
      _service.assess(photo);
}
