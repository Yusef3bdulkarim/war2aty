import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analysis/usecases/get_analysis_consent.dart';
import '../../../../core/documents/usecases/build_analysis_result.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/storage/analysis_session.dart';
import '../../../ocr/domain/entities/extraction_result.dart';
import '../../domain/entities/analysis_request.dart';
import '../../domain/usecases/analyze_document.dart';
import 'analysis_result_state.dart';

/// Drives one analysis run and the result screen that follows it.
///
/// Depends on three use cases only (architecture rule):
/// - [GetAnalysisConsent] — whether the user still allows the text to leave
///   the phone at all (F11-T02); checked before anything is sent.
/// - [AnalyzeDocument] — sends the OCR text off and brings back the
///   understanding, or a classified failure.
/// - [BuildAnalysisResult] — orders and filters the sections to draw.
///
/// What leaves the phone is decided by [AnalysisRequest], which has no field
/// for the image or its path: this cubit holds the session only for its id
/// (privacy §7).
final class AnalysisResultCubit extends Cubit<AnalysisResultState> {
  AnalysisResultCubit({
    required AnalysisSession session,
    required ExtractionResult extraction,
    required GetAnalysisConsent getAnalysisConsent,
    required AnalyzeDocument analyzeDocument,
    required BuildAnalysisResult buildResult,
  }) : _session = session,
       _extraction = extraction,
       _getAnalysisConsent = getAnalysisConsent,
       _analyzeDocument = analyzeDocument,
       _buildResult = buildResult,
       super(const AnalysisResultAnalyzing());

  final AnalysisSession _session;
  final ExtractionResult _extraction;
  final GetAnalysisConsent _getAnalysisConsent;
  final AnalyzeDocument _analyzeDocument;
  final BuildAnalysisResult _buildResult;

  /// Runs the analysis. Called once when the screen mounts, and again by the
  /// retry on the failure view.
  Future<void> analyze() async {
    if (isClosed) return;
    emit(const AnalysisResultAnalyzing());

    // The cleaned text, not the raw one: it is what the analysis reads (when
    // consent allows it) and what the extracted-text section — or every
    // fallback page — shows the user.
    final extractedText = _extraction.text.cleanedText;

    // Consent is checked here, before a single byte leaves the phone — never
    // inside the repository/data source, which has no business deciding this
    // (§5 layer rule: presentation orchestrates, data only executes).
    if (!await _getAnalysisConsent()) {
      if (isClosed) return;
      emit(
        AnalysisResultFailed(
          const AnalysisConsentDeclinedFailure(),
          extractedText,
        ),
      );
      return;
    }
    if (isClosed) return;

    final outcome = await _analyzeDocument(
      AnalysisRequest(
        sessionId: _session.id,
        extraction: _extraction,
        detectedLanguages: _extraction.detectedLanguages,
      ),
    );
    if (isClosed) return;

    emit(
      outcome.when(
        ok: (analysis) => AnalysisResultReady(
          _buildResult(analysis: analysis, extractedText: extractedText),
        ),
        err: (failure) => AnalysisResultFailed(failure, extractedText),
      ),
    );
  }
}
