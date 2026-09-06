import 'package:dio/dio.dart';

import '../env/app_environment.dart';
import '../logging/app_logger.dart';
import 'interceptors/api_log_interceptor.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/request_id_interceptor.dart';

/// Builds the Dio instance every Edge Function call goes through.
///
/// One client, one place where the cross-cutting behaviour lives. A datasource
/// below this gets a `Dio` that is already authenticated, already correlated,
/// and already logged — so it can be about its own endpoint and nothing else.
///
/// ## Why `validateStatus` accepts everything
///
/// The backend answers failures with a §31 body carrying a machine-readable
/// `code`, and that code is what the client maps to Arabic copy. Letting Dio
/// throw on a 4xx would discard the body and leave the repository guessing from
/// a status alone — a 429 could be a daily limit or an AI rate limit, and those
/// are different screens. Non-2xx responses therefore come back as responses.
///
/// ## Timeouts
///
/// [receiveTimeout] must exceed the server's own AI timeout (25s, F06-T08), or
/// the client gives up on an analysis the server is still finishing — and one
/// that has a slot reserved against the user's daily quota. The server is
/// designed to time out first, release the slot and answer 408; this value is
/// what keeps that true.
Dio createApiClient({
  required AppEnvironment environment,
  required AppLogger logger,
  required AccessTokenProvider accessToken,
  required SessionRefresher refreshSession,
  Duration connectTimeout = const Duration(seconds: 10),
  Duration receiveTimeout = const Duration(seconds: 40),
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: environment.functionsBaseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: connectTimeout,
      contentType: Headers.jsonContentType,
      validateStatus: (_) => true,
    ),
  );

  dio.interceptors.addAll([
    // Order matters. The id is stamped first so the auth retry and the log line
    // both see the same value; logging wraps the auth attempt so a refreshed
    // replay is timed as its own call.
    RequestIdInterceptor(),
    ApiLogInterceptor(logger),
    AuthInterceptor(
      accessToken: accessToken,
      refreshSession: refreshSession,
      anonKey: environment.supabaseAnonKey,
      dio: dio,
    ),
  ]);

  return dio;
}
