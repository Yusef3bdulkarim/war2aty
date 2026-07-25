import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/storage/analysis_session.dart';
import '../../domain/usecases/extract_candidates.dart';
import '../../domain/usecases/extract_document_text.dart';
import '../ocr_session_holder.dart';
import 'ocr_processing_state.dart';

/// Drives the full OCR pipeline for one [AnalysisSession]:
/// preprocess → OCR → normalize → extract candidates.
///
/// Depends on two use cases only (architecture rule):
/// - [ExtractDocumentText] — preprocessing + OCR + minimum-text check.
/// - [ExtractCandidates] — normalization + all five extractors.
final class OcrProcessingCubit extends Cubit<OcrProcessingState> {
  OcrProcessingCubit({
    required AnalysisSession session,
    required ExtractDocumentText extractText,
    required ExtractCandidates extractCandidates,
    required OcrSessionHolder sessionHolder,
  }) : _session = session,
       _extractText = extractText,
       _extractCandidates = extractCandidates,
       _sessionHolder = sessionHolder,
       super(const OcrProcessing());

  final AnalysisSession _session;
  final ExtractDocumentText _extractText;
  final ExtractCandidates _extractCandidates;
  final OcrSessionHolder _sessionHolder;

  /// Starts the pipeline. Called once when the screen mounts.
  Future<void> process() async {
    if (isClosed) return;
    emit(const OcrProcessing());

    final textResult = await _extractText(_session.imagePath);
    if (isClosed) return;

    final ocrResult = textResult.when(
      ok: (result) => result,
      err: (failure) {
        if (failure is NoTextDetectedFailure) {
          emit(const OcrNoText());
        } else {
          emit(const OcrError());
        }
        return null;
      },
    );

    if (ocrResult == null) return;

    final extraction = _extractCandidates(ocrResult);
    if (isClosed) return;

    emit(OcrCompleted(extraction));
  }

  /// Stores the completed result for F05 handoff. Called when the user
  /// taps "متابعة" (continue).
  void confirm() {
    final s = state;
    if (s is OcrCompleted) {
      _sessionHolder.set(_session, s.result);
    }
  }
}
