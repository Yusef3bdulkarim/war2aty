import '../analysis_session_storage.dart';

/// Deletes one analysis session's leftover temp working files once its
/// owner is done with them — `SaveDocumentCubit`'s use, today.
///
/// Thin wrapper so the presentation layer depends on a use case, never
/// [AnalysisSessionStorage] directly (architecture rule).
final class CleanupAnalysisSession {
  const CleanupAnalysisSession(this._storage);

  final AnalysisSessionStorage _storage;

  Future<void> call(String sessionId) => _storage.deleteSession(sessionId);
}
