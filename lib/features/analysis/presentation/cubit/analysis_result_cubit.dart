import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/analysis_session.dart';
import '../../../ocr/domain/entities/extraction_result.dart';
import '../../domain/entities/analysis_request.dart';
import '../../domain/usecases/analyze_document.dart';
import '../../domain/usecases/build_analysis_result.dart';
import 'analysis_result_state.dart';

/// Drives one analysis run and the result screen that follows it.
///
/// Depends on two use cases only (architecture rule):
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
    required AnalyzeDocument analyzeDocument,
    required BuildAnalysisResult buildResult,
  }) : _session = session,
       _extraction = extraction,
       _analyzeDocument = analyzeDocument,
       _buildResult = buildResult,
       super(const AnalysisResultAnalyzing());

  final AnalysisSession _session;
  final ExtractionResult _extraction;
  final AnalyzeDocument _analyzeDocument;
  final BuildAnalysisResult _buildResult;

  /// Runs the analysis. Called once when the screen mounts, and again by the
  /// retry on the failure view.
  Future<void> analyze() async {
    if (isClosed) return;
    emit(const AnalysisResultAnalyzing());

    final outcome = await _analyzeDocument(
      AnalysisRequest(
        sessionId: _session.id,
        extraction: _extraction,
        detectedLanguages: _extraction.detectedLanguages,
      ),
    );
    if (isClosed) return;

    // The cleaned text, not the raw one: it is what the analysis read and what
    // the extracted-text section — or the fallback page — shows the user.
    final extractedText = _extraction.text.cleanedText;

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
