import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../ocr/domain/entities/extraction_result.dart';
import '../entities/analysis_image_request.dart';
import '../repositories/analysis_repository.dart';

/// Runs OCR only on one captured document over the online route (F14) — the
/// first half of the two-call split, before the user reviews the text and
/// [AnalyzeDocument] sends the approved version on to Groq.
///
/// The single entry point [OcrReviewCubit] is allowed to call — cubits depend
/// on use cases, never on repositories or datasources.
final class OcrImage {
  const OcrImage(this._repository);

  final AnalysisRepository _repository;

  Future<Result<ExtractionResult, AppFailure>> call(
    AnalysisImageRequest request,
  ) {
    return _repository.ocrImage(request);
  }
}
