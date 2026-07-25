import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/analysis_request.dart';
import '../entities/document_analysis.dart';
import '../repositories/analysis_repository.dart';

/// Analyses one captured document.
///
/// The single entry point the presentation layer is allowed to call — cubits
/// depend on use cases, never on repositories or datasources.
final class AnalyzeDocument {
  const AnalyzeDocument(this._repository);

  final AnalysisRepository _repository;

  Future<Result<DocumentAnalysis, AppFailure>> call(AnalysisRequest request) {
    return _repository.analyze(request);
  }
}
