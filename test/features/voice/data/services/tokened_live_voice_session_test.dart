import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/voice/data/datasources/edge_function_live_token_data_source.dart';
import 'package:war2aty/features/voice/data/services/tokened_live_voice_session.dart';
import 'package:war2aty/features/voice/domain/entities/live_voice_event.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';
import 'package:war2aty/features/voice/domain/services/live_voice_session.dart';

/// F37-T21 · `TokenedLiveVoiceSession`.
///
/// The class exists because `ReadPaperAloud` needs a session **synchronously**
/// while the token that session connects with is fetched asynchronously. Every
/// test here is about something that can go wrong in the gap between those two
/// facts.
void main() {
  late _FakeTokenDataSource tokens;
  late List<_FakeInnerSession> built;

  TokenedLiveVoiceSession buildSession() {
    return TokenedLiveVoiceSession(
      tokens: tokens,
      build: (endpoint) {
        final inner = _FakeInnerSession();
        built.add(inner);
        return inner;
      },
    );
  }

  setUp(() {
    tokens = _FakeTokenDataSource();
    built = [];
  });

  group('the happy path', () {
    test('fetches a token, builds one inner session and starts it', () async {
      final session = buildSession();

      final result = await session.start('the paper');

      expect(result.isOk, isTrue);
      expect(tokens.fetches, 1);
      expect(built, hasLength(1));
      expect(built.single.startedWith, 'the paper');
    });

    test('format answers before any token is fetched', () {
      final session = buildSession();

      // `ReadPaperAloud` reads this to reserve the speaker *before* opening the
      // session. Fetching a token for it would put a round trip in front of
      // the first byte of audio.
      expect(session.format, PcmFormat.geminiLive);
      expect(tokens.fetches, 0);
    });

    test('events come from the inner session once started', () async {
      final session = buildSession();
      await session.start('the paper');

      built.single.emit(const LiveTurnComplete());

      expect(await session.events.first, isA<LiveTurnComplete>());
    });
  });

  group('cancelling', () {
    test(
      'a cancel during the token fetch stops the session being opened',
      () async {
        // The defect this test exists for: `cancel()` used to delegate to an
        // inner session that did not exist yet, so it did nothing, and `start`
        // went on to open the socket. `ReadPaperAloud` ends its frame loop by
        // *closing the session's stream*, so the user's stop was ignored and the
        // paper was read to the end over them.
        tokens.hold = Completer<Result<LiveSessionEndpoint, AppFailure>>();
        final session = buildSession();

        final starting = session.start('the paper');
        await pumpEventQueue();

        // Nothing built yet — we are inside the fetch, which is the window.
        expect(built, isEmpty);

        await session.cancel();
        tokens.hold!.complete(Ok(_endpoint));

        final result = await starting;

        expect(result.isErr, isTrue);
        expect(
          built,
          isEmpty,
          reason:
              'a socket was opened after the caller cancelled — the paper would '
              'be sent to the service and read aloud over a user who stopped it',
        );
      },
    );

    test(
      'cancel before start is safe and still blocks a later start',
      () async {
        final session = buildSession();

        await session.cancel();
        final result = await session.start('the paper');

        expect(result.isErr, isTrue);
        expect(built, isEmpty);
      },
    );

    test('cancel after start closes the inner session', () async {
      final session = buildSession();
      await session.start('the paper');

      await session.cancel();

      expect(built.single.cancels, 1);
    });

    test('cancel twice is safe', () async {
      final session = buildSession();
      await session.start('the paper');

      await session.cancel();
      await session.cancel();

      expect(built.single.cancels, 2);
    });

    test('cancel with no session and no start is a quiet no-op', () async {
      final session = buildSession();

      await expectLater(session.cancel(), completes);
      expect(built, isEmpty);
    });
  });

  group('failures', () {
    test(
      'the datasource failure is passed through, not reclassified',
      () async {
        // T10 maps 401, 429 and offline to *distinct* failures, and the ladder
        // reads them to decide whether falling back to the device is allowed.
        // Re-wrapping them here would flatten that.
        tokens.result = const Err(AiProviderRateLimitFailure());
        final session = buildSession();

        final result = await session.start('the paper');

        expect(result.failureOrNull, isA<AiProviderRateLimitFailure>());
        expect(built, isEmpty);
      },
    );

    test(
      'starting twice refuses rather than opening a second socket',
      () async {
        final session = buildSession();
        await session.start('the paper');

        final again = await session.start('the paper');

        expect(again.isErr, isTrue);
        expect(tokens.fetches, 1);
        expect(built, hasLength(1));
      },
    );

    test('events before start is an empty stream, not a throw', () async {
      final session = buildSession();

      // Unreachable through `ReadPaperAloud`, which subscribes only after
      // `start` answered Ok. Throwing here would take down a read that could
      // still have fallen back to the device.
      expect(await session.events.isEmpty, isTrue);
    });
  });
}

final _endpoint = LiveSessionEndpoint(
  wsUrl: Uri.parse('wss://example.test/ws?access_token=tok'),
  model: 'models/test-model',
  expiresAt: DateTime.utc(2026, 11, 15),
);

final class _FakeTokenDataSource implements LiveTokenDataSource {
  int fetches = 0;
  Result<LiveSessionEndpoint, AppFailure> result = Ok(_endpoint);

  /// When set, `fetchEndpoint` waits on it — the token-fetch window.
  Completer<Result<LiveSessionEndpoint, AppFailure>>? hold;

  @override
  Future<Result<LiveSessionEndpoint, AppFailure>> fetchEndpoint() async {
    fetches++;
    final held = hold;
    if (held != null) return held.future;
    return result;
  }
}

final class _FakeInnerSession implements LiveVoiceSession {
  final _events = StreamController<LiveVoiceEvent>();
  String? startedWith;
  int cancels = 0;

  void emit(LiveVoiceEvent event) => _events.add(event);

  @override
  PcmFormat get format => PcmFormat.geminiLive;

  @override
  Stream<LiveVoiceEvent> get events => _events.stream;

  @override
  Future<Result<void, AppFailure>> start(String turnText) async {
    startedWith = turnText;
    return const Ok(null);
  }

  @override
  Future<void> cancel() async {
    cancels++;
    // Not awaited: closing a single-subscription controller that nobody has
    // listened to returns a Future that never completes, which hangs the test
    // rather than failing it.
    if (!_events.isClosed) unawaited(_events.close());
  }
}
