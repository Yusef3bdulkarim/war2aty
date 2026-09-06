import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

import '../error/app_failure.dart';

/// Turns a transport-level [DioException] into an [AppFailure] (§31 rule 5).
///
/// This handles only the cases where there is **no usable response**. A call
/// that came back with a §31 error body is not a transport problem — the
/// repository maps `error.code` through `api_error_mapper.dart`, which is
/// what keeps the Arabic copy tied to the contract rather than to whatever the
/// network did.
///
/// The distinction the user actually feels is "you are offline" versus "this is
/// taking too long", because the two suggest different actions: check your
/// connection, or wait and retry. Everything else collapses to a generic
/// service failure — guessing beyond that would put words in the app's mouth.
///
/// PRIVACY: the exception's `message` is never read. On a bad response Dio
/// builds it from the response body, and that body is the user's document (§7).
AppFailure failureFromDioException(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      // We reached the server and it was too slow. "Try again" is good advice.
      return const RequestTimeoutFailure();

    case DioExceptionType.connectionTimeout:
      // We never reached the server at all, so this is connectivity, not a slow
      // analysis. Observed against an unreachable host on Windows, where the
      // connect attempt hangs to the timeout instead of being refused —
      // "try again" would be the wrong advice for someone with no signal.
      return const NoInternetFailure();

    case DioExceptionType.connectionError:
      return const NoInternetFailure();

    case DioExceptionType.cancel:
      // Nobody cancels an analysis today. If that changes, a cancelled request
      // is not a failure to report — but until then, treating it as one is
      // more honest than pretending it succeeded.
      return const AnalysisServiceFailure();

    case DioExceptionType.badCertificate:
      return const AnalysisServiceFailure();

    case DioExceptionType.badResponse:
      // Reached only when a caller let Dio throw on a non-2xx. The datasources
      // set `validateStatus` so §31 bodies come back as responses instead.
      return const AnalysisServiceFailure();

    case DioExceptionType.unknown:
      // Dio buries a dead socket here — no route to host, DNS failure, the
      // emulator pointed at 127.0.0.1 instead of 10.0.2.2. To the user that is
      // simply "no connection", and telling them the service is broken would
      // send them to support instead of to their wifi settings.
      return exception.error is SocketException
          ? const NoInternetFailure()
          : const AnalysisServiceFailure();
  }
}
