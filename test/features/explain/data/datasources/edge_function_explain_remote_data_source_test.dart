import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/explain/data/datasources/edge_function_explain_remote_data_source.dart';
import 'package:war2aty/features/explain/data/models/explain_request_dto.dart';

const _request = ExplainRequestDto(
  explainSchemaVersion: '1.0',
  sessionId: '3f2504e0-4f89-41d3-9a0c-0305e82c3301',
  installationId: '9c858901-8a57-4791-81fe-4c455b099bc9',
  appVersion: '1.0.0',
  image: ExplainImageDto(data: 'YWJj', mimeType: 'image/jpeg'),
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
  group('EdgeFunctionExplainRemoteDataSource', () {
    test('posts the body to the explain-document endpoint', () async {
      final adapter = _StubAdapter((_) => _json(200, '{"status":"success"}'));
      final source = EdgeFunctionExplainRemoteDataSource(_dio(adapter));

      await source.explain(_request, timeout: const Duration(seconds: 40));

      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, kExplainDocumentPath);
    });

    test('sends the §33 body with no input_type', () async {
      final adapter = _StubAdapter((_) => _json(200, '{}'));
      final source = EdgeFunctionExplainRemoteDataSource(_dio(adapter));

      await source.explain(_request, timeout: const Duration(seconds: 40));

      final body = adapter.lastBody! as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'explain_schema_version',
        'session_id',
        'installation_id',
        'app_version',
        'image',
      });
    });

    test('applies the given timeout to the request', () async {
      final adapter = _StubAdapter((_) => _json(200, '{}'));
      final source = EdgeFunctionExplainRemoteDataSource(_dio(adapter));

      await source.explain(_request, timeout: const Duration(seconds: 35));

      expect(adapter.lastRequest!.sendTimeout, const Duration(seconds: 35));
      expect(adapter.lastRequest!.receiveTimeout, const Duration(seconds: 35));
    });

    test('a §31 error body survives as a response, not an exception', () async {
      final adapter = _StubAdapter(
        (_) => _json(429, '{"error":{"code":"AI_RATE_LIMITED","message":"x"}}'),
      );
      final source = EdgeFunctionExplainRemoteDataSource(_dio(adapter));

      final response = await source.explain(
        _request,
        timeout: const Duration(seconds: 40),
      );

      expect(response.isSuccess, isFalse);
      expect(response.statusCode, 429);
    });

    test(
      'an HTML error page comes back untouched for the repository to judge',
      () async {
        final adapter = _StubAdapter(
          (_) => ResponseBody.fromString('<html>502</html>', 502),
        );
        final source = EdgeFunctionExplainRemoteDataSource(_dio(adapter));

        final response = await source.explain(
          _request,
          timeout: const Duration(seconds: 40),
        );

        expect(response.isSuccess, isFalse);
        expect(response.body, isNot(isA<Map<String, dynamic>>()));
      },
    );

    test('a transport failure is left to propagate', () async {
      final adapter = _StubAdapter((options) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      final source = EdgeFunctionExplainRemoteDataSource(_dio(adapter));

      await expectLater(
        source.explain(_request, timeout: const Duration(seconds: 40)),
        throwsA(isA<DioException>()),
      );
    });
  });
}
