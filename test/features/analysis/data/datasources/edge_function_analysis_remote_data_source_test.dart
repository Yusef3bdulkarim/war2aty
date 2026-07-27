import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/analysis/data/datasources/edge_function_analysis_remote_data_source.dart';
import 'package:war2aty/features/analysis/data/models/analysis_request_dto.dart';
import 'package:war2aty/features/analysis/data/models/candidates_dto.dart';
import 'package:war2aty/features/analysis/data/models/date_candidate_dto.dart';

const _request = AnalysisRequestDto(
  schemaVersion: '1.0',
  sessionId: '3f2504e0-4f89-41d3-9a0c-0305e82c3301',
  installationId: '9c858901-8a57-4791-81fe-4c455b099bc9',
  appVersion: '1.0.0',
  ocrText: 'فاتورة كهرباء — إجمالي المبلغ 850.50 جنيه',
  detectedLanguages: ['ar'],
  candidates: CandidatesDto(
    dates: [
      DateCandidateDto(
        rawText: '2026-08-15',
        normalizedDate: '2026-08-15',
        isAmbiguous: false,
      ),
    ],
  ),
);

final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  RequestOptions? lastRequest;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    lastBody = options.data;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_StubAdapter adapter) => Dio(
  BaseOptions(
    baseUrl: 'http://10.0.2.2:54321/functions/v1',
    validateStatus: (_) => true,
  ),
)..httpClientAdapter = adapter;

ResponseBody _json(int status, String body) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  group('EdgeFunctionAnalysisRemoteDataSource', () {
    test('posts the request to the analyze-document endpoint', () async {
      final adapter = _StubAdapter((_) => _json(200, '{"status":"success"}'));
      final source = EdgeFunctionAnalysisRemoteDataSource(_dio(adapter));

      await source.analyze(_request);

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, kAnalyzeDocumentPath);
    });

    test('sends the §29 body — and nothing that could be an image', () async {
      final adapter = _StubAdapter((_) => _json(200, '{}'));
      final source = EdgeFunctionAnalysisRemoteDataSource(_dio(adapter));

      await source.analyze(_request);

      final body = adapter.lastBody! as Map<String, dynamic>;

      expect(body['schema_version'], '1.0');
      expect(body['ocr_text'], _request.ocrText);
      expect(
        (body['candidates'] as Map<String, dynamic>)['dates'],
        hasLength(1),
      );

      // The paper never leaves the phone (§7). The backend rejects unknown
      // properties, so an extra key here would fail every analysis — but the
      // real guarantee is that the DTO has no field one could go in.
      expect(body.keys.toSet(), {
        'schema_version',
        'session_id',
        'installation_id',
        'app_version',
        'ocr_text',
        'detected_languages',
        'candidates',
      });
    });

    test('a §31 error body survives as a response, not an exception', () async {
      // Letting Dio throw would discard the body, and the repository would have
      // to guess from a status alone — a 429 is either a daily limit or an AI
      // rate limit, and those are different screens.
      final adapter = _StubAdapter(
        (_) => _json(
          429,
          '{"error":{"code":"DAILY_LIMIT_REACHED","message":"x"}}',
        ),
      );
      final source = EdgeFunctionAnalysisRemoteDataSource(_dio(adapter));

      final response = await source.analyze(_request);

      expect(response.isSuccess, isFalse);
      expect(response.statusCode, 429);
      expect(
        ((response.body! as Map<String, dynamic>)['error']
            as Map<String, dynamic>)['code'],
        'DAILY_LIMIT_REACHED',
      );
    });

    test(
      'an HTML error page comes back untouched for the repository to judge',
      () async {
        // §31 rule 4: a gateway can answer with something that is not JSON at all.
        final adapter = _StubAdapter(
          (_) => ResponseBody.fromString('<html>502</html>', 502),
        );
        final source = EdgeFunctionAnalysisRemoteDataSource(_dio(adapter));

        final response = await source.analyze(_request);

        expect(response.isSuccess, isFalse);
        expect(response.body, isNot(isA<Map<String, dynamic>>()));
      },
    );

    test('a transport failure is left to propagate', () async {
      // The repository maps DioException through `failureFromDioException`,
      // which owns the offline-vs-timeout distinction. Swallowing it here would
      // flatten both into one indistinguishable error.
      final adapter = _StubAdapter((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      final source = EdgeFunctionAnalysisRemoteDataSource(_dio(adapter));

      await expectLater(source.analyze(_request), throwsA(isA<DioException>()));
    });
  });
}
