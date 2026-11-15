import 'spoken_card_span.dart';
import 'voice_engine.dart';

/// What a finished reading left behind (F37).
///
/// This is the record a saved paper is built from (F38), so it answers the two
/// questions a later replay actually asks: is there a file to play, and can the
/// reading be trusted.
final class VoiceReadOutcome {
  VoiceReadOutcome({
    required this.engine,
    required this.duration,
    required this.verified,
    required this.audioSaved,
    required List<SpokenCardSpan> spans,
  }) : spans = List.unmodifiable(spans);

  final VoiceEngine engine;
  final Duration duration;

  /// Whether there is reason to believe the audio says what the page says.
  ///
  /// `true` by construction for [VoiceEngine.deviceTts]: the device speaks the
  /// exact string it was handed and has no capacity to reword it. For
  /// [VoiceEngine.geminiLive] it is `true` when the service's transcription of
  /// its own speech matched the source, and `false` in the one case worth
  /// tolerating — a divergence found so late that the user has already heard
  /// the paper, where re-reading costs another 75 seconds and un-hears nothing.
  final bool verified;

  /// Whether an encrypted `.m4a` was written and offline replay will work.
  ///
  /// Not derivable from [engine]: a Live read whose encoder failed also leaves
  /// no file, and the user still heard their paper.
  final bool audioSaved;

  /// Where each segment fell on the audio's timeline, in page order.
  ///
  /// Empty is valid — a read can succeed with nothing aligned. Each span says
  /// whether it was measured or interpolated.
  final List<SpokenCardSpan> spans;

  @override
  String toString() =>
      'VoiceReadOutcome($engine, $duration, verified: $verified, '
      'audioSaved: $audioSaved, ${spans.length} spans)';
}
