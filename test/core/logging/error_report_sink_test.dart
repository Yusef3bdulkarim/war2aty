import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/error_report_dto.dart';
import 'package:war2aty/core/logging/error_report_remote_data_source.dart';
import 'package:war2aty/core/logging/error_report_sink.dart';
import 'package:war2aty/core/logging/log_event.dart';

/// Records what was sent, and can be made to fail or to hang.
final class _FakeRemote implements ErrorReportRemoteDataSource {
  _FakeRemote({this.failure, this.throwsSynchronously = false});

  final List<ErrorReportDto> sent = [];

  /// Completed by the test, so "a send is still in flight" is a real state
  /// rather than a timing hope.
  final List<Completer<void>> pending = [];

  /// When set, the returned future fails with it.
  final Object? failure;

  /// When true, `send` throws instead of returning a failed future.
  final bool throwsSynchronously;

  @override
  Future<void> send(ErrorReportDto report) {
    if (throwsSynchronously) throw StateError('transport is broken');

    sent.add(report);
    if (failure != null) return Future<void>.error(failure!);

    final completer = Completer<void>();
    pending.add(completer);
    return completer.future;
  }

  void completeAll() {
    for (final completer in pending) {
      if (!completer.isCompleted) completer.complete();
    }
    pending.clear();
  }
}

void main() {
  group('ErrorReportDto.fromLogFields', () {
    test('ignores any record without an error code', () {
      // The volume guard: success lines, timings and OCR counts are local
      // telemetry and must not reach the network.
      for (final fields in <Map<String, Object>>[
        {},
        {'durationMs': 42},
        {'resultStatus': 'success', 'ocrCharacterCount': 900},
        {'errorCode': ''},
      ]) {
        expect(ErrorReportDto.fromLogFields(fields), isNull, reason: '$fields');
      }
    });

    test('maps the envelope to the snake_case wire shape', () {
      final report = ErrorReportDto.fromLogFields(
        const LogEvent(
          analysisSessionId: '11111111-1111-4111-8111-111111111111',
          requestId: '22222222-2222-4222-8222-222222222222',
          stage: LogStage.ocr,
          durationMs: 1200,
          httpStatus: 502,
          resultStatus: LogResultStatus.failure,
          failure: OcrFailure(),
          appVersion: '1.0.0',
          schemaVersion: '2.0',
        ).toLogMap(),
      );

      expect(report, isNotNull);
      expect(report!.toJson(), {
        'error_code': 'OCR',
        'stage': 'ocr',
        'result_status': 'failure',
        'request_id': '22222222-2222-4222-8222-222222222222',
        'analysis_session_id': '11111111-1111-4111-8111-111111111111',
        'http_status': 502,
        'duration_ms': 1200,
        'app_version': '1.0.0',
        'schema_version': '2.0',
      });
    });

    test('drops a field the in-app allowlist may gain later', () {
      // The wire contract is narrower than the local one on purpose: a field
      // added to §51 for a local-only reason must not start crossing the
      // network because it happened to be in the same map.
      final report = ErrorReportDto.fromLogFields(const {
        'errorCode': 'OCR',
        'ocrCharacterCount': 900,
        'ocrConfidenceBand': 'low',
      });

      expect(report!.toJson(), const {'error_code': 'OCR'});
    });

    test('omits null fields instead of sending them as null', () {
      final report = ErrorReportDto.fromLogFields(const {'errorCode': 'TTS'});

      expect(report!.toJson(), const {'error_code': 'TTS'});
    });

    test('carries an uncaught error the same way as a failure', () {
      final report = ErrorReportDto.fromLogFields(
        const LogEvent(crash: LogCrashKind.flutterFramework).toLogMap(),
      );

      expect(report!.errorCode, 'UNCAUGHT_FLUTTER_ERROR');
    });
  });

  group('ErrorReportSink', () {
    test('sends a failure record', () async {
      final remote = _FakeRemote();
      final sink = ErrorReportSink(remote);

      StructuredAppLogger(
        sink,
      ).failure(const OcrFailure(), stage: LogStage.ocr);

      expect(remote.sent.single.errorCode, 'OCR');
      expect(remote.sent.single.stage, 'ocr');
    });

    test('sends nothing for a record with no error code', () {
      final remote = _FakeRemote();
      final sink = ErrorReportSink(remote);

      StructuredAppLogger(sink).event(
        const LogEvent(stage: LogStage.ocr, durationMs: 10, httpStatus: 200),
      );

      expect(remote.sent, isEmpty);
      expect(sink.sentCount, 0);
    });

    test('does not block the caller on the request', () {
      // `write` is synchronous by contract and runs on someone else's hot
      // path. The fake never completes its future, so if `write` awaited it
      // this test would hang rather than fail.
      final remote = _FakeRemote();

      ErrorReportSink(remote).write(const {'errorCode': 'OCR'});

      expect(remote.pending, hasLength(1));
    });

    test('swallows a transport failure', () async {
      final remote = _FakeRemote(failure: StateError('network down'));
      final sink = ErrorReportSink(remote);

      expect(() => sink.write(const {'errorCode': 'OCR'}), returnsNormally);
      // An unhandled async error here would fail the test through the zone.
      await Future<void>.delayed(Duration.zero);
    });

    test('swallows a transport that throws synchronously', () {
      final sink = ErrorReportSink(_FakeRemote(throwsSynchronously: true));

      expect(() => sink.write(const {'errorCode': 'OCR'}), returnsNormally);
    });

    test('drops records while a send is in flight', () async {
      // The recursion guard. Reporting a failure can itself fail, and that
      // failure would be logged — which would report it.
      final remote = _FakeRemote();
      final sink = ErrorReportSink(remote);

      sink.write(const {'errorCode': 'OCR'});
      sink.write(const {'errorCode': 'NO_INTERNET'});
      sink.write(const {'errorCode': 'LOCAL_DATABASE'});

      expect(remote.sent.map((r) => r.errorCode), ['OCR']);

      remote.completeAll();
      await Future<void>.delayed(Duration.zero);

      sink.write(const {'errorCode': 'TTS'});
      expect(remote.sent.map((r) => r.errorCode), ['OCR', 'TTS']);
    });

    test('a synchronously-failing transport does not wedge the guard', () {
      // If the flag were left set, the sink would go silent for the rest of
      // the session after one odd transport error.
      final remote = _FakeRemote(throwsSynchronously: true);
      final sink = ErrorReportSink(remote);

      sink.write(const {'errorCode': 'OCR'});
      sink.write(const {'errorCode': 'TTS'});

      expect(sink.sentCount, 2, reason: 'both attempts were made');
    });

    test('stops at the per-session ceiling', () async {
      final remote = _FakeRemote();
      final sink = ErrorReportSink(remote, maxReportsPerSession: 3);

      for (var i = 0; i < 10; i++) {
        sink.write(const {'errorCode': 'OCR'});
        remote.completeAll();
        await Future<void>.delayed(Duration.zero);
      }

      expect(remote.sent, hasLength(3));
      expect(sink.sentCount, 3);
    });
  });
}
