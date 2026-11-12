import '../../../../core/error/app_failure.dart';
import 'spoken_card_span.dart';
import 'voice_engine.dart';
import 'voice_read_outcome.dart';

/// What the app learns while a paper is being read aloud (F37).
///
/// **Both tiers emit this same union.** Gemini Live and device TTS report
/// nothing alike at the transport level — one sends audio frames and a
/// transcription, the other fires utterance callbacks with character offsets —
/// and the tier that served a given read is a detail no screen should have to
/// branch on. The use case translates both into these events, which is also
/// what gives the fallback tier the same auto-scroll the primary one has.
sealed class VoiceReadEvent {
  const VoiceReadEvent();
}

/// A reading began, on [engine].
///
/// Carried because the tier decides what the UI may offer: only a Live read
/// will produce a file, and so only a Live read ever gains seeking.
final class VoiceReadStarted extends VoiceReadEvent {
  const VoiceReadStarted(this.engine);

  final VoiceEngine engine;

  @override
  bool operator ==(Object other) =>
      other is VoiceReadStarted && other.engine == engine;

  @override
  int get hashCode => engine.hashCode;
}

/// The segment boundaries are now known.
///
/// Emitted once, mid-read, rather than with the final outcome: the screen needs
/// them while the paper is still being spoken, which is the whole point of
/// them. Spans may be interpolated — each says so.
final class VoiceReadSpansResolved extends VoiceReadEvent {
  VoiceReadSpansResolved(List<SpokenCardSpan> spans)
    : spans = List.unmodifiable(spans);

  final List<SpokenCardSpan> spans;

  @override
  String toString() => 'VoiceReadSpansResolved(${spans.length} spans)';
}

/// The reading reached [position], which falls inside [segmentId].
///
/// [segmentId] is `null` before any span covers the position — a gap between
/// segments, or spans not yet resolved — and the screen should hold its current
/// highlight rather than clear it.
///
/// On the Live tier the position comes from what the device has actually
/// *played*, never from how much audio has been received: the stream arrives at
/// roughly twice real time, so counting bytes would run the highlight ahead of
/// the voice by tens of seconds.
final class VoiceReadPositionChanged extends VoiceReadEvent {
  const VoiceReadPositionChanged({required this.position, this.segmentId});

  final Duration position;
  final String? segmentId;

  @override
  bool operator ==(Object other) =>
      other is VoiceReadPositionChanged &&
      other.position == position &&
      other.segmentId == segmentId;

  @override
  int get hashCode => Object.hash(position, segmentId);
}

/// The paper was read to the end.
final class VoiceReadCompleted extends VoiceReadEvent {
  const VoiceReadCompleted(this.outcome);

  final VoiceReadOutcome outcome;

  @override
  String toString() => 'VoiceReadCompleted($outcome)';
}

/// No tier could read the paper.
///
/// Emitted only once every fallback is spent, because a Live failure that
/// device TTS then covers is not something the user should be told about. By
/// the time this arrives the screen has to say something out loud itself, which
/// is why the fixed voice lines are bundled assets rather than spoken by either
/// engine.
final class VoiceReadFailed extends VoiceReadEvent {
  const VoiceReadFailed(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is VoiceReadFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
