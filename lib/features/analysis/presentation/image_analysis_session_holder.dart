import '../../../core/storage/analysis_session.dart';
import '../../capture/domain/entities/captured_photo.dart';

/// In-memory holder for the perspective-corrected photo the online route
/// (F13) hands off to the analysis feature — the online counterpart of
/// `OcrSessionHolder`.
///
/// Set by the capture flow once perspective correction succeeds, read by the
/// result route when it builds [AnalysisResultCubit]. The route's own `extra`
/// is dropped when the OS kills and restores the app mid-scan, so this
/// instance is the source of truth, not the navigation state.
final class ImageAnalysisSessionHolder {
  AnalysisSession? session;
  CapturedPhoto? photo;

  void set(AnalysisSession s, CapturedPhoto p) {
    session = s;
    photo = p;
  }

  void clear() {
    session = null;
    photo = null;
  }
}
