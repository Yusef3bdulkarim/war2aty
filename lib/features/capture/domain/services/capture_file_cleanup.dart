/// Deletes temporary capture files (source photo, rotated copy) so no
/// unencrypted page image outlives its analysis session (privacy §7).
abstract interface class CaptureFileCleanup {
  /// Best-effort deletion of every file in [paths].
  ///
  /// Missing files are silently skipped; filesystem errors are swallowed —
  /// cleanup is fire-and-forget by design, so a failure must never block the
  /// user or surface as a visible error.
  Future<void> deleteFiles(List<String> paths);
}
