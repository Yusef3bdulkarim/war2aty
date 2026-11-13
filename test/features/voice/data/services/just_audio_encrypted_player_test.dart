import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/encrypted_audio_store.dart';
import 'package:war2aty/features/voice/data/services/just_audio_encrypted_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleAudio = Uint8List.fromList(List.generate(256, (i) => i % 256));

  const globalChannel = MethodChannel('com.ryanheise.just_audio.methods');
  final playerChannels = <MethodChannel>[];

  setUp(() {
    playerChannels.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalChannel, (call) async {
          if (call.method == 'disposeAllPlayers') return <String, dynamic>{};
          if (call.method == 'init') {
            final id = (call.arguments as Map)['id'] as String;
            final ch = MethodChannel('com.ryanheise.just_audio.methods.$id');
            playerChannels.add(ch);
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(ch, (playerCall) async {
                  if (playerCall.method == 'load') {
                    throw PlatformException(
                      code: 'UNSUPPORTED',
                      message: 'test environment',
                    );
                  }
                  if (playerCall.method == 'dispose')
                    return <String, dynamic>{};
                  return <String, dynamic>{};
                });
            return <String, dynamic>{};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalChannel, null);
    for (final ch in playerChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, null);
    }
    playerChannels.clear();
  });

  group('JustAudioEncryptedPlayer', () {
    test('isLoaded is false before load', () async {
      final player = JustAudioEncryptedPlayer(
        store: _FakeStore(const Err(FileStorageFailure())),
      );
      expect(player.isLoaded, isFalse);
      await player.dispose();
    });

    test('propagates store FileStorageFailure on missing audio', () async {
      final player = JustAudioEncryptedPlayer(
        store: _FakeStore(const Err(FileStorageFailure())),
      );

      final result = await player.load('missing-id');

      expect(result.failureOrNull, isA<FileStorageFailure>());
      expect(player.isLoaded, isFalse);
      await player.dispose();
    });

    test('propagates store FileEncryptionFailure on corrupt audio', () async {
      final player = JustAudioEncryptedPlayer(
        store: _FakeStore(const Err(FileEncryptionFailure())),
      );

      final result = await player.load('corrupt-id');

      expect(result.failureOrNull, isA<FileEncryptionFailure>());
      expect(player.isLoaded, isFalse);
      await player.dispose();
    });

    test('returns AudioPlaybackFailure when platform player fails', () async {
      final player = JustAudioEncryptedPlayer(
        store: _FakeStore(Ok(sampleAudio)),
      );

      final result = await player.load('some-id');

      expect(result.failureOrNull, isA<AudioPlaybackFailure>());
      expect(player.isLoaded, isFalse);
      await player.dispose();
    });

    test('dispose resets isLoaded', () async {
      final player = JustAudioEncryptedPlayer(
        store: _FakeStore(const Err(FileStorageFailure())),
      );
      await player.load('any');
      await player.dispose();
      expect(player.isLoaded, isFalse);
    });

    test('load passes the requested id to the store', () async {
      String? requestedId;
      final player = JustAudioEncryptedPlayer(
        store: _SpyStore(
          result: const Err(FileStorageFailure()),
          onLoad: (id) => requestedId = id,
        ),
      );

      await player.load('paper-42');

      expect(requestedId, 'paper-42');
      await player.dispose();
    });
  });
}

final class _FakeStore implements EncryptedAudioStore {
  _FakeStore(this._loadResult);

  final Result<Uint8List, AppFailure> _loadResult;

  @override
  Future<Result<Uint8List, AppFailure>> load(String id) async => _loadResult;

  @override
  Future<Result<String, AppFailure>> store({
    required String id,
    required Uint8List audioBytes,
  }) async => throw UnimplementedError();

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<bool> exists(String id) async => false;
}

final class _SpyStore extends _FakeStore {
  _SpyStore({
    required Result<Uint8List, AppFailure> result,
    required this.onLoad,
  }) : super(result);

  final void Function(String id) onLoad;

  @override
  Future<Result<Uint8List, AppFailure>> load(String id) async {
    onLoad(id);
    return super.load(id);
  }
}
