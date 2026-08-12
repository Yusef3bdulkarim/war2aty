import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/usecases/build_analysis_result.dart';
import '../../../../core/storage/analysis_session.dart';
import '../../domain/entities/analysis_image_request.dart';
import '../../domain/entities/analysis_request.dart';
import '../../domain/entities/analysis_source.dart';
import '../../domain/usecases/analyze_document.dart';
import '../../domain/usecases/analyze_image.dart';
import 'analysis_result_state.dart';

/// Drives one analysis run and the result screen that follows it.
///
/// Depends on use cases only (architecture rule):
/// - [AnalyzeDocument] — sends the OCR text off, for [OcrAnalysisSource].
/// - [AnalyzeImage] — sends the perspective-corrected image off instead, for
///   [ImageAnalysisSource] (F13 online route — OCR is skipped entirely).
/// - [BuildAnalysisResult] — orders and filters the sections to draw.
///
/// What leaves the phone for the offline route is decided by
/// [AnalysisRequest], which has no field for the image or its path; the
/// online route's entire reason to exist is sending the image instead (F13
/// locked decisions — a privacy-model change). Either way this cubit holds
/// the session only for its id (privacy §7).
final class AnalysisResultCubit extends Cubit<AnalysisResultState> {
  AnalysisResultCubit({
    required AnalysisSession session,
    required AnalysisSource source,
    required AnalyzeDocument analyzeDocument,
    required AnalyzeImage analyzeImage,
    required BuildAnalysisResult buildResult,
  }) : _session = session,
       _source = source,
       _analyzeDocument = analyzeDocument,
       _analyzeImage = analyzeImage,
       _buildResult = buildResult,
       super(const AnalysisResultAnalyzing());

  final AnalysisSession _session;
  final AnalysisSource _source;
  final AnalyzeDocument _analyzeDocument;
  final AnalyzeImage _analyzeImage;
  final BuildAnalysisResult _buildResult;

  /// Runs the analysis. Called once when the screen mounts, and again by the
  /// retry on the failure view.
  Future<void> analyze() async {
    if (isClosed) return;
    emit(const AnalysisResultAnalyzing());

    final outcome = await switch (_source) {
      OcrAnalysisSource(:final extraction) => _analyzeDocument(
        AnalysisRequest(
          sessionId: _session.id,
          extraction: extraction,
          detectedLanguages: extraction.detectedLanguages,
        ),
      ),
      ImageAnalysisSource(:final photo) => _analyzeImage(
        AnalysisImageRequest(sessionId: _session.id, photo: photo),
      ),
    };
    if (isClosed) return;

    // The cleaned text, not the raw one: it is what the analysis read and
    // what the extracted-text section — or the fallback page — shows the
    // user. The online route has no local OCR text to fall back to; the
    // section simply drops itself when this is empty (§4).
    final extractedText = switch (_source) {
      OcrAnalysisSource(:final extraction) => extraction.text.cleanedText,
      ImageAnalysisSource() => '',
    };

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
