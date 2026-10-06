import '../analysis_session_storage.dart';

/// Deletes one analysis session's working files once that analysis is over
/// (F27-T15).
///
/// Lives in `core/` rather than beside `CreateAnalysisSession` in the capture
/// feature's domain, even though the two are a pair: the caller is the
/// *analysis* feature's result cubit, and reaching into another feature's
/// domain for it is exactly the cross-feature import CLAUDE.md §1 rules out.
/// The session's lifetime spans both features, so neither owns it.
///
/// Returns nothing and cannot fail — see
/// [AnalysisSessionStorage.deleteSession]. Cubits call it on their way out,
/// where there is nothing a failure could usefully be reported to.
final class DiscardAnalysisSession {
  const DiscardAnalysisSession(this._storage);

  final AnalysisSessionStorage _storage;

  Future<void> call(String sessionId) => _storage.deleteSession(sessionId);
}
