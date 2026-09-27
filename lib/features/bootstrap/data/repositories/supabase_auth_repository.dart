import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/app_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../mappers/auth_failure_mapper.dart';

/// Real Supabase Anonymous Auth (F01-T03/T04, wired at M4 by F06-T14).
///
/// There is no login screen and never will be (§6): the session is a technical
/// identity that lets the backend police its quota, and it carries nothing
/// about the person holding the phone.
///
/// ## Why the SDK owns the session, and this class stores nothing
///
/// GoTrue rotates refresh tokens, and the local stack sets a 10-second reuse
/// interval. Persisting our own copy alongside the SDK's would create two
/// writers for one rotating credential: a restore from our copy could present a
/// token the server has already rotated past, and the account would be locked
/// out — with no sign-in screen to recover through. So [restoreSession] reads
/// whatever the SDK has, and nothing here writes to secure storage.
///
/// PRIVACY: the access token is never logged and never leaves this layer except
/// inside [AppSession], whose `toString` deliberately omits it (§51).
final class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._auth);

  final supabase.GoTrueClient _auth;

  @override
  Future<Result<AppSession, AppFailure>> signInAnonymously() async {
    try {
      final response = await _auth.signInAnonymously();
      return _sessionFrom(response.session);
    } on supabase.AuthException catch (exception) {
      // The message can name internal auth configuration; it is dropped rather
      // than surfaced, and the user sees Arabic copy derived from the failure.
      //
      // Classifying rather than assuming "unauthorized": GoTrue reports a dead
      // socket as an `AuthException` too, and an offline first launch is by far
      // the likeliest way this is reached (F19).
      return Err(failureFromAuthException(exception));
    } on Object {
      // Not an auth exception at all — a last resort, reached only if the SDK
      // lets something else escape.
      return const Err(NoInternetFailure());
    }
  }

  @override
  Future<Result<AppSession?, AppFailure>> restoreSession() async {
    try {
      final session = _auth.currentSession;
      if (session == null) return const Ok(null);

      // An expired session is reported as what it is, not as "no session".
      // Deciding what to do about expiry is [EnsureActiveSession]'s policy, and
      // it needs to see the stale session to apply it: offline, keeping a token
      // the Edge Function will reject is what lets the app launch at all, and
      // the `AuthInterceptor` refreshes it on the first 401 (F19).
      return _sessionFrom(session).map<AppSession?>((value) => value);
    } on Object {
      // Unreadable persisted state reads as "no session", exactly as the stub
      // behaved — the caller simply signs in again.
      return const Ok(null);
    }
  }

  @override
  Future<Result<AppSession, AppFailure>> refreshSession() async {
    try {
      // No session to refresh is not a failure — it is a first launch, or a
      // sign-in that never completed. Minting one is what the caller wanted.
      if (_auth.currentSession == null) return signInAnonymously();

      final response = await _auth.refreshSession();
      return _sessionFrom(response.session);
    } on supabase.AuthException catch (exception) {
      final failure = failureFromAuthException(exception);

      // We never reached the server, or it is down. Minting a new identity means
      // another request over the same dead connection, so it would fail exactly
      // the same way one round-trip later (F19). Report it instead, and let the
      // caller decide — offline, `EnsureActiveSession` keeps the stale session.
      if (failure is NoInternetFailure || failure is AnalysisServiceFailure) {
        return Err(failure);
      }

      // The server answered and refused: a refresh token that has been rotated
      // past, revoked, or reused is unrecoverable. A fresh anonymous identity is
      // strictly better than stranding the user: they lose only the server-side
      // quota count, and the installation id — which is what actually identifies
      // the install — is untouched.
      return signInAnonymously();
    } on Object {
      return const Err(NoInternetFailure());
    }
  }

  Result<AppSession, AppFailure> _sessionFrom(supabase.Session? session) {
    if (session == null) return const Err(UnauthorizedFailure());

    return Ok(
      AppSession(
        userId: session.user.id,
        accessToken: session.accessToken,
        expiresAt: _expiryOf(session),
      ),
    );
  }

  /// GoTrue reports expiry as a Unix timestamp in seconds.
  ///
  /// A session without one is treated as already expired rather than as
  /// long-lived: the cost of refreshing unnecessarily is one request, and the
  /// cost of the opposite is an analysis that 401s after the user has already
  /// photographed their paper.
  DateTime _expiryOf(supabase.Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return DateTime.now().toUtc();

    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true);
  }
}
