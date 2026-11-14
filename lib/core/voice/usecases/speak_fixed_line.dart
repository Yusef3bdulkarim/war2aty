import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../fixed_line_player.dart';
import '../voice_line.dart';

/// Speaks one of the bundled fixed UI lines (F37-T20).
///
/// This is what every screen in the pivot calls to say its own message out
/// loud. It reaches **no** engine: the line is an asset that was generated once
/// and shipped, which is the only way a message about having no connection can
/// be heard by someone with no connection.
///
/// **There is no device-TTS fallback, on purpose.** Falling back would
/// re-introduce the dependency the assets exist to remove, and a missing asset
/// is not a runtime condition to degrade from — `voice_line_test.dart` asserts
/// id ↔ asset parity in both directions, so a line that is absent from the
/// bundle cannot be released. A failure here is therefore a silent no-op from
/// the screen's point of view: it is reported, and the screen carries on.
///
/// **It does not coordinate with a paper being read.** A fixed line and a paper
/// reading are never both wanted, but which one wins is the screen's question,
/// not this use case's — F39 and F40 own that. What this guarantees is that two
/// fixed *lines* never overlap.
final class SpeakFixedLine {
  const SpeakFixedLine(this._player);

  final FixedLinePlayer _player;

  /// Starts [line] and returns once it is playing, not once it has finished.
  Future<Result<void, AppFailure>> call(VoiceLine line) =>
      _player.play(line.assetPath);

  /// Stops the line that is playing, if any.
  ///
  /// A screen calls this when it is left before its line has finished: a
  /// message about the screen the user has just walked away from is worse than
  /// no message.
  Future<void> stop() => _player.stop();
}
