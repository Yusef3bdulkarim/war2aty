import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/app_session.dart';

/// Establishes and maintains the app's anonymous identity.
///
/// Domain-level contract: implementations live in the data layer (a local stub
/// until the real Supabase Anonymous Auth lands at M4). Never throws — every
/// outcome is a [Result].
abstract interface class AuthRepository {
  /// Signs in anonymously, returning (and persisting) the resulting session.
  Future<Result<AppSession, AppFailure>> signInAnonymously();

  /// Restores the persisted session, or `Ok(null)` when there is none (or the
  /// stored value is unreadable). Missing state is not an error.
  ///
  /// A restored session **may be expired**: implementations report what they
  /// hold and do not judge it. Expiry is [EnsureActiveSession]'s policy, and it
  /// can only apply that policy if it is given the stale session to reason about
  /// (F19). Callers that need a *usable* token go through that use case rather
  /// than reading this directly.
  Future<Result<AppSession?, AppFailure>> restoreSession();

  /// Obtains a fresh session, replacing the persisted one.
  ///
  /// A failure here is classified: a network failure means the refresh never
  /// reached the server and the caller may still have a use for the stale
  /// session, while any other failure means it was refused.
  Future<Result<AppSession, AppFailure>> refreshSession();
}
