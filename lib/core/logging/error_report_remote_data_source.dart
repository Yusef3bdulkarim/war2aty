import 'package:dio/dio.dart';

import 'error_report_dto.dart';

/// Path of the error-report endpoint, relative to the functions base URL.
const String kReportErrorPath = '/report-error';

/// Transport for the error-report endpoint (F27-T12).
///
/// Deliberately returns nothing. Nobody is waiting for the answer and there is
/// no retry: a report that fails to arrive is a lost data point, while a
/// retry queue in the one component that runs *during* a crash is a second
/// thing to go wrong at the worst moment.
abstract interface class ErrorReportRemoteDataSource {
  /// Sends one report. May throw; the caller is expected to swallow it.
  Future<void> send(ErrorReportDto report);
}

/// The real transport: `POST /functions/v1/report-error`.
///
/// Its [Dio] must be one built **without** the API log interceptor. Logging a
/// call that is itself a log line is an infinite loop, and the sink's own
/// re-entrancy guard should not be the only thing standing between this app
/// and one.
final class EdgeFunctionErrorReportDataSource
    implements ErrorReportRemoteDataSource {
  const EdgeFunctionErrorReportDataSource(this._dio);

  final Dio _dio;

  @override
  Future<void> send(ErrorReportDto report) async {
    await _dio.post<dynamic>(kReportErrorPath, data: report.toJson());
  }
}
