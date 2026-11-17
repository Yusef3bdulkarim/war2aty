import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/voice/just_audio_fixed_line_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const globalChannel = MethodChannel('com.ryanheise.just_audio.methods');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final playerIds = <String>[];
  final eventSinks = <String, MockStreamHandlerEventSink>{};

  Map<String, dynamic> completedEvent() => <String, dynamic>{
    'processingState': 4,
    'updateTime': DateTime.now().millisecondsSinceEpoch,
    'updatePosition': 0,
    'bufferedPosition': 0,
    'duration': -1,
    'icyMetadata': null,
    'currentIndex': null,
    'androidAudioSessionId': null,
    'errorCode': null,
    'errorMessage': null,
  };

  var failNextLoad = false;

  setUp(() {
    playerIds.clear();
    eventSinks.clear();
    failNextLoad = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => Directory.systemTemp.createTempSync().path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalChannel, (call) async {
          if (call.method == 'disposeAllPlayers') return <String, dynamic>{};
          if (call.method == 'init') {
            final id = (call.arguments as Map)['id'] as String;
            playerIds.add(id);
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  MethodChannel('com.ryanheise.just_audio.methods.$id'),
                  (playerCall) async {
                    if (playerCall.method == 'load') {
                      if (failNextLoad) {
                        throw PlatformException(
                          code: 'UNSUPPORTED',
                          message: 'test environment',
                        );
                      }
                      return <String, dynamic>{'duration': -1};
                    }
                    return <String, dynamic>{};
                  },
                );
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockStreamHandler(
                  EventChannel('com.ryanheise.just_audio.events.$id'),
                  MockStreamHandler.inline(
                    onListen: (args, events) {
                      eventSinks[id] = events;
                    },
                  ),
                );
            return <String, dynamic>{};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalChannel, null);
    for (final id in playerIds) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel('com.ryanheise.just_audio.methods.$id'),
            null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            EventChannel('com.ryanheise.just_audio.events.$id'),
            null,
          );
    }
  });

  group('JustAudioFixedLinePlayer.playToEnd', () {
    test('completes when the line reaches its natural end', () async {
      final player = JustAudioFixedLinePlayer();

      final future = player.playToEnd('assets/voice_lines/waiting_reading.m4a');
      await pumpEventQueue();

      final id = playerIds.single;
      eventSinks[id]!.success(completedEvent());

      final result = await future;
      expect(result.isOk, isTrue);

      await player.dispose();
    });

    test('completes when stop() is called mid-playback', () async {
      final player = JustAudioFixedLinePlayer();

      final future = player.playToEnd('assets/voice_lines/waiting_reading.m4a');
      await pumpEventQueue();

      await player.stop();

      final result = await future;
      expect(result.isOk, isTrue);

      await player.dispose();
    });

    test(
      'returns AudioPlaybackFailure on a load failure, never hangs',
      () async {
        failNextLoad = true;
        final player = JustAudioFixedLinePlayer();

        final result = await player.playToEnd(
          'assets/voice_lines/waiting_reading.m4a',
        );

        expect(result.failureOrNull, isA<AudioPlaybackFailure>());

        await player.dispose();
      },
    );
  });
}
