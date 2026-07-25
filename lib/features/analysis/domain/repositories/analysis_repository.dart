import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/analysis_request.dart';
import '../entities/document_analysis.dart';

/// Turns a local OCR result into an understood document.
///
/// The only route to the analysis service. Implementations never throw — an
/// unreachable server, a rejected request, a quota exhaustion and an
/// unsupported document all come back as an [AppFailure].
abstract interface class AnalysisRepository {
  Future<Result<DocumentAnalysis, AppFailure>> analyze(AnalysisRequest request);
}
