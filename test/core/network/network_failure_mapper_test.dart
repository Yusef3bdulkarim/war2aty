import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/network/network_failure_mapper.dart';

final _options = RequestOptions(path: '/analyze-document');

DioException _exception(DioExceptionType type, {Object? error}) =>
    DioException(requestOptions: _options, type: type, error: error);

void main() {
  group('failureFromDioException', () {
    test('a slow server reads as a timeout', () {
      for (final type in [
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(
          failureFromDioException(_exception(type)),
          isA<RequestTimeoutFailure>(),
          reason: '$type must not read as a generic service failure',
        );
      }
    });

    test('failing to connect at all reads as no internet, not a timeout', () {
      // The two suggest different actions — check your wifi, or wait and retry
      // — so they must not collapse (§31 rule 5). A *connection* timeout means
      // the server was never reached, which is connectivity: observed against
      // an unreachable host on Windows, where connecting hangs to the timeout
      // rather than being refused.
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(
          failureFromDioException(_exception(type)),
          isA<NoInternetFailure>(),
          reason: '$type means we never reached the server',
        );
      }
    });

    test('a dead socket buried in `unknown` still reads as no internet', () {
      // This is the emulator pointed at 127.0.0.1 instead of 10.0.2.2, and DNS
      // failures. Reporting "the service is broken" would send the user to
      // support instead of to their network settings.
      expect(
        failureFromDioException(
          _exception(
            DioExceptionType.unknown,
            error: const SocketException('Connection refused'),
          ),
        ),
        isA<NoInternetFailure>(),
      );
    });

    test('an unknown error with no socket cause stays generic', () {
      expect(
        failureFromDioException(
          _exception(DioExceptionType.unknown, error: StateError('boom')),
        ),
        isA<AnalysisServiceFailure>(),
      );
    });

    test('bad certificate and bad response are service failures', () {
      expect(
        failureFromDioException(_exception(DioExceptionType.badCertificate)),
        isA<AnalysisServiceFailure>(),
      );
      expect(
        failureFromDioException(_exception(DioExceptionType.badResponse)),
        isA<AnalysisServiceFailure>(),
      );
    });

    test('the exception message is never read', () {
      // On a bad response Dio builds `message` from the response body, and that
      // body is the user's document (§7). A failure carries no text at all, so
      // this is structural — but assert it, because a future leaf that took a
      // message would pass silently otherwise.
      final failure = failureFromDioException(
        DioException(
          requestOptions: _options,
          type: DioExceptionType.badResponse,
          message: 'رقم الحساب 12345678',
        ),
      );

      expect(failure.toString(), isNot(contains('12345678')));
    });
  });
}
