import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analysis/usecases/get_analysis_consent.dart';
import '../../../../core/documents/usecases/build_analysis_result.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/storage/analysis_session.dart';
import '../../../../core/usage/usecases/sync_daily_usage.dart';
import '../../domain/entities/analysis_request.dart';
import '../../domain/entities/analysis_source.dart';
import '../../domain/usecases/analyze_document.dart';
import 'analysis_result_state.dart';

/// Drives one analysis run and the result screen that follows it.
///
/// Depends on use cases only (architecture rule):
/// - [GetAnalysisConsent] — whether the user allows data to leave the phone at
///   all (F11-T02); checked before anything is sent.
/// - [AnalyzeDocument] — sends the reviewed OCR text off.
/// - [BuildAnalysisResult] — orders and filters the sections to draw.
/// - [SyncDailyUsage] — refreshes the cached quota after a *successful*
///   analysis, so Home's already-live usage stream reflects the consumed
///   slot without polling or client-side decrementing.
///
/// What leaves the phone is decided by [AnalysisRequest], which has no field
/// for the image or its path: every analysis is text, whichever route read
/// the page (F20-T19). This cubit holds the session only for its id
/// (privacy §7).
final class AnalysisResultCubit extends Cubit<AnalysisResultState> {
  AnalysisResultCubit({
    required AnalysisSession session,
    required AnalysisSource source,
    required GetAnalysisConsent getAnalysisConsent,
    required AnalyzeDocument analyzeDocument,
    required BuildAnalysisResult buildResult,
    required SyncDailyUsage syncDailyUsage,
  }) : _session = session,
       _source = source,
       _getAnalysisConsent = getAnalysisConsent,
       _analyzeDocument = analyzeDocument,
       _buildResult = buildResult,
       _syncDailyUsage = syncDailyUsage,
       super(const AnalysisResultAnalyzing());

  final AnalysisSession _session;
  final AnalysisSource _source;
  final GetAnalysisConsent _getAnalysisConsent;
  final AnalyzeDocument _analyzeDocument;
  final BuildAnalysisResult _buildResult;
  final SyncDailyUsage _syncDailyUsage;

  /// Runs the analysis. Called once when the screen mounts, and again by the
  /// retry on the failure view.
  Future<void> analyze() async {
    if (isClosed) return;
    emit(const AnalysisResultAnalyzing());

    final extraction = switch (_source) {
      OcrAnalysisSource(:final extraction) => extraction,
    };

    // The cleaned text is what the extracted-text section — or every fallback
    // page — shows the user.
    final extractedText = extraction.text.cleanedText;

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
        extraction: extraction,
        detectedLanguages: extraction.detectedLanguages,
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

    // Only a successful analysis consumed a daily slot — refresh the cached
    // usage row so Home's live stream reflects it. Fire-and-forget: never
    // blocks the result screen, and a failure here just leaves the previous
    // cached count in place until the next sync.
    if (outcome.isOk) unawaited(_syncDailyUsage());
  }
}
