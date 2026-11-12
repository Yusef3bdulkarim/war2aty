import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/result/result.dart';

/// Path of the live-token endpoint, relative to the functions base URL.
const String kLiveTokenPath = '/live-token';

/// The resolved connection details for a single Live voice session (F37-T10).
///
/// What this carries depends on the transport path T01 chose. For Path A
/// (ephemeral token), [wsUrl] includes the token as a query parameter and the
/// phone connects to Google directly. For Path B1 (relay), [wsUrl] would be
/// the relay's address and auth would be the existing Supabase JWT. The
/// [GeminiLiveVoiceSession] does not know or care which — it connects to
/// [wsUrl] and speaks.
final class LiveSessionEndpoint {
  const LiveSessionEndpoint({
    required this.wsUrl,
    required this.model,
    required this.expiresAt,
  });

  final Uri wsUrl;
  final String model;
  final DateTime expiresAt;
}

/// Fetches a short-lived voice endpoint from the backend.
///
/// T17's `ReadPaperAloud` calls this before creating a [GeminiLiveVoiceSession].
/// Under Path A the endpoint is a Google WebSocket URL with an embedded
/// ephemeral token; under Path B1 it would be our own relay — the interface
/// is the same either way, which is the whole point of injecting it.
abstract interface class LiveTokenDataSource {
  Future<Result<LiveSessionEndpoint, AppFailure>> fetchEndpoint();
}

/// The real transport: `POST /functions/v1/live-token` (F37-T10).
///
/// Thin on purpose: the Edge Function does the work (auth, gates, mint), and
/// this class turns the response into a [LiveSessionEndpoint] or maps the
/// error to the right [AppFailure].
///
/// PRIVACY: the response carries the ephemeral token only inside `ws_url`.
/// It is never logged here, and it expires within minutes.
final class EdgeFunctionLiveTokenDataSource implements LiveTokenDataSource {
  const EdgeFunctionLiveTokenDataSource(this._dio);

  final Dio _dio;

  @override
  Future<Result<LiveSessionEndpoint, AppFailure>> fetchEndpoint() async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        kLiveTokenPath,
        options: Options(validateStatus: (_) => true),
      );
    } on DioException catch (e) {
      return Err(_failureFromDioException(e));
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      return Err(failureFromErrorBody(response.data, statusCode: statusCode));
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      return const Err(VoiceServiceFailure());
    }

    final wsUrl = data['ws_url'];
    final model = data['model'];
    final expiresAt = data['expires_at'];

    if (wsUrl is! String || model is! String || expiresAt is! String) {
      return const Err(VoiceServiceFailure());
    }

    final parsedUri = Uri.tryParse(wsUrl);
    final parsedExpiry = DateTime.tryParse(expiresAt);
    if (parsedUri == null || parsedExpiry == null) {
      return const Err(VoiceServiceFailure());
    }

    return Ok(
      LiveSessionEndpoint(
        wsUrl: parsedUri,
        model: model,
        expiresAt: parsedExpiry,
      ),
    );
  }

  /// Maps transport-level failures to [AppFailure].
  ///
  /// Mirrors `failureFromDioException` but returns [VoiceServiceFailure]
  /// instead of [AnalysisServiceFailure] for the cases that are not
  /// connectivity — a voice endpoint outage must not be reported as the
  /// paper having failed to be understood.
  static AppFailure _failureFromDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return const NoInternetFailure();
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const RequestTimeoutFailure();
      case DioExceptionType.unknown:
        return exception.error is SocketException
            ? const NoInternetFailure()
            : const VoiceServiceFailure();
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
        return const VoiceServiceFailure();
    }
  }
}
