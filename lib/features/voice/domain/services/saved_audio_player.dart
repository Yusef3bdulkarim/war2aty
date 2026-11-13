import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';

/// Plays back a reading that was already saved (F37-T19).
///
/// The second of the spine's two phases. Where `PcmAudioSink` plays audio that
/// is still arriving — no length, no seeking, the paper heard once from the
/// top — this plays a finished `.m4a` out of the encrypted store, which is a
/// different thing entirely: the length is known, so the position means
/// something, and any position can be jumped to.
///
/// An interface for the same reason `PcmAudioSink` is one: the implementation
/// (`JustAudioEncryptedPlayer`, T16) belongs to a package, and the domain may
/// not import one. It also keeps `ReplaySavedAudio` testable without a
/// platform player.
///
/// **It does not own the store's key space.** [load] takes the same opaque
/// [id] the read was stored under, so the spine stays clear of F36's schema.
abstract interface class SavedAudioPlayer {
  /// Decrypts the audio saved under [id] and prepares to play it.
  ///
  /// `Ok` carries the audio's full length, which is what makes the second
  /// phase seekable. `Duration.zero` is possible and means the player could
  /// not determine it — a scrubber has nothing to draw, and the reading still
  /// plays.
  ///
  /// An `Err` is the store's own failure for a missing or corrupt file, or
  /// [AudioPlaybackFailure] when the player refuses the audio.
  Future<Result<Duration, AppFailure>> load(String id);

  Future<void> play();

  /// Holds the playback in place. Unlike the streaming phase's pause there is
  /// nothing to accumulate: the whole paper is already on disk.
  Future<void> pause();

  /// Jumps to [position] — the thing this phase exists for.
  Future<void> seek(Duration position);

  /// Stops the playback and releases what it holds, leaving the player able to
  /// [load] again.
  Future<void> stop();

  /// The playback position, as it is played.
  Stream<Duration> get position;

  /// Emits once each time the playback reaches the end of the audio.
  ///
  /// Not `Future<void>`: a finished replay can be seeked back into and will
  /// finish again, so this is a stream of endings rather than one.
  Stream<void> get completions;
}
