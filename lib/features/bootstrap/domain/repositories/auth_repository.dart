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
  Future<Result<AppSession?, AppFailure>> restoreSession();

  /// Obtains a fresh session, replacing the persisted one.
  Future<Result<AppSession, AppFailure>> refreshSession();
}
