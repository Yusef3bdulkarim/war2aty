import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/app_session.dart';
import '../repositories/auth_repository.dart';

/// Guarantees the app has a usable session, whatever state it launched in.
///
/// Policy: restore what was saved → if nothing was saved, sign in → if what we
/// restored has expired, refresh it. Keeping this here (not in the repository)
/// means the rule is testable in isolation and independent of how sessions are
/// stored or fetched.
final class EnsureActiveSession {
  EnsureActiveSession(this._auth, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AuthRepository _auth;
  final DateTime Function() _now;

  Future<Result<AppSession, AppFailure>> call() async {
    final restored = await _auth.restoreSession();
    if (restored case Err(:final failure)) return Err(failure);

    final session = restored.valueOrNull;
    if (session == null) return _auth.signInAnonymously();
    if (session.isExpired(_now())) return _auth.refreshSession();

    return Ok(session);
  }
}
