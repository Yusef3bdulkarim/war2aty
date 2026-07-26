import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/error_code.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/logging/log_sink.dart';

/// Captures written field maps so tests can inspect exactly what was emitted.
final class _CapturingSink implements LogSink {
  final List<Map<String, Object>> writes = [];

  @override
  void write(Map<String, Object> fields) => writes.add(fields);

  Map<String, Object> get last => writes.last;
}

void main() {
  late _CapturingSink sink;
  late AppLogger logger;

  setUp(() {
    sink = _CapturingSink();
    logger = StructuredAppLogger(sink);
  });

  group('allowlist enforcement', () {
    test('a fully-populated event emits only allowlisted keys', () {
      logger.event(
        const LogEvent(
          analysisSessionId: 'sess-123',
          stage: LogStage.ocr,
          durationMs: 42,
          ocrCharacterCount: 900,
          ocrConfidenceBand: OcrConfidenceBand.high,
          resultStatus: LogResultStatus.success,
          failure: OcrFailure(),
          appVersion: '1.0.0',
          schemaVersion: 'v1',
        ),
      );

      expect(sink.last.keys.toSet(), kAllowedLogFields);
      expect(sink.last.keys.every(kAllowedLogFields.contains), isTrue);
    });

    test('null fields are omitted', () {
      logger.event(const LogEvent(stage: LogStage.analyze));
      expect(sink.last, {'stage': 'analyze'});
    });

    test('empty event emits an empty map', () {
      logger.event(const LogEvent());
      expect(sink.last, isEmpty);
    });
  });

  group('value serialization', () {
    test('enums serialize by name, ints pass through', () {
      logger.event(
        const LogEvent(
          stage: LogStage.save,
          ocrConfidenceBand: OcrConfidenceBand.low,
          resultStatus: LogResultStatus.partial,
          durationMs: 10,
          ocrCharacterCount: 5,
        ),
      );
      expect(sink.last, {
        'stage': 'save',
        'ocrConfidenceBand': 'low',
        'resultStatus': 'partial',
        'durationMs': 10,
        'ocrCharacterCount': 5,
      });
    });
  });

  group('failure() convenience', () {
    test('derives error code and marks status as failure', () {
      logger.failure(
        const NoInternetFailure(),
        stage: LogStage.analyze,
        sessionId: 'sess-9',
      );
      expect(sink.last, {
        'analysisSessionId': 'sess-9',
        'stage': 'analyze',
        'resultStatus': 'failure',
        'errorCode': 'NO_INTERNET',
      });
    });

    test('never leaks failure payload — only the code is logged', () {
      // A data-carrying failure must still log only its stable code.
      logger.failure(PartialAnalysisFailure(['amount', 'invoiceNumber']));
      expect(sink.last['errorCode'], 'PARTIAL_ANALYSIS');
      expect(sink.last.values.join(), isNot(contains('amount')));
      expect(sink.last.values.join(), isNot(contains('invoiceNumber')));
    });
  });

  group('errorCodeOf', () {
    final all = <AppFailure>[
      const CameraPermissionFailure(),
      const GalleryAccessFailure(),
      const ImageQualityFailure(),
      const ImageProcessingFailure(),
      const OcrInitializationFailure(),
      const OcrFailure(),
      const NoTextDetectedFailure(),
      const LocalDatabaseFailure(),
      const FileEncryptionFailure(),
      const FileStorageFailure(),
      const NotificationPermissionFailure(),
      const NotificationSchedulingFailure(),
      const TtsFailure(),
      const NoInternetFailure(),
      const RequestTimeoutFailure(),
      const UnauthorizedFailure(),
      DailyLimitReachedFailure(DateTime(2026, 7, 21)),
      const AnalysisDisabledFailure(),
      const UnsupportedAppVersionFailure(),
      const InvalidRequestFailure(),
      const AnalysisServiceFailure(),
      const InvalidAnalysisResponseFailure(),
      const AiProviderRateLimitFailure(),
      const UnsupportedDocumentFailure(),
      PartialAnalysisFailure(['x']),
      const AmbiguousDateFailure(),
      const MissingReminderTimeFailure(),
    ];

    test('maps all 27 failures to distinct non-empty codes', () {
      final codes = all.map(errorCodeOf).toList();
      expect(codes, hasLength(27));
      expect(codes.toSet(), hasLength(27));
      expect(codes.every((c) => c.isNotEmpty), isTrue);
    });
  });

  group('sinks', () {
    test('NoopLogSink discards writes', () {
      const noop = NoopLogSink();
      // Just proves it accepts and drops without error.
      expect(() => noop.write({'stage': 'ocr'}), returnsNormally);
    });
  });
}
