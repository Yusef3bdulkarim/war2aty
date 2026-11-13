import 'package:just_audio/just_audio.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/voice/encrypted_audio_store.dart';
import 'encrypted_m4a_audio_source.dart';

/// Replays an encrypted `.m4a` from the [EncryptedAudioStore] via `just_audio`
/// (F37-T16).
///
/// The audio is decrypted into an in-memory buffer and served to
/// `just_audio`'s platform player through [EncryptedM4aAudioSource], so the
/// full file never touches disk in plaintext. Seek is supported because the
/// source handles arbitrary range requests from the buffer.
///
/// This class is the data-layer implementation; `VoicePlaybackCubit` (T19)
/// reaches it through a use case.
final class JustAudioEncryptedPlayer {
  JustAudioEncryptedPlayer({
    required EncryptedAudioStore store,
    AudioPlayer? player,
  }) : _store = store,
       _player = player ?? AudioPlayer();

  final EncryptedAudioStore _store;
  final AudioPlayer _player;

  bool _loaded = false;

  /// Decrypts the audio for [id] and prepares `just_audio` to play it.
  ///
  /// Returns the duration reported by the platform player, or [Duration.zero]
  /// when the player cannot determine it (some containers report duration only
  /// after a seek or play). Propagates the store's failure on a missing or
  /// corrupt file, and returns [AudioPlaybackFailure] when the platform player
  /// refuses the source.
  Future<Result<Duration, AppFailure>> load(String id) async {
    final result = await _store.load(id);
    return result.when(
      ok: (bytes) async {
        try {
          final source = EncryptedM4aAudioSource(bytes);
          final duration = await _player.setAudioSource(source);
          _loaded = true;
          return Ok(duration ?? Duration.zero);
        } on Object {
          return const Err(AudioPlaybackFailure());
        }
      },
      err: (failure) async => Err(failure),
    );
  }

  /// Whether [load] has completed successfully.
  bool get isLoaded => _loaded;

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() => _player.stop();

  /// The playback position, updated by the platform player.
  Stream<Duration> get positionStream => _player.positionStream;

  /// The total duration, available after [load] succeeds.
  Duration? get duration => _player.duration;

  /// The player state (playing/paused/stopped and processing state).
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  /// Releases the platform player. Must be called when the replay is done.
  Future<void> dispose() async {
    _loaded = false;
    await _player.dispose();
  }
}
