import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/analysis/data/mappers/analysis_error_mapper.dart';

Object? _body(String code, {String? details}) => jsonDecode(
  '{"error":{"code":"$code","message":"debug only"'
  '${details == null ? '' : ',"details":$details'}}}',
);

void main() {
  group('error code → failure', () {
    test('maps every documented code', () {
      final expected = <String, Type>{
        'INVALID_REQUEST': InvalidRequestFailure,
        'UNSUPPORTED_SCHEMA': InvalidRequestFailure,
        'UNSUPPORTED_APP_VERSION': UnsupportedAppVersionFailure,
        'UNAUTHORIZED': UnauthorizedFailure,
        'TIMEOUT': RequestTimeoutFailure,
        'DAILY_LIMIT_REACHED': DailyLimitReachedFailure,
        'AI_RATE_LIMITED': AiProviderRateLimitFailure,
        'ANALYSIS_FAILED': AnalysisServiceFailure,
        'INTERNAL_ERROR': AnalysisServiceFailure,
        'ANALYSIS_DISABLED': AnalysisDisabledFailure,
      };

      for (final entry in expected.entries) {
        expect(
          failureFromErrorBody(_body(entry.key)).runtimeType,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('treats an unrecognised code as a service failure', () {
      expect(
        failureFromErrorBody(_body('TEAPOT')),
        isA<AnalysisServiceFailure>(),
      );
    });
  });

  group('DAILY_LIMIT_REACHED', () {
    test('carries the server-provided reset time', () {
      final failure =
          failureFromErrorBody(
                _body(
                  'DAILY_LIMIT_REACHED',
                  details: '{"reset_at":"2024-03-16T00:00:00+02:00"}',
                ),
              )
              as DailyLimitReachedFailure;

      expect(failure.resetAtCairo, DateTime.parse('2024-03-16T00:00:00+02:00'));
    });

    test('falls back to the next Cairo midnight when reset_at is missing', () {
      // 2024-03-15 20:00 UTC is 22:00 in Cairo — the quota resets two hours
      // later, at 2024-03-15 22:00 UTC.
      final now = DateTime.utc(2024, 3, 15, 20);

      final failure =
          failureFromErrorBody(_body('DAILY_LIMIT_REACHED'), now: now)
              as DailyLimitReachedFailure;

      expect(failure.resetAtCairo, DateTime.utc(2024, 3, 15, 22));
    });

    test('falls back when reset_at is unparseable', () {
      final now = DateTime.utc(2024, 3, 15, 20);

      final failure =
          failureFromErrorBody(
                _body('DAILY_LIMIT_REACHED', details: '{"reset_at":"soon"}'),
                now: now,
              )
              as DailyLimitReachedFailure;

      expect(failure.resetAtCairo, DateTime.utc(2024, 3, 15, 22));
    });
  });

  group('unusable bodies', () {
    test('treats a non-object body as a service failure', () {
      for (final body in <Object?>[
        null,
        '<html>502 Bad Gateway</html>',
        <Object>[],
        42,
      ]) {
        expect(
          failureFromErrorBody(body),
          isA<AnalysisServiceFailure>(),
          reason: '$body',
        );
      }
    });

    test('treats a malformed envelope as a service failure', () {
      expect(
        failureFromErrorBody(jsonDecode('{"message":"boom"}')),
        isA<AnalysisServiceFailure>(),
      );
      expect(
        failureFromErrorBody(jsonDecode('{"error":{"message":"no code"}}')),
        isA<AnalysisServiceFailure>(),
      );
      expect(
        failureFromErrorBody(jsonDecode('{"error":"boom"}')),
        isA<AnalysisServiceFailure>(),
      );
    });
  });
}
