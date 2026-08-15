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
/// This holder also owns the lifecycle of **every** temp file the capture flow
/// produced (source, rotated copy, corrected copy). The preview cubit hands
/// ownership here instead of deleting them in its own `close()`, because
/// `pushReplacement` disposes the preview route in the same frame the result
/// route tries to read the image — deleting early races against the read.
/// [clear] deletes them all once the analysis is done or abandoned (§7).
final class ImageAnalysisSessionHolder {
  AnalysisSession? session;
  CapturedPhoto? photo;

  /// Every temp file the capture flow created — source, rotated, corrected.
  /// Owned by this holder once the online handoff fires; deleted in [clear].
  List<String>? _captureCleanupPaths;

  void set(
    AnalysisSession s,
    CapturedPhoto p, {
    List<String>? cleanupPaths,
  }) {
    session = s;
    photo = p;
    _captureCleanupPaths = cleanupPaths;
  }

  /// Releases the session and photo, deleting every temp file on disk.
  ///
  /// Best-effort: a failure to delete must never surface to the user.
  void clear() {
    final paths = _captureCleanupPaths;
    if (paths != null) {
      for (final path in paths) {
        unawaited(File(path).delete().catchError((_) => File(path)));
      }
    }
    session = null;
    photo = null;
    _captureCleanupPaths = null;
  }
}
