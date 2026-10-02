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

  /// Runs OCR only (F14) — the first half of the online route's two-call
  /// split. Sends the captured image and stops at the OCR text and
  /// candidates; the caller reviews them before deciding whether to spend an
  /// analysis on [analyze], which only ever sends text (F20-T19).
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  );
}
