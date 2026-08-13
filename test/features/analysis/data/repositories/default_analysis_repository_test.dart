import 'dart:async';
import 'dart:convert';
import 'dart:io' show FileSystemException;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/identity/installation_id_provider.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/analysis/data/datasources/analysis_remote_data_source.dart';
import 'package:war2aty/features/analysis/data/models/analysis_image_request_dto.dart';
import 'package:war2aty/features/analysis/data/models/analysis_request_dto.dart';
import 'package:war2aty/features/analysis/data/repositories/default_analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/ocr/domain/entities/amount_candidate.dart';
import 'package:war2aty/features/ocr/domain/entities/date_candidate.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/normalized_ocr_text.dart';
import 'package:war2aty/features/ocr/domain/entities/phone_candidate.dart';

import '../../../../support/fakes.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class _FakeDataSource implements AnalysisRemoteDataSource {
  _FakeDataSource({this.response, this.error});

  final AnalysisApiResponse? response;
  final Object? error;

  /// The request the repository actually built.
  AnalysisRequestDto? sent;

  /// The image request the repository actually built.
  AnalysisImageRequestDto? sentImage;

  @override
  Future<AnalysisApiResponse> analyze(AnalysisRequestDto request) async {
    sent = request;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<AnalysisApiResponse> analyzeImage(
    AnalysisImageRequestDto request,
  ) async {
    sentImage = request;
    if (error != null) throw error!;
    return response!;
  }
}

final class _FakeInstallationId implements InstallationIdProvider {
  _FakeInstallationId([this._result = const Ok('install-42')]);

  final Result<String, AppFailure> _result;

  @override
  Future<Result<String, AppFailure>> getOrCreate() async => _result;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _successBody({String status = 'success'}) => {
  'schema_version': '1.0',
  'session_id': 'session-1',
  'status': status,
  'document_type': {
    'type': 'invoice',
    'title': 'فاتورة كهرباء',
    'confidence': 'high',
  },
  'summary': {'short': 'قصير.', 'detailed': 'تفصيلي.'},
};

Object? _errorBody(String code, {String? details}) => jsonDecode(
  '{"error":{"code":"$code","message":"debug only"'
  '${details == null ? '' : ',"details":$details'}}}',
);

const _extraction = ExtractionResult(
  text: NormalizedOcrText(
    originalText: 'فاتورة كهرباء ٨٥٠ جنيه',
    cleanedText: 'فاتورة كهرباء 850 جنيه',
  ),
  dates: [DateCandidate(rawText: '2024/04/15')],
  amounts: [AmountCandidate(rawText: '850 جنيه', value: 850, currency: 'EGP')],
  phones: [
    PhoneCandidate(rawText: '0100-123-4567', normalizedNumber: '01001234567'),
  ],
);

const _request = AnalysisRequest(
  sessionId: 'session-1',
  extraction: _extraction,
  detectedLanguages: ['ar', 'en'],
);

const _imageRequest = AnalysisImageRequest(
  sessionId: 'session-1',
  photo: CapturedPhoto('/tmp/warped.jpg'),
);

({
  DefaultAnalysisRepository repository,
  _FakeDataSource dataSource,
  FakeLogSink sink,
})
_build({
  AnalysisApiResponse? response,
  Object? error,
  Result<String, AppFailure> identity = const Ok('install-42'),
  ImageBytesReader? readImageBytes,
}) {
  final dataSource = _FakeDataSource(response: response, error: error);
  final sink = FakeLogSink();

  return (
    repository: DefaultAnalysisRepository(
      dataSource: dataSource,
      installationId: _FakeInstallationId(identity),
      logger: StructuredAppLogger(sink),
      appVersion: '1.2.3',
      readImageBytes:
          readImageBytes ?? (path) async => Uint8List.fromList([1, 2, 3]),
    ),
    dataSource: dataSource,
    sink: sink,
  );
}

AnalysisApiResponse _ok(Object? body) =>
    AnalysisApiResponse(statusCode: 200, body: body);

void main() {
  group('request building', () {
    test('fills the envelope from identity and config', () async {
      final harness = _build(response: _ok(_successBody()));

      await harness.repository.analyze(_request);

      final sent = harness.dataSource.sent!;
      expect(sent.schemaVersion, kAnalysisRequestSchemaVersion);
      expect(sent.sessionId, 'session-1');
      expect(sent.installationId, 'install-42');
      expect(sent.appVersion, '1.2.3');
      expect(sent.detectedLanguages, ['ar', 'en']);
    });

    test('sends the cleaned OCR text, not the raw output', () async {
      final harness = _build(response: _ok(_successBody()));

      await harness.repository.analyze(_request);

      expect(harness.dataSource.sent!.ocrText, 'فاتورة كهرباء 850 جنيه');
    });

    test('carries every candidate type across', () async {
      final harness = _build(response: _ok(_successBody()));

      await harness.repository.analyze(_request);

      final candidates = harness.dataSource.sent!.candidates;
      expect(candidates.dates, hasLength(1));
      expect(candidates.amounts, hasLength(1));
      expect(candidates.phones, hasLength(1));
      expect(candidates.times, isEmpty);
      expect(candidates.references, isEmpty);
      expect(candidates.amounts.single.value, 850);
      expect(candidates.phones.single.normalizedNumber, '01001234567');
    });

    test('never puts an image path in the payload', () async {
      final harness = _build(response: _ok(_successBody()));

      await harness.repository.analyze(_request);

      final json = jsonEncode(harness.dataSource.sent!.toJson());
      expect(json, isNot(contains('.jpg')));
      expect(json, isNot(contains('analysis_sessions')));
      expect(
        harness.dataSource.sent!.toJson().keys,
        unorderedEquals([
          'schema_version',
          'session_id',
          'installation_id',
          'app_version',
          'input_type',
          'ocr_text',
          'detected_languages',
          'candidates',
        ]),
      );
    });
  });

  group('success', () {
    test('returns the mapped analysis', () async {
      final harness = _build(response: _ok(_successBody()));

      final result = await harness.repository.analyze(_request);

      final analysis = result.valueOrNull;
      expect(analysis, isNotNull);
      expect(analysis!.kind, DocumentKind.invoice);
      expect(analysis.status, AnalysisStatus.success);
      expect(harness.sink.writes, isEmpty, reason: 'nothing to log on success');
    });

    test('passes a partial result through as a success', () async {
      final harness = _build(response: _ok(_successBody(status: 'partial')));

      final result = await harness.repository.analyze(_request);

      expect(result.valueOrNull?.isPartial, isTrue);
    });

    test('turns an unsupported document into a failure', () async {
      final harness = _build(
        response: _ok(_successBody(status: 'unsupported')),
      );

      final result = await harness.repository.analyze(_request);

      expect(result.failureOrNull, isA<UnsupportedDocumentFailure>());
    });

    test('fails on a body it cannot read', () async {
      final harness = _build(response: _ok('<html>oops</html>'));

      final result = await harness.repository.analyze(_request);

      expect(result.failureOrNull, isA<InvalidAnalysisResponseFailure>());
    });
  });

  group('error responses', () {
    test('maps the error code, not the HTTP status', () async {
      final harness = _build(
        response: AnalysisApiResponse(
          statusCode: 429,
          body: _errorBody(
            'DAILY_LIMIT_REACHED',
            details: '{"reset_at":"2024-03-16T00:00:00+02:00"}',
          ),
        ),
      );

      final result = await harness.repository.analyze(_request);

      final failure = result.failureOrNull;
      expect(failure, isA<DailyLimitReachedFailure>());
      expect(
        (failure! as DailyLimitReachedFailure).resetAtCairo,
        DateTime.parse('2024-03-16T00:00:00+02:00'),
      );
    });

    test('maps a maintenance response', () async {
      final harness = _build(
        response: AnalysisApiResponse(
          statusCode: 503,
          body: _errorBody('ANALYSIS_DISABLED'),
        ),
      );

      final result = await harness.repository.analyze(_request);

      expect(result.failureOrNull, isA<AnalysisDisabledFailure>());
    });

    test('treats an unparseable error body as a service failure', () async {
      final harness = _build(
        response: const AnalysisApiResponse(statusCode: 500, body: null),
      );

      final result = await harness.repository.analyze(_request);

      expect(result.failureOrNull, isA<AnalysisServiceFailure>());
    });
  });

  group('transport and identity', () {
    test('maps a timeout', () async {
      final harness = _build(error: TimeoutException('slow'));

      final result = await harness.repository.analyze(_request);

      expect(result.failureOrNull, isA<RequestTimeoutFailure>());
    });

    test('maps any other transport error to a service failure', () async {
      final harness = _build(error: StateError('socket died'));

      final result = await harness.repository.analyze(_request);

      expect(result.failureOrNull, isA<AnalysisServiceFailure>());
    });

    test(
      'propagates an identity failure without calling the service',
      () async {
        final harness = _build(
          response: _ok(_successBody()),
          identity: const Err(FileStorageFailure()),
        );

        final result = await harness.repository.analyze(_request);

        expect(result.failureOrNull, isA<FileStorageFailure>());
        expect(harness.dataSource.sent, isNull);
      },
    );
  });

  group('logging', () {
    test('logs a failure by code, scoped to the session', () async {
      final harness = _build(
        response: AnalysisApiResponse(
          statusCode: 401,
          body: _errorBody('UNAUTHORIZED'),
        ),
      );

      await harness.repository.analyze(_request);

      expect(harness.sink.writes, hasLength(1));
      final logged = harness.sink.writes.single;
      expect(logged['errorCode'], 'UNAUTHORIZED');
      expect(logged['stage'], LogStage.analyze.name);
      expect(logged['analysisSessionId'], 'session-1');
    });

    test('never logs document content', () async {
      final harness = _build(response: _ok('<html>oops</html>'));

      await harness.repository.analyze(_request);

      final logged = jsonEncode(harness.sink.writes);
      expect(logged, isNot(contains('كهرباء')));
      expect(logged, isNot(contains('850')));
      expect(logged, isNot(contains('01001234567')));
      expect(
        harness.sink.writes.single.keys,
        everyElement(isIn(kAllowedLogFields)),
      );
    });
  });

  group('analyzeImage — request building', () {
    test('fills the envelope and the image shape', () async {
      final harness = _build(
        response: _ok(_successBody()),
        readImageBytes: (path) async => Uint8List.fromList([1, 2, 3]),
      );

      await harness.repository.analyzeImage(_imageRequest);

      final sent = harness.dataSource.sentImage!;
      expect(sent.schemaVersion, kAnalysisRequestSchemaVersion);
      expect(sent.sessionId, 'session-1');
      expect(sent.installationId, 'install-42');
      expect(sent.appVersion, '1.2.3');
      expect(sent.imageBase64, base64Encode([1, 2, 3]));
      expect(sent.mimeType, 'image/jpeg');
    });

    test('reads bytes from the photo path it was given', () async {
      String? readPath;
      final harness = _build(
        response: _ok(_successBody()),
        readImageBytes: (path) async {
          readPath = path;
          return Uint8List.fromList([1]);
        },
      );

      await harness.repository.analyzeImage(_imageRequest);

      expect(readPath, '/tmp/warped.jpg');
    });

    test('picks image/png for a .png photo', () async {
      final harness = _build(response: _ok(_successBody()));

      await harness.repository.analyzeImage(
        const AnalysisImageRequest(
          sessionId: 'session-1',
          photo: CapturedPhoto('/tmp/warped.png'),
        ),
      );

      expect(harness.dataSource.sentImage!.mimeType, 'image/png');
    });

    test('never puts the ocr-text shape in the payload', () async {
      final harness = _build(response: _ok(_successBody()));

      await harness.repository.analyzeImage(_imageRequest);

      expect(
        harness.dataSource.sentImage!.toJson().keys,
        unorderedEquals([
          'schema_version',
          'session_id',
          'installation_id',
          'app_version',
          'input_type',
          'image',
        ]),
      );
      expect(harness.dataSource.sentImage!.toJson()['input_type'], 'image');
    });
  });

  group('analyzeImage — outcomes', () {
    test('returns the mapped analysis on success', () async {
      final harness = _build(response: _ok(_successBody()));

      final result = await harness.repository.analyzeImage(_imageRequest);

      expect(result.valueOrNull?.kind, DocumentKind.invoice);
    });

    test('maps an error response through the shared §31 mapper', () async {
      final harness = _build(
        response: AnalysisApiResponse(
          statusCode: 503,
          body: _errorBody('ANALYSIS_DISABLED'),
        ),
      );

      final result = await harness.repository.analyzeImage(_imageRequest);

      expect(result.failureOrNull, isA<AnalysisDisabledFailure>());
    });

    test('maps a transport error the same way as the text route', () async {
      final harness = _build(error: StateError('socket died'));

      final result = await harness.repository.analyzeImage(_imageRequest);

      expect(result.failureOrNull, isA<AnalysisServiceFailure>());
    });

    test(
      'turns an unreadable file into a local failure without calling the service',
      () async {
        final harness = _build(
          response: _ok(_successBody()),
          readImageBytes: (path) => throw const FileSystemException('nope'),
        );

        final result = await harness.repository.analyzeImage(_imageRequest);

        expect(result.failureOrNull, isA<ImageProcessingFailure>());
        expect(harness.dataSource.sentImage, isNull);
      },
    );

    test(
      'propagates an identity failure without calling the service',
      () async {
        final harness = _build(
          response: _ok(_successBody()),
          identity: const Err(FileStorageFailure()),
        );

        final result = await harness.repository.analyzeImage(_imageRequest);

        expect(result.failureOrNull, isA<FileStorageFailure>());
        expect(harness.dataSource.sentImage, isNull);
      },
    );

    test('logs a failure scoped to the session', () async {
      final harness = _build(
        response: AnalysisApiResponse(
          statusCode: 401,
          body: _errorBody('UNAUTHORIZED'),
        ),
      );

      await harness.repository.analyzeImage(_imageRequest);

      expect(harness.sink.writes, hasLength(1));
      expect(harness.sink.writes.single['errorCode'], 'UNAUTHORIZED');
      expect(harness.sink.writes.single['analysisSessionId'], 'session-1');
    });
  });
}
