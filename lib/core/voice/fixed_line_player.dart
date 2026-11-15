import '../error/app_failure.dart';
import '../result/result.dart';

/// Plays one bundled fixed line (F37-T20).
///
/// Deliberately smaller than [SavedAudioPlayer]: a fixed line has no seek, no
/// position stream and no spans. It starts, and it can be stopped. Everything
/// a screen needs to know about a fixed line is which one it is.
///
/// Implementations are **single-flight**: starting a line stops whichever line
/// is still playing. Two fixed lines overlapping is never useful — it is two
/// messages the user cannot separate.
abstract interface class FixedLinePlayer {
  /// Starts [assetPath] and returns as soon as playback has begun.
  ///
  /// It does **not** wait for the line to finish: a caller that awaited the
  /// audio would be blocked for seconds on a screen that has already drawn.
  /// Returns [AudioPlaybackFailure] when the asset cannot be loaded or the
  /// platform player refuses it.
  Future<Result<void, AppFailure>> play(String assetPath);

  /// Stops the line that is playing, if any. A no-op otherwise.
  Future<void> stop();

  /// Releases the platform player.
  Future<void> dispose();
}
