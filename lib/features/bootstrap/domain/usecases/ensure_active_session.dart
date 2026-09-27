import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/app_session.dart';
import '../repositories/auth_repository.dart';

/// Guarantees the app has a usable session, whatever state it launched in.
///
/// Policy: restore what was saved → if nothing was saved, sign in → if what we
/// restored has expired, refresh it → if that refresh cannot reach the network,
/// keep the stale session rather than failing. Keeping this here (not in the
/// repository) means the rule is testable in isolation and independent of how
/// sessions are stored or fetched.
///
/// ## Why an expired session is better than no session (F19)
///
/// A stale JWT grants nothing — the Edge Function validates it and refuses it,
/// and nothing in this app makes a local decision from a session. So offline,
/// the choice is between launching with a token that will be refreshed on the
/// first 401 (`AuthInterceptor`, which exists for exactly that) and not
/// launching at all. Discarding it used to mean an install that had been online
/// an hour earlier could not open its own saved papers.
///
/// Only a *network* failure is tolerated this way. A refresh the server actively
/// refused is a real problem and still propagates.
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
    if (!session.isExpired(_now())) return Ok(session);

    final refreshed = await _auth.refreshSession();

    // Offline. Launch with what we have; the interceptor refreshes it on the
    // first call that needs it, once there is a network to do it over.
    if (refreshed case Err(failure: NoInternetFailure())) return Ok(session);

    return refreshed;
  }
}
