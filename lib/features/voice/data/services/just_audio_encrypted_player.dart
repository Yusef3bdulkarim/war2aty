import 'package:just_audio/just_audio.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/voice/encrypted_audio_store.dart';
import '../../domain/services/saved_audio_player.dart';
import 'encrypted_m4a_audio_source.dart';

/// Replays an encrypted `.m4a` from the [EncryptedAudioStore] via `just_audio`
/// (F37-T16).
///
/// The audio is decrypted into an in-memory buffer and served to
/// `just_audio`'s platform player through [EncryptedM4aAudioSource], so the
/// full file never touches disk in plaintext. Seek is supported because the
/// source handles arbitrary range requests from the buffer.
///
/// This class is the data-layer implementation of [SavedAudioPlayer];
/// `VoicePlaybackCubit` (T19) reaches it through `ReplaySavedAudio`.
final class JustAudioEncryptedPlayer implements SavedAudioPlayer {
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
  @override
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

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Stops the playback and releases the decoder.
  ///
  /// The source goes with it — `just_audio` requires a fresh
  /// `setAudioSource` — so [isLoaded] falls back to false and a later replay
  /// goes through [load] again. That is what [ReplaySavedAudio] does on every
  /// path out of a replay.
  @override
  Future<void> stop() async {
    _loaded = false;
    await _player.stop();
  }

  /// The playback position, updated by the platform player.
  @override
  Stream<Duration> get position => _player.positionStream;

  /// Each time the playback reaches the end of the audio.
  ///
  /// `just_audio` reports this as a *state*, which repeats for as long as the
  /// player sits finished; this is the edge of it, so a paper heard to the end
  /// is reported once rather than on every state event that follows.
  @override
  Stream<void> get completions => _player.playerStateStream
      .map((state) => state.processingState == ProcessingState.completed)
      .distinct()
      .where((completed) => completed);

  /// Releases the platform player. Must be called when the replay is done.
  Future<void> dispose() async {
    _loaded = false;
    await _player.dispose();
  }
}
