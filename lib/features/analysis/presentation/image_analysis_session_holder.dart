import 'dart:async';
import 'dart:io';

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
///
/// This holder also owns the lifecycle of the corrected file: when the
/// preview cubit's `close()` fires (via `pushReplacement`), the file must
/// survive until the analysis repository has read its bytes. [clear] deletes
/// it once the analysis is done or abandoned (privacy §7).
final class ImageAnalysisSessionHolder {
  AnalysisSession? session;
  CapturedPhoto? photo;

  void set(AnalysisSession s, CapturedPhoto p) {
    session = s;
    photo = p;
  }

  /// Whether this holder currently owns [path] — i.e. the corrected file was
  /// handed off and must not be deleted by the preview cubit's cleanup.
  bool holdsCorrectedFile(String path) => photo?.path == path;

  /// Releases the session and photo, deleting the corrected file on disk.
  ///
  /// Best-effort: a failure to delete must never surface to the user.
  void clear() {
    final filePath = photo?.path;
    if (filePath != null) {
      // Fire-and-forget: the file is a temp copy that must not survive past
      // consumption (CLAUDE.md §7).
      unawaited(File(filePath).delete().catchError((_) => File(filePath)));
    }
    session = null;
    photo = null;
  }
}
