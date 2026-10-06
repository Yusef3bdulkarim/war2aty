import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analysis/usecases/get_analysis_consent.dart';
import '../../../../core/documents/usecases/build_analysis_result.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/analysis_session.dart';
import '../../../../core/storage/usecases/discard_analysis_session.dart';
import '../../../../core/usage/usecases/get_daily_usage.dart';
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
/// - [GetDailyUsage] — reads the cached daily limit, only when the limit is
///   what stopped the analysis, so its page can name the number (F23 #14).
/// - [DiscardAnalysisSession] — deletes the session's working files when this
///   screen closes, which is where the scan actually ends (F27-T15).
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
    required GetDailyUsage getDailyUsage,
    required DiscardAnalysisSession discardSession,
  }) : _session = session,
       _source = source,
       _getAnalysisConsent = getAnalysisConsent,
       _analyzeDocument = analyzeDocument,
       _buildResult = buildResult,
       _syncDailyUsage = syncDailyUsage,
       _getDailyUsage = getDailyUsage,
       _discardSession = discardSession,
       super(const AnalysisResultAnalyzing());

  final AnalysisSession _session;
  final AnalysisSource _source;
  final GetAnalysisConsent _getAnalysisConsent;
  final AnalyzeDocument _analyzeDocument;
  final BuildAnalysisResult _buildResult;
  final SyncDailyUsage _syncDailyUsage;
  final GetDailyUsage _getDailyUsage;
  final DiscardAnalysisSession _discardSession;

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

    switch (outcome) {
      case Ok(:final value):
        emit(
          AnalysisResultReady(
            _buildResult(analysis: value, extractedText: extractedText),
          ),
        );
      case Err(failure: final DailyLimitReachedFailure failure):
        final dailyLimit = await _cachedDailyLimit();
        if (isClosed) return;
        emit(
          AnalysisResultFailed(failure, extractedText, dailyLimit: dailyLimit),
        );
      case Err(:final failure):
        emit(AnalysisResultFailed(failure, extractedText));
    }

    // Only a successful analysis consumed a daily slot — refresh the cached
    // usage row so Home's live stream reflects it. Fire-and-forget: never
    // blocks the result screen, and a failure here just leaves the previous
    // cached count in place until the next sync.
    if (outcome.isOk) unawaited(_syncDailyUsage());
  }

  /// The daily limit from the local cache — no network. `null` when there is
  /// nothing cached or the read fails: the page then words itself without a
  /// number rather than guess one.
  Future<int?> _cachedDailyLimit() async => switch (await _getDailyUsage()) {
    Ok(:final value) => value?.dailyLimit,
    Err() => null,
  };

  /// Deletes the session's working files on the way out.
  ///
  /// The result screen is the end of the scan: whatever the user did here —
  /// saved the paper with its picture, saved the result only, or saved
  /// nothing — the unencrypted copy under `analysis_sessions/` has no reader
  /// left, and §7 says it must not outlive the flow that made it. A
  /// save-with-image has already moved that file into the encrypted store, so
  /// this usually removes an empty folder.
  ///
  /// Fire-and-forget, like the usage sync above: `close()` must not wait on
  /// the filesystem, and the deletion cannot fail in a way anyone could act
  /// on.
  @override
  Future<void> close() {
    unawaited(_discardSession(_session.id));
    return super.close();
  }
}
