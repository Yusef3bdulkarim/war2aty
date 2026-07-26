import '../../../core/storage/analysis_session.dart';
import '../domain/entities/extraction_result.dart';

/// In-memory holder for the OCR result that F05 (AI analysis) will consume.
///
/// Set by the OCR flow when the user taps "متابعة", read by the analysis
/// feature when it starts. Cleared after consumption to prevent stale data.
final class OcrSessionHolder {
  AnalysisSession? session;
  ExtractionResult? result;

  void set(AnalysisSession s, ExtractionResult r) {
    session = s;
    result = r;
  }

  void clear() {
    session = null;
    result = null;
  }
}
