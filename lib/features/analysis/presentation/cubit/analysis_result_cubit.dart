import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analysis/usecases/get_analysis_consent.dart';
import '../../../../core/documents/usecases/build_analysis_result.dart';
import '../../../../core/error/app_failure.dart';
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
/// - [GetAnalysisConsent] — whether the user allows data to leave the phone at
///   all (F11-T02); checked before anything is sent on either route.
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
    required GetAnalysisConsent getAnalysisConsent,
    required AnalyzeDocument analyzeDocument,
    required AnalyzeImage analyzeImage,
    required BuildAnalysisResult buildResult,
    VoidCallback? onImageConsumed,
  }) : _session = session,
       _source = source,
       _getAnalysisConsent = getAnalysisConsent,
       _analyzeDocument = analyzeDocument,
       _analyzeImage = analyzeImage,
       _buildResult = buildResult,
       _onImageConsumed = onImageConsumed,
       super(const AnalysisResultAnalyzing());

  final AnalysisSession _session;
  final AnalysisSource _source;
  final GetAnalysisConsent _getAnalysisConsent;
  final AnalyzeDocument _analyzeDocument;
  final AnalyzeImage _analyzeImage;
  final BuildAnalysisResult _buildResult;

  /// Called once after [_analyzeImage] has finished reading the
  /// perspective-corrected file's bytes (success or failure). The file is no
  /// longer needed and can be safely deleted — wired to
  /// `ImageAnalysisSessionHolder.clear()` by the router.
  VoidCallback? _onImageConsumed;

  /// Runs the analysis. Called once when the screen mounts, and again by the
  /// retry on the failure view.
  Future<void> analyze() async {
    if (isClosed) return;
    emit(const AnalysisResultAnalyzing());

    // The cleaned text (for OCR route) or empty string (for online route):
    // it is what the extracted-text section — or every fallback page — shows
    // the user. The online route has no local OCR text to fall back to; the
    // section simply drops itself when this is empty (§4).
    final extractedText = switch (_source) {
      OcrAnalysisSource(:final extraction) => extraction.text.cleanedText,
      ImageAnalysisSource() => '',
    };

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

    // The repository has finished reading the corrected file's bytes (or
    // failed trying). Either way, the file on disk is no longer needed and
    // can be safely deleted — privacy §7 mandates that no unencrypted temp
    // copy survives past consumption.
    _onImageConsumed?.call();
    _onImageConsumed = null;

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
