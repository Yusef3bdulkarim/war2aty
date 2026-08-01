import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/analysis_image_request.dart';
import '../entities/document_analysis.dart';
import '../repositories/analysis_repository.dart';

/// Analyses one captured document over the online (image) route (F13-T14).
///
/// The single entry point the capture flow is allowed to call for the online
/// path — cubits depend on use cases, never on repositories or datasources.
final class AnalyzeImage {
  const AnalyzeImage(this._repository);

  final AnalysisRepository _repository;

  Future<Result<DocumentAnalysis, AppFailure>> call(
    AnalysisImageRequest request,
  ) {
    return _repository.analyzeImage(request);
  }
}
