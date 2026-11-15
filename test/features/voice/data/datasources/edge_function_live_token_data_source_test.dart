import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/voice/data/datasources/edge_function_live_token_data_source.dart';

// ── fakes ────────────────────────────────────────────────────────────────────

final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

final class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.exception);

  final DioException exception;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw exception;
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(HttpClientAdapter adapter) => Dio(
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

const _validBody =
    '{"ws_url":"wss://example.test/ws?access_token=tok","model":"models/gemini-2.5-flash-native-audio-latest","expires_at":"2026-11-13T10:30:00.000Z"}';

// ── tests ────────────────────────────────────────────────────────────────────

void main() {
  group('EdgeFunctionLiveTokenDataSource', () {
    test('posts to the live-token endpoint', () async {
      final adapter = _StubAdapter((_) => _json(200, _validBody));
      final source = EdgeFunctionLiveTokenDataSource(_dio(adapter));

      await source.fetchEndpoint();

      expect(adapter.lastRequest?.method, 'POST');
      expect(adapter.lastRequest?.path, contains(kLiveTokenPath));
    });

    test('a successful response parses into a LiveSessionEndpoint', () async {
      final adapter = _StubAdapter((_) => _json(200, _validBody));
      final source = EdgeFunctionLiveTokenDataSource(_dio(adapter));

      final result = await source.fetchEndpoint();

      expect(result, isA<Ok<LiveSessionEndpoint, AppFailure>>());
      final endpoint = (result as Ok<LiveSessionEndpoint, AppFailure>).value;
      expect(
        endpoint.wsUrl.toString(),
        'wss://example.test/ws?access_token=tok',
      );
      expect(endpoint.model, 'models/gemini-2.5-flash-native-audio-latest');
      expect(endpoint.expiresAt, DateTime.utc(2026, 11, 13, 10, 30));
    });

    // ── T10 done condition: 401, 429 and offline → distinct AppFailures ────

    test('401 maps to UnauthorizedFailure', () async {
      final adapter = _StubAdapter(
        (_) => _json(401, '{"error":{"code":"UNAUTHORIZED","message":"x"}}'),
      );
      final source = EdgeFunctionLiveTokenDataSource(_dio(adapter));

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<UnauthorizedFailure>(),
      );
    });

    test('429 AI_RATE_LIMITED maps to AiProviderRateLimitFailure', () async {
      final adapter = _StubAdapter(
        (_) => _json(429, '{"error":{"code":"AI_RATE_LIMITED","message":"x"}}'),
      );
      final source = EdgeFunctionLiveTokenDataSource(_dio(adapter));

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<AiProviderRateLimitFailure>(),
      );
    });

    test('503 ANALYSIS_DISABLED maps to AnalysisDisabledFailure', () async {
      final adapter = _StubAdapter(
        (_) =>
            _json(503, '{"error":{"code":"ANALYSIS_DISABLED","message":"x"}}'),
      );
      final source = EdgeFunctionLiveTokenDataSource(_dio(adapter));

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<AnalysisDisabledFailure>(),
      );
    });

    test('offline (connection error) maps to NoInternetFailure', () async {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/live-token'),
        type: DioExceptionType.connectionError,
      );
      final source = EdgeFunctionLiveTokenDataSource(
        _dio(_ThrowingAdapter(exception)),
      );

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<NoInternetFailure>(),
      );
    });

    test(
      'offline (SocketException inside unknown) maps to NoInternetFailure',
      () async {
        final exception = DioException(
          requestOptions: RequestOptions(path: '/live-token'),
          type: DioExceptionType.unknown,
          error: const SocketException('no route to host'),
        );
        final source = EdgeFunctionLiveTokenDataSource(
          _dio(_ThrowingAdapter(exception)),
        );

        final result = await source.fetchEndpoint();

        expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
        expect(
          (result as Err<LiveSessionEndpoint, AppFailure>).failure,
          isA<NoInternetFailure>(),
        );
      },
    );

    test('connection timeout maps to NoInternetFailure', () async {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/live-token'),
        type: DioExceptionType.connectionTimeout,
      );
      final source = EdgeFunctionLiveTokenDataSource(
        _dio(_ThrowingAdapter(exception)),
      );

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<NoInternetFailure>(),
      );
    });

    test('receive timeout maps to RequestTimeoutFailure', () async {
      final exception = DioException(
        requestOptions: RequestOptions(path: '/live-token'),
        type: DioExceptionType.receiveTimeout,
      );
      final source = EdgeFunctionLiveTokenDataSource(
        _dio(_ThrowingAdapter(exception)),
      );

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<RequestTimeoutFailure>(),
      );
    });

    test('500 INTERNAL_ERROR maps to AnalysisServiceFailure', () async {
      final adapter = _StubAdapter(
        (_) => _json(500, '{"error":{"code":"INTERNAL_ERROR","message":"x"}}'),
      );
      final source = EdgeFunctionLiveTokenDataSource(_dio(adapter));

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<AnalysisServiceFailure>(),
      );
    });

    // ── malformed responses ─────────────────────────────────────────────────

    test('a non-JSON response maps to VoiceServiceFailure', () async {
      final adapter = _StubAdapter((_) => _json(200, '"just a string"'));
      final source = EdgeFunctionLiveTokenDataSource(_dio(adapter));

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<VoiceServiceFailure>(),
      );
    });

    test('a response missing ws_url maps to VoiceServiceFailure', () async {
      final adapter = _StubAdapter(
        (_) => _json(
          200,
          '{"model":"models/x","expires_at":"2026-11-13T10:30:00.000Z"}',
        ),
      );
      final source = EdgeFunctionLiveTokenDataSource(_dio(adapter));

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<VoiceServiceFailure>(),
      );
    });

    test('an unparseable expires_at maps to VoiceServiceFailure', () async {
      final adapter = _StubAdapter(
        (_) => _json(
          200,
          '{"ws_url":"wss://x","model":"models/x","expires_at":"not-a-date"}',
        ),
      );
      final source = EdgeFunctionLiveTokenDataSource(_dio(adapter));

      final result = await source.fetchEndpoint();

      expect(result, isA<Err<LiveSessionEndpoint, AppFailure>>());
      expect(
        (result as Err<LiveSessionEndpoint, AppFailure>).failure,
        isA<VoiceServiceFailure>(),
      );
    });

    // ── the three error types are distinct ───────────────────────────────────

    test(
      '401, 429 and offline produce three different failure types',
      () async {
        final adapter401 = _StubAdapter(
          (_) => _json(401, '{"error":{"code":"UNAUTHORIZED","message":"x"}}'),
        );
        final adapter429 = _StubAdapter(
          (_) =>
              _json(429, '{"error":{"code":"AI_RATE_LIMITED","message":"x"}}'),
        );
        final offlineException = DioException(
          requestOptions: RequestOptions(path: '/live-token'),
          type: DioExceptionType.connectionError,
        );

        final r401 =
            await EdgeFunctionLiveTokenDataSource(
                  _dio(adapter401),
                ).fetchEndpoint()
                as Err<LiveSessionEndpoint, AppFailure>;
        final r429 =
            await EdgeFunctionLiveTokenDataSource(
                  _dio(adapter429),
                ).fetchEndpoint()
                as Err<LiveSessionEndpoint, AppFailure>;
        final rOff =
            await EdgeFunctionLiveTokenDataSource(
                  _dio(_ThrowingAdapter(offlineException)),
                ).fetchEndpoint()
                as Err<LiveSessionEndpoint, AppFailure>;

        expect(r401.failure.runtimeType, isNot(r429.failure.runtimeType));
        expect(r401.failure.runtimeType, isNot(rOff.failure.runtimeType));
        expect(r429.failure.runtimeType, isNot(rOff.failure.runtimeType));
      },
    );
  });
}
