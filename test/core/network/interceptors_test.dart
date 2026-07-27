import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/network/interceptors/api_log_interceptor.dart';
import 'package:war2aty/core/network/interceptors/auth_interceptor.dart';
import 'package:war2aty/core/network/interceptors/request_id_interceptor.dart';

/// Answers requests from a script instead of a network, so every test is
/// deterministic and nothing touches a socket.
final class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;

  /// Header **snapshots**, not the options themselves.
  ///
  /// The retry path mutates and re-sends the same `RequestOptions` instance, so
  /// keeping references would give every entry the final state and quietly make
  /// "the replay differs from the original" unassertable.
  final List<Map<String, dynamic>> received = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    received.add(Map<String, dynamic>.of(options.headers));
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

final class _RecordingLogger implements AppLogger {
  final List<Map<String, Object>> lines = [];

  @override
  void event(LogEvent e) => lines.add(e.toLogMap());

  @override
  void failure(_, {LogStage? stage, String? sessionId}) {}
}

ResponseBody _json(int status, String body) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// Mirrors `createApiClient`, including `validateStatus`.
///
/// That last part is load-bearing, not incidental: the production client
/// accepts every status so §31 error bodies reach the repository, which means
/// Dio never raises `onError` for a 401. A test client with stricter validation
/// would exercise a code path that does not exist in the app.
Dio _dio(_StubAdapter adapter) => Dio(
  BaseOptions(
    baseUrl: 'http://127.0.0.1:54321/functions/v1',
    validateStatus: (_) => true,
  ),
)..httpClientAdapter = adapter;

void main() {
  group('RequestIdInterceptor', () {
    test('stamps a fresh id on every request', () async {
      final adapter = _StubAdapter((_) => _json(200, '{}'));
      final dio = _dio(adapter)..interceptors.add(RequestIdInterceptor());

      await dio.get<dynamic>('/get-usage');
      await dio.get<dynamic>('/get-usage');

      final first = adapter.received[0][kRequestIdHeader];
      final second = adapter.received[1][kRequestIdHeader];

      expect(first, isNotNull);
      // A reused id would be refused as a duplicate reservation, turning a
      // recoverable retry into a permanent failure for that document.
      expect(first, isNot(second));
    });

    test('an explicitly set id is left alone', () async {
      final adapter = _StubAdapter((_) => _json(200, '{}'));
      final dio = _dio(adapter)..interceptors.add(RequestIdInterceptor());

      await dio.get<dynamic>(
        '/get-usage',
        options: Options(headers: {kRequestIdHeader: 'caller-chose-this'}),
      );

      expect(adapter.received.single[kRequestIdHeader], 'caller-chose-this');
    });
  });

  group('AuthInterceptor', () {
    test('attaches the bearer token and the gateway apikey', () async {
      final adapter = _StubAdapter((_) => _json(200, '{}'));
      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          accessToken: () async => 'jwt-token',
          refreshSession: () async => null,
          anonKey: 'anon-key',
          dio: dio,
        ),
      );

      await dio.get<dynamic>('/get-usage');

      final headers = adapter.received.single;
      expect(headers['Authorization'], 'Bearer jwt-token');
      expect(headers['apikey'], 'anon-key');
    });

    test('sends no Authorization header when there is no session', () async {
      final adapter = _StubAdapter((_) => _json(200, '{}'));
      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          accessToken: () async => null,
          refreshSession: () async => null,
          anonKey: 'anon-key',
          dio: dio,
        ),
      );

      await dio.get<dynamic>('/get-usage');

      // `Bearer null` would be a malformed credential; absence is honest.
      expect(adapter.received.single.containsKey('Authorization'), isFalse);
    });

    test('a 401 refreshes the session and replays the request once', () async {
      // The JWT lives an hour, so a token that was fine when the photo was
      // taken can expire while the OCR runs. Without this the user would see a
      // session error on a good document, with no login screen to fix it.
      var refreshes = 0;
      final adapter = _StubAdapter((options) {
        final authorized = options.headers['Authorization'] == 'Bearer fresh';
        return _json(authorized ? 200 : 401, authorized ? '{"ok":true}' : '{}');
      });

      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          accessToken: () async => 'stale',
          refreshSession: () async {
            refreshes += 1;
            return 'fresh';
          },
          anonKey: 'anon-key',
          dio: dio,
        ),
      );

      final response = await dio.get<dynamic>('/get-usage');

      expect(response.statusCode, 200);
      expect(refreshes, 1);
      expect(adapter.received.length, 2);
    });

    test('the replay carries a fresh request id', () async {
      // Without this the replay would reuse the id the server already saw and
      // be refused as a duplicate reservation (F06-T07).
      final adapter = _StubAdapter((options) {
        final authorized = options.headers['Authorization'] == 'Bearer fresh';
        return _json(authorized ? 200 : 401, '{}');
      });

      final dio = _dio(adapter);
      dio.interceptors.addAll([
        RequestIdInterceptor(),
        AuthInterceptor(
          accessToken: () async => 'stale',
          refreshSession: () async => 'fresh',
          anonKey: 'anon-key',
          dio: dio,
          generateId: () => 'replay-id',
        ),
      ]);

      await dio.get<dynamic>('/get-usage');

      expect(adapter.received[1][kRequestIdHeader], 'replay-id');
      expect(
        adapter.received[0][kRequestIdHeader],
        isNot(adapter.received[1][kRequestIdHeader]),
      );
    });

    test('a persistently rejected token retries only once', () async {
      var refreshes = 0;
      final adapter = _StubAdapter((_) => _json(401, '{}'));

      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          accessToken: () async => 'stale',
          refreshSession: () async {
            refreshes += 1;
            return 'also-stale';
          },
          anonKey: 'anon-key',
          dio: dio,
        ),
      );

      await dio.get<dynamic>('/get-usage');

      // Bounded: an unbounded refresh loop would hammer auth and hang the UI.
      expect(refreshes, 1);
      expect(adapter.received.length, 2);
    });

    test('a failed refresh lets the 401 through', () async {
      final adapter = _StubAdapter((_) => _json(401, '{}'));

      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          accessToken: () async => 'stale',
          refreshSession: () async => null,
          anonKey: 'anon-key',
          dio: dio,
        ),
      );

      final response = await dio.get<dynamic>('/get-usage');

      // The 401 survives to the repository, which maps it to
      // UnauthorizedFailure; swallowing it would look like a transport error.
      expect(response.statusCode, 401);
      expect(adapter.received.length, 1);
    });

    test('a non-401 error is not retried', () async {
      var refreshes = 0;
      final adapter = _StubAdapter((_) => _json(429, '{}'));

      final dio = _dio(adapter);
      dio.interceptors.add(
        AuthInterceptor(
          accessToken: () async => 'jwt',
          refreshSession: () async {
            refreshes += 1;
            return 'fresh';
          },
          anonKey: 'anon-key',
          dio: dio,
        ),
      );

      await dio.get<dynamic>('/get-usage');

      // Replaying a daily-limit refusal would burn a second reservation.
      expect(refreshes, 0);
      expect(adapter.received.length, 1);
    });
  });

  group('ApiLogInterceptor', () {
    test(
      'logs the request id, status and duration — and nothing else',
      () async {
        final logger = _RecordingLogger();
        final adapter = _StubAdapter(
          (_) => _json(200, '{"summary":{"short":"رقم الحساب 12345678"}}'),
        );

        final dio = _dio(adapter)
          ..interceptors.addAll([
            RequestIdInterceptor(),
            ApiLogInterceptor(logger),
          ]);

        await dio.post<dynamic>('/analyze-document', data: {'ocr_text': 'سري'});

        final line = logger.lines.single;
        expect(line['httpStatus'], 200);
        expect(line['requestId'], isNotNull);
        expect(line['durationMs'], isNotNull);

        // Dio's own LogInterceptor prints bodies and the Authorization header,
        // which is exactly what §51 forbids — hence this one replaces it.
        expect(line.keys, everyElement(isIn(kAllowedLogFields)));
        expect(line.toString(), isNot(contains('12345678')));
        expect(line.toString(), isNot(contains('سري')));
      },
    );

    test('logs a failed call too, without its message', () async {
      final logger = _RecordingLogger();
      final adapter = _StubAdapter(
        (_) => _json(429, '{"error":{"code":"DAILY_LIMIT_REACHED"}}'),
      );

      final dio = _dio(adapter)
        ..interceptors.addAll([
          RequestIdInterceptor(),
          ApiLogInterceptor(logger),
        ])
        ..options.validateStatus = (status) => status == 200;

      await dio
          .get<dynamic>('/get-usage')
          .catchError(
            (Object _) => Response<dynamic>(requestOptions: RequestOptions()),
          );

      expect(logger.lines.single['httpStatus'], 429);
      expect(logger.lines.single.keys, everyElement(isIn(kAllowedLogFields)));
    });
  });
}
