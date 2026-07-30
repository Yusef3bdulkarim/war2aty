import 'package:dio/dio.dart';

import '../../logging/app_logger.dart';
import '../../logging/log_event.dart';
import 'request_id_interceptor.dart';

/// Logs one structured line per API call — and nothing else.
///
/// Dio ships a `LogInterceptor`, and it is unusable here: it prints request and
/// response **bodies**, which on this path are the OCR text of someone's
/// electricity bill and the analysis of it, plus the `Authorization` header.
/// That is precisely what §51 forbids, so this replaces it rather than
/// configuring it.
///
/// What goes out is the §51 allowlist: the request id, the HTTP status, and how
/// long it took. No URL, no headers, no body, no query string — a path could
/// one day carry an identifier, and there is no version of "just this once"
/// that stays true.
final class ApiLogInterceptor extends Interceptor {
  ApiLogInterceptor(this._logger, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  static const String _startedAtExtra = 'started_at_ms';

  final AppLogger _logger;
  final DateTime Function() _now;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtExtra] = _now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // `err.message` is deliberately not logged: on a bad-response error Dio
    // builds it from the response body, which is the analysis.
    _log(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }

  void _log(RequestOptions options, int? statusCode) {
    final startedAt = options.extra[_startedAtExtra];

    _logger.event(
      LogEvent(
        requestId: options.headers[kRequestIdHeader] as String?,
        stage: LogStage.analyze,
        httpStatus: statusCode,
        durationMs: startedAt is int
            ? _now().millisecondsSinceEpoch - startedAt
            : null,
      ),
    );
  }
}
