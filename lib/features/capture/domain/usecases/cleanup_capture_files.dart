import '../services/capture_file_cleanup.dart';

/// Deletes the temporary files a capture flow produced (source photo, rotated
/// copy). Called when the preview cubit closes — whether the user confirmed,
/// retook, or navigated away.
final class CleanupCaptureFiles {
  const CleanupCaptureFiles(this._cleanup);

  final CaptureFileCleanup _cleanup;

  Future<void> call(List<String> paths) => _cleanup.deleteFiles(paths);
}
