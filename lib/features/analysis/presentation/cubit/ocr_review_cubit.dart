import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/analysis/usecases/get_analysis_consent.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/storage/analysis_session.dart';
import '../../../capture/domain/entities/captured_photo.dart';
import '../../../ocr/domain/entities/extraction_result.dart';
import '../../../ocr/domain/entities/ocr_result.dart';
import '../../../ocr/domain/usecases/extract_candidates.dart';
import '../../domain/entities/analysis_image_request.dart';
import '../../domain/usecases/ocr_image.dart';
import '../image_analysis_session_holder.dart';
import 'ocr_review_state.dart';

/// Drives the OCR review screen — the unified stop between OCR (online or
/// offline) and Groq analysis.
///
/// Two construction paths:
/// - **Online** (default constructor): takes a [CapturedPhoto], runs Azure OCR
///   via [OcrImage], checks consent via [GetAnalysisConsent]. Caller invokes
///   [runOcr] on mount.
/// - **Offline** ([OcrReviewCubit.offline]): the Tesseract OCR already ran on
///   `OcrProcessingScreen`; this cubit receives the finished
///   [ExtractionResult] and emits [OcrReviewReady] immediately. Caller
///   invokes [loadOffline] on mount.
///
/// Depends on use cases only (architecture rule):
/// - [GetAnalysisConsent] — same F11-T02 gate [AnalysisResultCubit] checks,
///   run here too since this is now the first thing that sends data off the
///   phone on the online route.
/// - [OcrImage] — runs Azure OCR + extractors, stops short of Groq.
/// - [ExtractCandidates] — reruns normalization + all five extractors on the
///   user's *approved* text, so Groq never receives a candidate that does not
///   match what the user actually reviewed (locked correction #1).
final class OcrReviewCubit extends Cubit<OcrReviewState> {
  /// Online path: Azure OCR runs inside this cubit.
  OcrReviewCubit({
    required AnalysisSession session,
    required CapturedPhoto photo,
    required OcrImage ocrImage,
    required ExtractCandidates extractCandidates,
    required GetAnalysisConsent getAnalysisConsent,
    required ImageAnalysisSessionHolder imageHolder,
  }) : _session = session,
       _photo = photo,
       _ocrImage = ocrImage,
       _extractCandidates = extractCandidates,
       _getAnalysisConsent = getAnalysisConsent,
       _imageHolder = imageHolder,
       super(const OcrReviewLoading());

  /// Offline path: Tesseract OCR already finished on [OcrProcessingScreen].
  OcrReviewCubit.offline({
    required AnalysisSession session,
    required ExtractCandidates extractCandidates,
  }) : _session = session,
       _photo = null,
       _ocrImage = null,
       _extractCandidates = extractCandidates,
       _getAnalysisConsent = null,
       _imageHolder = null,
       super(const OcrReviewLoading());

  final AnalysisSession _session;
  final CapturedPhoto? _photo;
  final OcrImage? _ocrImage;
  final ExtractCandidates _extractCandidates;
  final GetAnalysisConsent? _getAnalysisConsent;
  final ImageAnalysisSessionHolder? _imageHolder;

  /// Calls the ocr-document endpoint. Called once when the screen mounts
  /// (online path only).
  ///
  /// The image is not touched here beyond reading its bytes — it stays on
  /// disk through [OcrReviewReady]/[OcrReviewPoorQuality]/[OcrReviewFailed]
  /// so the user can view it during review (F14 image lifecycle). Cleanup is
  /// explicit, via [cleanupImage] or [close].
  Future<void> runOcr() async {
    if (isClosed) return;
    emit(const OcrReviewLoading());

    // Same gate `AnalysisResultCubit.analyze` checks (F11-T02) — this screen
    // is now the first place the online route sends anything off the phone,
    // so the consent check moves here rather than staying only on /result.
    final consent = _getAnalysisConsent;
    if (consent != null && !await consent()) {
      if (isClosed) return;
      emit(const OcrReviewFailed(AnalysisConsentDeclinedFailure()));
      return;
    }
    if (isClosed) return;

    final photo = _photo;
    final ocrImage = _ocrImage;
    if (photo == null || ocrImage == null) {
      // Should never happen: `runOcr` is only called on the online path,
      // which always supplies both. Guard rather than crash (CLAUDE.md §A3).
      emit(const OcrReviewFailed(OcrFailure()));
      return;
    }

    final result = await ocrImage(
      AnalysisImageRequest(sessionId: _session.id, photo: photo),
    );
    if (isClosed) return;

    emit(result.when(ok: _readyOrPoorQuality, err: OcrReviewFailed.new));
  }

  /// Loads an already-completed offline [ExtractionResult] directly into the
  /// review state. Called once when the screen mounts (offline path only).
  void loadOffline(ExtractionResult result) {
    if (isClosed) return;
    final text = result.text.cleanedText;
    if (text.trim().isEmpty) {
      emit(OcrReviewPoorQuality(imagePath: _session.imagePath));
      return;
    }
    emit(
      OcrReviewReady(
        originalOcrText: text,
        reviewedOcrText: text,
        serverCandidates: result,
        detectedLanguages: result.detectedLanguages,
        imagePath: _session.imagePath,
        isOffline: true,
      ),
    );
  }

  OcrReviewState _readyOrPoorQuality(ExtractionResult extraction) {
    final text = extraction.text.cleanedText;
    if (text.trim().isEmpty) {
      return OcrReviewPoorQuality(imagePath: _photo?.path);
    }
    return OcrReviewReady(
      originalOcrText: text,
      reviewedOcrText: text,
      serverCandidates: extraction,
      detectedLanguages: extraction.detectedLanguages,
      imagePath: _photo?.path,
    );
  }

  /// The user edited the OCR text field. A no-op outside [OcrReviewReady] —
  /// the text field only exists in that state.
  void updateOcrText(String text) {
    final current = state;
    if (current is! OcrReviewReady) return;
    emit(
      OcrReviewReady(
        originalOcrText: current.originalOcrText,
        reviewedOcrText: text,
        serverCandidates: current.serverCandidates,
        detectedLanguages: current.detectedLanguages,
        imagePath: current.imagePath,
        isOffline: current.isOffline,
      ),
    );
  }

  /// Builds the final [ExtractionResult] from the user-approved text, for the
  /// caller to hand to `OcrSessionHolder` before navigating to `/result`.
  ///
  /// Re-runs [ExtractCandidates] on [OcrReviewReady.reviewedOcrText] rather
  /// than reusing [OcrReviewReady.serverCandidates] — those were extracted
  /// from Azure's original text and would go stale the moment the user edits
  /// a date or amount (locked correction #1).
  ///
  /// Only ever called from the Analyze button, which only exists in
  /// [OcrReviewReady] — a call from any other state is a caller bug.
  ExtractionResult buildReviewedResult() {
    final current = state;
    if (current is! OcrReviewReady) {
      throw StateError(
        'OcrReviewCubit.buildReviewedResult() called outside OcrReviewReady',
      );
    }
    final ocrResult = OcrResult(
      originalText: current.reviewedOcrText,
      detectedLanguages: current.detectedLanguages,
    );
    return _extractCandidates(ocrResult);
  }

  /// Deletes the temp corrected image. Called explicitly before leaving the
  /// screen on every exit path — analyze, retake, pick another.
  ///
  /// A no-op on the offline path where [_imageHolder] is `null` — the offline
  /// image lifecycle is managed by the caller, not this cubit.
  void cleanupImage() {
    _imageHolder?.clear();
  }

  @override
  Future<void> close() {
    // Safety net for the one exit path with no button: the user backs out or
    // the app is killed mid-review. `clear()` is idempotent, so this is a
    // no-op when [cleanupImage] already ran (privacy §7 — no temp copy may
    // outlive the flow that created it).
    _imageHolder?.clear();
    return super.close();
  }
}
