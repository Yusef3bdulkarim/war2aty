import '../../../../core/documents/document_analysis.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../ocr/domain/entities/extraction_result.dart';
import '../entities/analysis_image_request.dart';
import '../entities/analysis_request.dart';

/// Turns a local OCR result into an understood document.
///
/// The only route to the analysis service. Implementations never throw — an
/// unreachable server, a rejected request, a quota exhaustion and an
/// unsupported document all come back as an [AppFailure].
abstract interface class AnalysisRepository {
  Future<Result<DocumentAnalysis, AppFailure>> analyze(AnalysisRequest request);

  /// Online-only counterpart of [analyze] (F13-T14): sends the captured image
  /// itself instead of local OCR output. Same result contract, same failure
  /// surface — callers do not need to know which route produced either.
  Future<Result<DocumentAnalysis, AppFailure>> analyzeImage(
    AnalysisImageRequest request,
  );

  /// Runs OCR only (F14) — the first half of the online route's two-call
  /// split. Sends the same image [request] as [analyzeImage], but stops at
  /// the OCR text and candidates instead of reaching Groq; the caller reviews
  /// them before deciding whether to spend an analysis on [analyze].
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  );
}
