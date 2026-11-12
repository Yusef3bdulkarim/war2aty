import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/voice/data/services/gemini_live_voice_session.dart';
import 'package:war2aty/features/voice/domain/entities/live_voice_event.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../support/live_frames.dart';

void main() {
  late _FakeWebSocketChannel fakeChannel;
  late GeminiLiveVoiceSession session;

  GeminiLiveVoiceSession buildSession({
    Duration interFrameTimeout = const Duration(seconds: 10),
    Duration totalTimeout = const Duration(seconds: 60),
  }) {
    return GeminiLiveVoiceSession(
      endpoint: Uri.parse('wss://test.example.com/ws'),
      model: 'test-model',
      connect: (_) async => fakeChannel,
      interFrameTimeout: interFrameTimeout,
      totalTimeout: totalTimeout,
    );
  }

  setUp(() {
    fakeChannel = _FakeWebSocketChannel();
  });

  // ── format ──────────────────────────────────────────────────────────────

  test('format is Gemini Live PCM', () {
    session = buildSession();
    expect(session.format, PcmFormat.geminiLive);
  });

  // ── clean turn ──────────────────────────────────────────────────────────

  group('clean turn', () {
    test('setup → audio → transcript → turnComplete yields events and Ok', () {
      fakeAsync((async) {
        session = buildSession();
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        Result<void, AppFailure>? result;
        session.start('paper text').then((r) => result = r);
        async.flushMicrotasks();

        // Setup frame was sent.
        expect(fakeChannel.sent, hasLength(1));
        final setup =
            jsonDecode(fakeChannel.sent.first) as Map<String, dynamic>;
        expect(setup.containsKey('setup'), isTrue);
        final setupBody = setup['setup'] as Map<String, dynamic>;
        expect(setupBody['model'], 'models/test-model');

        // Server acknowledges setup.
        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        // User turn was sent; start() completed.
        expect(fakeChannel.sent, hasLength(2));
        final turn = jsonDecode(fakeChannel.sent[1]) as Map<String, dynamic>;
        expect(turn.containsKey('clientContent'), isTrue);
        expect(result?.isOk, isTrue);

        // Audio arrives.
        final pcm = testPcmChunk();
        fakeChannel.serverSends(audioFrame(pcm));
        async.flushMicrotasks();

        expect(events.whereType<LivePcmChunk>(), hasLength(1));
        final chunk = events.whereType<LivePcmChunk>().first;
        expect(chunk.bytes.length, pcm.length);

        // Transcription arrives.
        fakeChannel.serverSends(transcriptFrame('كلمة'));
        async.flushMicrotasks();

        expect(events.whereType<LiveTranscriptDelta>(), hasLength(1));
        expect(events.whereType<LiveTranscriptDelta>().first.text, 'كلمة');

        // Turn complete.
        fakeChannel.serverSends(turnCompleteFrame());
        async.flushMicrotasks();

        expect(events.last, isA<LiveTurnComplete>());
        expect(events.whereType<LiveSessionLost>(), isEmpty);

        session.cancel();
      });
    });

    test('generationComplete also finishes the session', () {
      fakeAsync((async) {
        session = buildSession();
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        fakeChannel.serverSends(turnCompleteFrame(generation: true));
        async.flushMicrotasks();

        expect(events.last, isA<LiveTurnComplete>());

        session.cancel();
      });
    });

    test('the system instruction matches the spike verbatim', () {
      fakeAsync((async) {
        session = buildSession();
        session.events.listen((_) {});

        session.start('text').then((_) {});
        async.flushMicrotasks();

        final setup =
            jsonDecode(fakeChannel.sent.first) as Map<String, dynamic>;
        final body = setup['setup'] as Map<String, dynamic>;
        final instruction = body['systemInstruction'] as Map<String, dynamic>;
        final parts = instruction['parts'] as List<dynamic>;
        final text = (parts[0] as Map<String, dynamic>)['text'] as String;

        expect(
          text,
          'اقرأ النص التالي بالحرف، كلمة بكلمة، من غير أي إضافة أو تعليق أو ترحيب، '
          'ومن غير ما تغيّر أي كلمة أو رقم أو تاريخ. متقولش حاجة غير النص نفسه.',
        );

        session.cancel();
      });
    });

    test('the four spike conditions are all present in setup', () {
      fakeAsync((async) {
        session = buildSession();
        session.events.listen((_) {});

        session.start('text').then((_) {});
        async.flushMicrotasks();

        final setup =
            jsonDecode(fakeChannel.sent.first) as Map<String, dynamic>;
        final body = setup['setup'] as Map<String, dynamic>;
        final config = body['generationConfig'] as Map<String, dynamic>;

        expect(config['responseModalities'], ['AUDIO']);
        expect(config['temperature'], 0);
        expect(body.containsKey('systemInstruction'), isTrue);
        expect(body.containsKey('outputAudioTranscription'), isTrue);

        session.cancel();
      });
    });
  });

  // ── mid-stream drop ─────────────────────────────────────────────────────

  group('mid-stream drop', () {
    test('socket closes after audio → VoiceStreamInterruptedFailure', () {
      fakeAsync((async) {
        session = buildSession();
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        // Some audio arrives.
        final pcm = testPcmOneSecond();
        fakeChannel.serverSends(audioFrame(pcm));
        async.flushMicrotasks();

        expect(events.whereType<LivePcmChunk>(), hasLength(1));

        // Socket drops.
        fakeChannel.serverCloses();
        async.flushMicrotasks();

        final lost = events.whereType<LiveSessionLost>().single;
        expect(lost.failure, isA<VoiceStreamInterruptedFailure>());
        final interrupted = lost.failure as VoiceStreamInterruptedFailure;
        expect(
          interrupted.heard,
          PcmFormat.geminiLive.durationOfBytes(pcm.length),
        );
      });
    });

    test('heard duration accumulates across multiple audio frames', () {
      fakeAsync((async) {
        session = buildSession();
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        final pcm = testPcmChunk();
        fakeChannel.serverSends(audioFrame(pcm));
        async.flushMicrotasks();
        fakeChannel.serverSends(audioFrame(pcm));
        async.flushMicrotasks();
        fakeChannel.serverSends(audioFrame(pcm));
        async.flushMicrotasks();

        fakeChannel.serverCloses();
        async.flushMicrotasks();

        final lost = events.whereType<LiveSessionLost>().single;
        final interrupted = lost.failure as VoiceStreamInterruptedFailure;
        expect(
          interrupted.heard,
          PcmFormat.geminiLive.durationOfBytes(pcm.length * 3),
        );
      });
    });
  });

  // ── 1007 close ──────────────────────────────────────────────────────────

  group('1007 close (goAway)', () {
    test('1007 before audio → VoiceServiceFailure', () {
      fakeAsync((async) {
        session = buildSession();
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        Result<void, AppFailure>? result;
        session.start('text').then((r) => result = r);
        async.flushMicrotasks();

        // Server closes with 1007 before setup completes.
        fakeChannel.serverCloses(1007, 'goAway');
        async.flushMicrotasks();

        expect(result?.isErr, isTrue);
        expect(result?.failureOrNull, isA<VoiceServiceFailure>());
      });
    });

    test('1007 after audio → VoiceStreamInterruptedFailure with heard', () {
      fakeAsync((async) {
        session = buildSession();
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        final pcm = testPcmOneSecond();
        fakeChannel.serverSends(audioFrame(pcm));
        async.flushMicrotasks();

        fakeChannel.serverCloses(1007, 'goAway');
        async.flushMicrotasks();

        final lost = events.whereType<LiveSessionLost>().single;
        expect(lost.failure, isA<VoiceStreamInterruptedFailure>());
      });
    });
  });

  // ── error frame ─────────────────────────────────────────────────────────

  group('error frame', () {
    test('error during setup → start returns Err', () {
      fakeAsync((async) {
        session = buildSession();
        session.events.listen((_) {});

        Result<void, AppFailure>? result;
        session.start('text').then((r) => result = r);
        async.flushMicrotasks();

        fakeChannel.serverSends(errorFrame());
        async.flushMicrotasks();

        expect(result?.isErr, isTrue);
        expect(result?.failureOrNull, isA<VoiceServiceFailure>());
      });
    });

    test('error after setup → LiveSessionLost(VoiceServiceFailure)', () {
      fakeAsync((async) {
        session = buildSession();
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        fakeChannel.serverSends(errorFrame(code: 500, message: 'boom'));
        async.flushMicrotasks();

        final lost = events.whereType<LiveSessionLost>().single;
        expect(lost.failure, isA<VoiceServiceFailure>());
      });
    });
  });

  // ── connect failure ─────────────────────────────────────────────────────

  test('connect failure → start returns Err', () {
    fakeAsync((async) {
      session = GeminiLiveVoiceSession(
        endpoint: Uri.parse('wss://test.example.com/ws'),
        model: 'test-model',
        connect: (_) async => throw Exception('no network'),
      );
      session.events.listen((_) {});

      Result<void, AppFailure>? result;
      session.start('text').then((r) => result = r);
      async.flushMicrotasks();

      expect(result?.isErr, isTrue);
      expect(result?.failureOrNull, isA<VoiceServiceFailure>());
    });
  });

  // ── watchdogs ───────────────────────────────────────────────────────────

  group('inter-frame watchdog', () {
    test('fires after silence with no audio → VoiceServiceFailure', () {
      fakeAsync((async) {
        session = buildSession(interFrameTimeout: const Duration(seconds: 5));
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        // No frames for 5 seconds.
        async.elapse(const Duration(seconds: 5));

        final lost = events.whereType<LiveSessionLost>().single;
        expect(lost.failure, isA<VoiceServiceFailure>());
      });
    });

    test('fires after silence with audio → VoiceStreamInterruptedFailure', () {
      fakeAsync((async) {
        session = buildSession(interFrameTimeout: const Duration(seconds: 5));
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        fakeChannel.serverSends(audioFrame(testPcmChunk()));
        async.flushMicrotasks();

        // No more frames for 5 seconds.
        async.elapse(const Duration(seconds: 5));

        final lost = events.whereType<LiveSessionLost>().single;
        expect(lost.failure, isA<VoiceStreamInterruptedFailure>());
      });
    });

    test('resets on each frame', () {
      fakeAsync((async) {
        session = buildSession(interFrameTimeout: const Duration(seconds: 5));
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        // Frame at +4 s resets the timer.
        async.elapse(const Duration(seconds: 4));
        fakeChannel.serverSends(audioFrame(testPcmChunk()));
        async.flushMicrotasks();

        // Frame at +8 s resets again.
        async.elapse(const Duration(seconds: 4));
        fakeChannel.serverSends(audioFrame(testPcmChunk()));
        async.flushMicrotasks();

        // No loss yet — each frame arrived before the 5 s deadline.
        expect(events.whereType<LiveSessionLost>(), isEmpty);

        // Now let it expire.
        async.elapse(const Duration(seconds: 5));
        expect(events.whereType<LiveSessionLost>(), hasLength(1));

        session.cancel();
      });
    });
  });

  group('total watchdog', () {
    test('fires after total timeout', () {
      fakeAsync((async) {
        session = buildSession(
          totalTimeout: const Duration(seconds: 30),
          interFrameTimeout: const Duration(seconds: 60),
        );
        final events = <LiveVoiceEvent>[];
        session.events.listen(events.add);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        // Keep sending frames so inter-frame doesn't fire first.
        for (var i = 0; i < 5; i++) {
          fakeChannel.serverSends(audioFrame(testPcmChunk()));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 6));
        }
        // 30 s have passed — total watchdog fires.

        final lost = events.whereType<LiveSessionLost>().single;
        expect(lost.failure, isA<VoiceStreamInterruptedFailure>());

        session.cancel();
      });
    });
  });

  // ── cancel ──────────────────────────────────────────────────────────────

  group('cancel', () {
    test('before start is safe', () async {
      session = buildSession();
      await session.cancel();
      await session.cancel(); // idempotent
    });

    test('during streaming closes the event stream', () {
      fakeAsync((async) {
        session = buildSession();
        var streamDone = false;
        session.events.listen((_) {}, onDone: () => streamDone = true);

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        fakeChannel.serverSends(audioFrame(testPcmChunk()));
        async.flushMicrotasks();

        session.cancel();
        async.flushMicrotasks();

        expect(streamDone, isTrue);
      });
    });

    test('after completion is safe', () {
      fakeAsync((async) {
        session = buildSession();
        session.events.listen((_) {});

        session.start('text').then((_) {});
        async.flushMicrotasks();

        fakeChannel.serverSends(setupCompleteFrame);
        async.flushMicrotasks();

        fakeChannel.serverSends(turnCompleteFrame());
        async.flushMicrotasks();

        session.cancel();
        async.flushMicrotasks();
        session.cancel(); // idempotent
      });
    });
  });

  // ── double start ────────────────────────────────────────────────────────

  test('calling start twice returns Err on the second call', () async {
    session = buildSession();
    session.events.listen((_) {});

    // First call proceeds (will await, but we don't need it to finish).
    unawaited(session.start('text'));
    await Future<void>.delayed(Duration.zero);

    final second = await session.start('text again');
    expect(second.isErr, isTrue);

    await session.cancel();
  });

  // ── socket close before setup ───────────────────────────────────────────

  test('socket closes before setupComplete → start returns Err', () {
    fakeAsync((async) {
      session = buildSession();
      session.events.listen((_) {});

      Result<void, AppFailure>? result;
      session.start('text').then((r) => result = r);
      async.flushMicrotasks();

      fakeChannel.serverCloses();
      async.flushMicrotasks();

      expect(result?.isErr, isTrue);
      expect(result?.failureOrNull, isA<VoiceServiceFailure>());
    });
  });

  // ── unknown frames are ignored ──────────────────────────────────────────

  test('unknown frames do not crash or finish the session', () {
    fakeAsync((async) {
      session = buildSession();
      final events = <LiveVoiceEvent>[];
      session.events.listen(events.add);

      session.start('text').then((_) {});
      async.flushMicrotasks();

      fakeChannel.serverSends(setupCompleteFrame);
      async.flushMicrotasks();

      fakeChannel.serverSends('{"toolCall":{"name":"test"}}');
      async.flushMicrotasks();

      // No loss, no crash.
      expect(events.whereType<LiveSessionLost>(), isEmpty);
      expect(events.whereType<LiveTurnComplete>(), isEmpty);

      // Session still alive — turnComplete still works.
      fakeChannel.serverSends(turnCompleteFrame());
      async.flushMicrotasks();

      expect(events.last, isA<LiveTurnComplete>());

      session.cancel();
    });
  });
}

// ── fake WebSocket channel ────────────────────────────────────────────────

class _FakeWebSocketChannel extends Fake implements WebSocketChannel {
  final _incoming = StreamController<dynamic>();
  final sent = <String>[];
  int? _closeCode;
  String? _closeReason;

  late final _sink = _FakeWebSocketSink(this);

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  Future<void> get ready => Future<void>.value();

  void serverSends(String json) => _incoming.add(json);

  void serverCloses([int? code, String? reason]) {
    _closeCode = code;
    _closeReason = reason;
    _incoming.close();
  }
}

class _FakeWebSocketSink extends Fake implements WebSocketSink {
  _FakeWebSocketSink(this._channel);
  final _FakeWebSocketChannel _channel;

  @override
  void add(dynamic data) => _channel.sent.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  Future<void> get done => Completer<void>().future;
}
