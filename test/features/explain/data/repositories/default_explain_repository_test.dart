import 'dart:async';
import 'dart:convert';
import 'dart:io' show FileSystemException;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/config/runtime_config.dart';
import 'package:war2aty/core/config/runtime_config_store.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/identity/installation_id_provider.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/explain/data/datasources/explain_remote_data_source.dart';
import 'package:war2aty/features/explain/data/models/explain_request_dto.dart';
import 'package:war2aty/features/explain/data/repositories/default_explain_repository.dart';

import '../../../../support/fakes.dart';

final class _FakeDataSource implements ExplainRemoteDataSource {
  _FakeDataSource({this.response, this.error});

  final ExplainApiResponse? response;
  final Object? error;

  ExplainRequestDto? sent;
  Duration? sentTimeout;

  @override
  Future<ExplainApiResponse> explain(
    ExplainRequestDto request, {
    required Duration timeout,
  }) async {
    sent = request;
    sentTimeout = timeout;
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

Map<String, dynamic> _successBody({String status = 'success'}) => {
  'explain_schema_version': '1.0',
  'session_id': 'echoed-session',
  'status': status,
  'paper': {'title': 'جواب من مدرسة النور'},
  'explain': ['دي ورقة من مدرسة النور لولي أمر الطالب أحمد محمود.'],
  'todo': {'required': true, 'text': 'روح الاجتماع بنفسك.'},
  'date': null,
  'caution': null,
  'contact': null,
  'place': null,
};

Object? _errorBody(String code, {String? details}) => jsonDecode(
  '{"error":{"code":"$code","message":"debug only"'
  '${details == null ? '' : ',"details":$details'}}}',
);

const _photo = CapturedPhoto('/tmp/paper.jpg');

ExplainApiResponse _ok(Object? body) =>
    ExplainApiResponse(statusCode: 200, body: body);

({
  DefaultExplainRepository repository,
  _FakeDataSource dataSource,
  FakeLogSink sink,
})
_build({
  ExplainApiResponse? response,
  Object? error,
  Result<String, AppFailure> identity = const Ok('install-42'),
  ImageBytesReader? readImageBytes,
  RuntimeConfig? config,
  IdGenerator? generateSessionId,
}) {
  final dataSource = _FakeDataSource(response: response, error: error);
  final sink = FakeLogSink();
  final store = RuntimeConfigStore();
  if (config != null) store.update(config);

  return (
    repository: DefaultExplainRepository(
      dataSource: dataSource,
      installationId: _FakeInstallationId(identity),
      logger: StructuredAppLogger(sink),
      appVersion: '1.2.3',
      config: store,
      readImageBytes:
          readImageBytes ?? (path) async => Uint8List.fromList([1, 2, 3]),
      generateSessionId: generateSessionId ?? () => 'session-1',
    ),
    dataSource: dataSource,
    sink: sink,
  );
}

void main() {
  group('request building', () {
    test('fills the envelope from identity, config and the photo', () async {
      final harness = _build(response: _ok(_successBody()));

      await harness.repository.explain(_photo);

      final sent = harness.dataSource.sent!;
      expect(sent.sessionId, 'session-1');
      expect(sent.installationId, 'install-42');
      expect(sent.appVersion, '1.2.3');
      expect(
        sent.explainSchemaVersion,
        RuntimeConfig.defaults.explainSchemaVersion,
      );
    });

    test(
      'reads the schema version from runtime config, not hard-coded',
      () async {
        final harness = _build(
          response: _ok(_successBody()),
          config: const RuntimeConfig(
            analysisEnabled: true,
            dailyAnalysisLimit: 3,
            maxOcrCharacters: 12000,
            analysisTimeout: Duration(seconds: 30),
            schemaVersion: '2.0',
            minimumAppVersion: '1.0.0',
            explainSchemaVersion: '9.9',
          ),
        );

        await harness.repository.explain(_photo);

        expect(harness.dataSource.sent!.explainSchemaVersion, '9.9');
      },
    );

    test(
      'sends the timeout from runtime config, longer than the 30s server budget',
      () async {
        final harness = _build(
          response: _ok(_successBody()),
          config: const RuntimeConfig(
            analysisEnabled: true,
            dailyAnalysisLimit: 3,
            maxOcrCharacters: 12000,
            analysisTimeout: Duration(seconds: 30),
            schemaVersion: '2.0',
            minimumAppVersion: '1.0.0',
            explainTimeout: Duration(seconds: 45),
          ),
        );

        await harness.repository.explain(_photo);

        expect(harness.dataSource.sentTimeout, const Duration(seconds: 45));
        expect(
          harness.dataSource.sentTimeout! > const Duration(seconds: 30),
          isTrue,
        );
      },
    );

    test('mints a fresh session id and sends exactly that', () async {
      var calls = 0;
      final harness = _build(
        response: _ok(_successBody()),
        generateSessionId: () => 'generated-${++calls}',
      );

      await harness.repository.explain(_photo);

      expect(harness.dataSource.sent!.sessionId, 'generated-1');
    });

    test('never puts the file path or an input_type in the payload', () async {
      final harness = _build(response: _ok(_successBody()));

      await harness.repository.explain(_photo);

      final json = jsonEncode(harness.dataSource.sent!.toJson());
      expect(json, isNot(contains('/tmp/paper.jpg')));
      expect(
        harness.dataSource.sent!.toJson().keys,
        unorderedEquals([
          'explain_schema_version',
          'session_id',
          'installation_id',
          'app_version',
          'image',
        ]),
      );
    });

    test('picks image/png for a .png photo', () async {
      final harness = _build(response: _ok(_successBody()));

      await harness.repository.explain(const CapturedPhoto('/tmp/paper.png'));

      expect(harness.dataSource.sent!.image.mimeType, 'image/png');
    });
  });

  group('success', () {
    test(
      'returns the parsed explanation with its envelope bookkeeping',
      () async {
        final harness = _build(response: _ok(_successBody()));

        final result = await harness.repository.explain(_photo);

        final outcome = result.valueOrNull;
        expect(outcome, isNotNull);
        expect(outcome!.explanation.status, PaperStatus.success);
        expect(outcome.explanation.title, 'جواب من مدرسة النور');
        expect(outcome.sessionId, 'session-1');
        expect(outcome.explainSchemaVersion, '1.0');
        expect(
          harness.sink.writes,
          isEmpty,
          reason: 'nothing to log on success',
        );
      },
    );

    test('passes a partial result through as Ok, not a failure', () async {
      final harness = _build(response: _ok(_successBody(status: 'partial')));

      final result = await harness.repository.explain(_photo);

      expect(result.valueOrNull?.explanation.status, PaperStatus.partial);
    });

    test(
      'passes status: unsupported through as Ok, not UnsupportedDocumentFailure (D10)',
      () async {
        final harness = _build(
          response: _ok(_successBody(status: 'unsupported')),
        );

        final result = await harness.repository.explain(_photo);

        expect(result.isOk, isTrue);
        expect(result.valueOrNull?.explanation.status, PaperStatus.unsupported);
      },
    );

    test('fails on a body it cannot read', () async {
      final harness = _build(response: _ok('<html>oops</html>'));

      final result = await harness.repository.explain(_photo);

      expect(result.failureOrNull, isA<InvalidAnalysisResponseFailure>());
    });
  });

  group('§33.7 errors — all twelve rows', () {
    final cases = <({String code, int status, Type failure})>[
      (
        code: 'ANALYSIS_DISABLED',
        status: 503,
        failure: AnalysisDisabledFailure,
      ),
      (code: 'INVALID_REQUEST', status: 400, failure: InvalidRequestFailure),
      (code: 'UNSUPPORTED_SCHEMA', status: 400, failure: InvalidRequestFailure),
      (
        code: 'UNSUPPORTED_APP_VERSION',
        status: 400,
        failure: UnsupportedAppVersionFailure,
      ),
      (code: 'UNAUTHORIZED', status: 401, failure: UnauthorizedFailure),
      (
        code: 'DAILY_LIMIT_REACHED',
        status: 429,
        failure: DailyLimitReachedFailure,
      ),
      (
        code: 'GLOBAL_CAPACITY_REACHED',
        status: 429,
        failure: GlobalCapacityReachedFailure,
      ),
      (
        code: 'AI_RATE_LIMITED',
        status: 429,
        failure: AiProviderRateLimitFailure,
      ),
      (code: 'TIMEOUT', status: 408, failure: RequestTimeoutFailure),
      (code: 'ANALYSIS_FAILED', status: 500, failure: AnalysisServiceFailure),
      (code: 'INTERNAL_ERROR', status: 500, failure: AnalysisServiceFailure),
    ];

    for (final c in cases) {
      test('${c.code} (${c.status}) maps to ${c.failure}', () async {
        final harness = _build(
          response: ExplainApiResponse(
            statusCode: c.status,
            body: _errorBody(c.code),
          ),
        );

        final result = await harness.repository.explain(_photo);

        expect(result.failureOrNull.runtimeType, c.failure);
      });
    }

    test(
      'ANALYSIS_FAILED covers both the reading leg and the explaining leg (same code)',
      () async {
        final harness = _build(
          response: ExplainApiResponse(
            statusCode: 500,
            body: _errorBody('ANALYSIS_FAILED'),
          ),
        );

        final result = await harness.repository.explain(_photo);

        expect(result.failureOrNull, isA<AnalysisServiceFailure>());
      },
    );
  });

  group('malformed or unexpected bodies', () {
    test(
      'an HTML gateway body is AnalysisServiceFailure, not a crash (§31 rule 4)',
      () async {
        final harness = _build(
          response: const ExplainApiResponse(
            statusCode: 502,
            body: '<html>502 Bad Gateway</html>',
          ),
        );

        final result = await harness.repository.explain(_photo);

        expect(result.failureOrNull, isA<AnalysisServiceFailure>());
      },
    );

    test('an unparseable error body falls back by status code', () async {
      final harness = _build(
        response: const ExplainApiResponse(statusCode: 401, body: null),
      );

      final result = await harness.repository.explain(_photo);

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    });
  });

  group('transport — offline and too-slow are distinguishable', () {
    test('a connection error is NoInternetFailure', () async {
      final harness = _build(
        error: DioException(
          requestOptions: RequestOptions(path: '/explain-document'),
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await harness.repository.explain(_photo);

      expect(result.failureOrNull, isA<NoInternetFailure>());
    });

    test('a receive timeout is RequestTimeoutFailure', () async {
      final harness = _build(
        error: DioException(
          requestOptions: RequestOptions(path: '/explain-document'),
          type: DioExceptionType.receiveTimeout,
        ),
      );

      final result = await harness.repository.explain(_photo);

      expect(result.failureOrNull, isA<RequestTimeoutFailure>());
    });

    test('a bare TimeoutException is also RequestTimeoutFailure', () async {
      final harness = _build(error: TimeoutException('slow'));

      final result = await harness.repository.explain(_photo);

      expect(result.failureOrNull, isA<RequestTimeoutFailure>());
    });

    test('any other transport error is a generic service failure', () async {
      final harness = _build(error: StateError('socket died'));

      final result = await harness.repository.explain(_photo);

      expect(result.failureOrNull, isA<AnalysisServiceFailure>());
    });

    test(
      'propagates an identity failure without calling the service',
      () async {
        final harness = _build(
          response: _ok(_successBody()),
          identity: const Err(FileStorageFailure()),
        );

        final result = await harness.repository.explain(_photo);

        expect(result.failureOrNull, isA<FileStorageFailure>());
        expect(harness.dataSource.sent, isNull);
      },
    );

    test(
      'turns an unreadable file into a local failure without calling the service',
      () async {
        final harness = _build(
          response: _ok(_successBody()),
          readImageBytes: (path) => throw const FileSystemException('nope'),
        );

        final result = await harness.repository.explain(_photo);

        expect(result.failureOrNull, isA<ImageProcessingFailure>());
        expect(harness.dataSource.sent, isNull);
      },
    );
  });

  group('logging', () {
    test('logs a failure by code, scoped to the explain stage', () async {
      final harness = _build(
        response: ExplainApiResponse(
          statusCode: 401,
          body: _errorBody('UNAUTHORIZED'),
        ),
        generateSessionId: () => 'session-xyz',
      );

      await harness.repository.explain(_photo);

      expect(harness.sink.writes, hasLength(1));
      final logged = harness.sink.writes.single;
      expect(logged['errorCode'], 'UNAUTHORIZED');
      expect(logged['stage'], LogStage.explain.name);
      expect(logged['analysisSessionId'], 'session-xyz');
    });

    test('never logs document content, the path or a card', () async {
      final harness = _build(response: _ok('<html>oops</html>'));

      await harness.repository.explain(_photo);

      final logged = jsonEncode(harness.sink.writes);
      expect(logged, isNot(contains('مدرسة')));
      expect(logged, isNot(contains('paper.jpg')));
      expect(
        harness.sink.writes.single.keys,
        everyElement(isIn(kAllowedLogFields)),
      );
    });
  });
}
