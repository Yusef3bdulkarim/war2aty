import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/voice/data/services/method_channel_live_audio_output.dart';
import 'package:war2aty/features/voice/domain/entities/pcm_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const control = MethodChannel('com.war2aty.app/voice_audio');
  const pcm = 'com.war2aty.app/voice_audio_pcm';

  late MethodChannelLiveAudioOutput output;
  late List<String> methodLog;
  late List<Uint8List> writtenChunks;
  late Map<String, Object? Function()> methodResponses;

  void installMocks() {
    methodLog = [];
    writtenChunks = [];
    methodResponses = {
      'open': () => true,
      'beginEncode': () => true,
      'pause': () => null,
      'resume': () => null,
      'stop': () => 5000000,
      'getPosition': () => 1000000,
      'finishEncode': () => Uint8List.fromList([0xFF, 0xF1, 0x50, 0x80]),
      'abortEncode': () => null,
    };

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(control, (call) async {
          methodLog.add(call.method);
          final handler = methodResponses[call.method];
          if (handler != null) return handler();
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(pcm, (message) async {
          if (message != null) {
            writtenChunks.add(
              Uint8List.view(
                message.buffer,
                message.offsetInBytes,
                message.lengthInBytes,
              ),
            );
          }
          return null;
        });
  }

  void clearMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(control, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(pcm, null);
  }

  setUp(() {
    output = MethodChannelLiveAudioOutput(
      pollInterval: const Duration(milliseconds: 100),
    );
    installMocks();
  });

  tearDown(clearMocks);

  // ── PcmAudioSink.open ─────────────────────────────────────────────

  group('open', () {
    test('success returns Ok', () async {
      final result = await output.open(PcmFormat.geminiLive);
      expect(result.isOk, isTrue);
      expect(methodLog, contains('open'));
    });

    test('passes format parameters to the host', () async {
      Map<String, dynamic>? args;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, (call) async {
            if (call.method == 'open') args = Map.from(call.arguments as Map);
            return true;
          });
      await output.open(PcmFormat.geminiLive);
      expect(args, {'sampleRate': 24000, 'channels': 1, 'bitsPerSample': 16});
    });

    test('host returning false yields AudioPlaybackFailure', () async {
      methodResponses['open'] = () => false;
      final result = await output.open(PcmFormat.geminiLive);
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioPlaybackFailure>());
    });

    test('MissingPluginException yields AudioPlaybackFailure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, null);
      final result = await output.open(PcmFormat.geminiLive);
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioPlaybackFailure>());
    });

    test('PlatformException yields AudioPlaybackFailure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, (call) async {
            if (call.method == 'open') {
              throw PlatformException(code: 'ERROR');
            }
            return null;
          });
      final result = await output.open(PcmFormat.geminiLive);
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioPlaybackFailure>());
    });
  });

  // ── PcmAudioSink.write ────────────────────────────────────────────

  group('write', () {
    test('sends chunks through the binary channel', () async {
      await output.open(PcmFormat.geminiLive);
      final chunk = Uint8List.fromList([1, 2, 3, 4]);
      await output.write(chunk);
      expect(writtenChunks, hasLength(1));
      expect(writtenChunks.first, [1, 2, 3, 4]);
    });

    test('preserves chunk order across multiple writes', () async {
      await output.open(PcmFormat.geminiLive);
      for (var i = 0; i < 5; i++) {
        await output.write(Uint8List.fromList([i]));
      }
      expect(writtenChunks, hasLength(5));
      for (var i = 0; i < 5; i++) {
        expect(writtenChunks[i], [i]);
      }
    });

    test('does nothing before open', () async {
      await output.write(Uint8List.fromList([1, 2, 3]));
      expect(writtenChunks, isEmpty);
    });

    test('does nothing after stop', () async {
      await output.open(PcmFormat.geminiLive);
      await output.stop();
      writtenChunks.clear();
      await output.write(Uint8List.fromList([1, 2, 3]));
      expect(writtenChunks, isEmpty);
    });
  });

  // ── PcmAudioSink.pause / resume ───────────────────────────────────

  group('pause and resume', () {
    test('pause invokes the host method', () async {
      await output.open(PcmFormat.geminiLive);
      await output.pause();
      expect(methodLog, contains('pause'));
    });

    test('resume invokes the host method', () async {
      await output.open(PcmFormat.geminiLive);
      await output.resume();
      expect(methodLog, contains('resume'));
    });

    test('pause does not throw on MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, null);
      await expectLater(output.pause(), completes);
    });

    test('resume does not throw on MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, null);
      await expectLater(output.resume(), completes);
    });
  });

  // ── PcmAudioSink.stop ─────────────────────────────────────────────

  group('stop', () {
    test('returns the played duration from the host', () async {
      await output.open(PcmFormat.geminiLive);
      final duration = await output.stop();
      expect(duration, const Duration(microseconds: 5000000));
      expect(methodLog, contains('stop'));
    });

    test('MissingPluginException yields Duration.zero', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, null);
      // open would fail, so test stop directly
      output = MethodChannelLiveAudioOutput(
        pollInterval: const Duration(milliseconds: 100),
      );
      final duration = await output.stop();
      expect(duration, Duration.zero);
    });

    test('PlatformException yields Duration.zero', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, (call) async {
            if (call.method == 'stop') throw PlatformException(code: 'ERROR');
            return true;
          });
      await output.open(PcmFormat.geminiLive);
      final duration = await output.stop();
      expect(duration, Duration.zero);
    });

    test('emits the final position on the position stream', () async {
      await output.open(PcmFormat.geminiLive);
      final positions = <Duration>[];
      output.position.listen(positions.add);
      await output.stop();
      expect(positions, contains(const Duration(microseconds: 5000000)));
    });
  });

  // ── AudioEncoder.begin ─────────────────────────────────────────────

  group('beginEncode', () {
    test('success returns Ok', () async {
      final result = await output.begin(PcmFormat.geminiLive);
      expect(result.isOk, isTrue);
      expect(methodLog, contains('beginEncode'));
    });

    test('host returning false yields AudioEncodingFailure', () async {
      methodResponses['beginEncode'] = () => false;
      final result = await output.begin(PcmFormat.geminiLive);
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioEncodingFailure>());
    });

    test('MissingPluginException yields AudioEncodingFailure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, null);
      final result = await output.begin(PcmFormat.geminiLive);
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioEncodingFailure>());
    });

    test('PlatformException yields AudioEncodingFailure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, (call) async {
            if (call.method == 'beginEncode') {
              throw PlatformException(code: 'ERROR');
            }
            return null;
          });
      final result = await output.begin(PcmFormat.geminiLive);
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioEncodingFailure>());
    });
  });

  // ── AudioEncoder.feed ──────────────────────────────────────────────

  group('feed', () {
    test('is a no-op — does not send to the binary channel', () async {
      await output.feed(Uint8List.fromList([1, 2, 3]));
      expect(writtenChunks, isEmpty);
      expect(methodLog, isEmpty);
    });
  });

  // ── AudioEncoder.finish ────────────────────────────────────────────

  group('finishEncode', () {
    test('returns the encoded bytes from the host', () async {
      final result = await output.finish();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, Uint8List.fromList([0xFF, 0xF1, 0x50, 0x80]));
      expect(methodLog, contains('finishEncode'));
    });

    test('null from host yields AudioEncodingFailure', () async {
      methodResponses['finishEncode'] = () => null;
      final result = await output.finish();
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioEncodingFailure>());
    });

    test('empty bytes from host yields AudioEncodingFailure', () async {
      methodResponses['finishEncode'] = () => Uint8List(0);
      final result = await output.finish();
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioEncodingFailure>());
    });

    test('MissingPluginException yields AudioEncodingFailure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, null);
      final result = await output.finish();
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioEncodingFailure>());
    });

    test('PlatformException yields AudioEncodingFailure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, (call) async {
            if (call.method == 'finishEncode') {
              throw PlatformException(code: 'ERROR');
            }
            return null;
          });
      final result = await output.finish();
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<AudioEncodingFailure>());
    });
  });

  // ── AudioEncoder.abort ─────────────────────────────────────────────

  group('abort', () {
    test('invokes the host method', () async {
      await output.abort();
      expect(methodLog, contains('abortEncode'));
    });

    test('does not throw on MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(control, null);
      await expectLater(output.abort(), completes);
    });
  });

  // ── position polling ───────────────────────────────────────────────

  group('position stream', () {
    test('emits polled values after open', () {
      fakeAsync((async) {
        int positionUs = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(control, (call) {
              if (call.method == 'open') return Future.value(true);
              if (call.method == 'getPosition') {
                positionUs += 200000;
                return Future.value(positionUs);
              }
              return Future<dynamic>.value();
            });

        final positions = <Duration>[];
        output.position.listen(positions.add);

        output.open(PcmFormat.geminiLive);
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 350));

        expect(positions.length, greaterThanOrEqualTo(2));
        expect(positions.first, const Duration(microseconds: 200000));
      });
    });

    test('stops polling after stop', () {
      fakeAsync((async) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(control, (call) {
              if (call.method == 'open') return Future.value(true);
              if (call.method == 'getPosition') return Future.value(100000);
              if (call.method == 'stop') return Future.value(100000);
              return Future<dynamic>.value();
            });

        final positions = <Duration>[];
        output.position.listen(positions.add);

        output.open(PcmFormat.geminiLive);
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 150));
        final countBeforeStop = positions.length;

        output.stop();
        async.flushMicrotasks();

        positions.clear();
        async.elapse(const Duration(milliseconds: 500));

        // Only the final position from stop(), no further polls.
        expect(positions, isEmpty);
        expect(countBeforeStop, greaterThan(0));
      });
    });
  });

  // ── full flow ──────────────────────────────────────────────────────

  group('full flow', () {
    test('open → begin → write chunks → stop → finish', () async {
      final openResult = await output.open(PcmFormat.geminiLive);
      expect(openResult.isOk, isTrue);

      final beginResult = await output.begin(PcmFormat.geminiLive);
      expect(beginResult.isOk, isTrue);

      for (var i = 0; i < 3; i++) {
        await output.write(Uint8List.fromList([i, i + 1, i + 2]));
      }
      expect(writtenChunks, hasLength(3));

      final duration = await output.stop();
      expect(duration, const Duration(microseconds: 5000000));

      final finishResult = await output.finish();
      expect(finishResult.isOk, isTrue);

      expect(
        methodLog,
        containsAllInOrder(['open', 'beginEncode', 'stop', 'finishEncode']),
      );
    });

    test('open → write → abort discards without finish', () async {
      await output.open(PcmFormat.geminiLive);
      await output.begin(PcmFormat.geminiLive);
      await output.write(Uint8List.fromList([1, 2, 3]));
      await output.abort();

      expect(methodLog, contains('abortEncode'));
      expect(methodLog, isNot(contains('finishEncode')));
    });
  });
}
