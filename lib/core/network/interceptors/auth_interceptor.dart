import 'dart:async';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'request_id_interceptor.dart';

/// Returns the current access token, or `null` when there is no session.
typedef AccessTokenProvider = Future<String?> Function();

/// Forces a new session and returns its token, or `null` if that failed.
typedef SessionRefresher = Future<String?> Function();

/// Attaches the anonymous identity to every call, and recovers from a stale one.
///
/// Two headers go out: the `apikey` the Supabase gateway requires, and the
/// `Authorization: Bearer <jwt>` the Edge Function actually authenticates
/// (F06-T03). The JWT is short-lived — one hour by default — so a token that
/// was fine when a photo was taken can be expired by the time the OCR finishes
/// and the analysis is sent.
///
/// That is what the 401 path is for: refresh once, replay once. Without it the
/// user would see «انتهت الجلسة» on a perfectly good document, with no login
/// screen to fix it through — this app has no visible sign-in (§6).
///
/// ## Why the 401 is caught in `onResponse`, not `onError`
///
/// `createApiClient` sets `validateStatus: (_) => true` so §31 error bodies
/// survive to the repository instead of being thrown away. That also means Dio
/// treats a 401 as a perfectly ordinary response and **never** calls
/// `onError` for it. Handling only the error path would have produced an
/// interceptor that passes its own unit tests and silently never fires in
/// production. [onError] is kept as well, so the interceptor still works if it
/// is ever mounted on a client with stricter status validation.
///
/// PRIVACY: the token is never logged, never put in an error, and never
/// reaches [toString] anywhere on this path (§51).
final class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AccessTokenProvider accessToken,
    required SessionRefresher refreshSession,
    required String anonKey,
    required Dio dio,
    String Function()? generateId,
  }) : _accessToken = accessToken,
       _refreshSession = refreshSession,
       _anonKey = anonKey,
       _dio = dio,
       _generateId = generateId ?? (() => const Uuid().v4());

  /// Marks a request that has already been replayed, so a persistently
  /// rejected token cannot drive an unbounded refresh/retry loop.
  static const String _retriedExtra = 'auth_retried';

  /// Carries the just-refreshed token into the replay.
  ///
  /// `Dio.fetch` runs the **full** interceptor chain, [onRequest] included — so
  /// a replay would otherwise re-read [_accessToken] and re-attach the very
  /// token the server just rejected, guaranteeing a second 401. Passing the
  /// fresh one explicitly makes the replay correct regardless of whether the
  /// session store has caught up with the refresh yet.
  static const String _freshTokenExtra = 'auth_fresh_token';

  final AccessTokenProvider _accessToken;
  final SessionRefresher _refreshSession;
  final String _anonKey;
  final Dio _dio;
  final String Function() _generateId;

  /// In-flight refresh, shared by every caller that arrives during it.
  ///
  /// Three tabs of a screen hitting a stale token at once must produce one
  /// refresh, not three. Beyond the wasted round-trips, GoTrue rotates refresh
  /// tokens with a 10-second reuse window — concurrent refreshes race to spend
  /// the same one, and the losers can invalidate the session outright.
  Future<String?>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['apikey'] = _anonKey;

    // A replay's fresh token wins over whatever the session store reports.
    final override = options.extra[_freshTokenExtra];
    final token = override is String && override.isNotEmpty
        ? override
        : await _accessToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(response.statusCode, response.requestOptions)) {
      handler.next(response);
      return;
    }

    final replayed = await _replay(response.requestOptions);
    if (replayed == null) {
      handler.next(response);
      return;
    }

    handler.resolve(replayed);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err.response?.statusCode, err.requestOptions)) {
      handler.next(err);
      return;
    }

    final replayed = await _replay(err.requestOptions);
    if (replayed == null) {
      // Still no identity — let the 401 through so it maps to
      // UnauthorizedFailure rather than looking like a transport error.
      handler.next(err);
      return;
    }

    handler.resolve(replayed);
  }

  bool _shouldRetry(int? statusCode, RequestOptions options) =>
      statusCode == 401 && options.extra[_retriedExtra] != true;

  /// Refreshes and replays once. `null` means "could not", and the caller
  /// passes the original 401 along untouched.
  Future<Response<dynamic>?> _replay(RequestOptions options) async {
    final token = await _refreshOnce();
    if (token == null || token.isEmpty) return null;

    options
      ..extra[_retriedExtra] = true
      ..extra[_freshTokenExtra] = token
      ..headers['Authorization'] = 'Bearer $token'
      // A fresh correlation id, or the replay would carry the one the server
      // already saw and be refused as a duplicate reservation (F06-T07).
      // `RequestIdInterceptor` only fills in a missing id, so setting it here
      // survives the chain re-running.
      ..headers[kRequestIdHeader] = _generateId();

    try {
      return await _dio.fetch<dynamic>(options);
    } on DioException {
      // The replay failed too. Reporting the original 401 is more useful than
      // the second error, which is usually a consequence of the first.
      return null;
    }
  }

  Future<String?> _refreshOnce() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final started = _refreshSession();
    _refreshInFlight = started;

    return started.whenComplete(() {
      // Cleared only if this is still the current attempt, so a slow refresh
      // finishing after a newer one cannot wipe the newer future.
      if (identical(_refreshInFlight, started)) _refreshInFlight = null;
    });
  }
}
