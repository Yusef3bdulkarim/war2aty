import '../../features/voice/domain/entities/spoken_card_span.dart';
import '../../features/voice/domain/entities/voice_engine.dart';
import '../../features/voice/domain/entities/voice_read_outcome.dart';
import '../error/app_failure.dart';
import '../utils/list_equality.dart';

/// What the voice is doing with a paper (F37-T19).
///
/// The spine has **two phases**, and they are not the same player with a
/// different flag on it:
///
/// * [VoicePlaybackStreaming] — the paper is being spoken as it arrives. There
///   is no file and no known length, so there is nothing to seek *to*: the
///   user hears it from the top (D7). Whether it can even be held is the
///   tier's answer, not the screen's — see [VoiceEngine.canPauseMidRead].
/// * [VoicePlaybackFile] — the saved `.m4a` is being replayed. The whole
///   reading is on the phone, so the length is known and any position can be
///   jumped to, including the start of a card.
///
/// **No state carries a service**, a session, a player or a stream: a screen
/// gets positions, spans, two booleans and a failure, and asks the cubit for
/// everything else (CLAUDE.md §B2).
sealed class VoicePlaybackState {
  const VoicePlaybackState();

  /// Whether the user may jump to a position — or to a card — in what is
  /// playing. True only in the second phase.
  bool get canSeek => false;

  /// Whether what is playing can be held and continued. False where there is
  /// nothing playing, and false on a tier that cannot resume where it stopped.
  bool get canPause => false;

  /// Whether a voice is speaking right now — false while paused, and false
  /// before a tier has answered.
  bool get isSpeaking => false;
}

/// Nothing is being read or replayed.
final class VoicePlaybackIdle extends VoicePlaybackState {
  const VoicePlaybackIdle();

  @override
  bool operator ==(Object other) => other is VoicePlaybackIdle;

  @override
  int get hashCode => (VoicePlaybackIdle).hashCode;
}

/// A read or a replay was asked for and no engine has answered yet.
///
/// Its own state rather than an early [VoicePlaybackStreaming]: the tier is
/// not known yet, which means neither is whether a pause can be offered, and a
/// screen that showed a pause button here would have to take it away again.
/// Reaching the first word takes about a second on Live (F36) and the device
/// engine's own start-up on the fallback tier — long enough that saying
/// nothing would look like nothing happened.
final class VoicePlaybackPreparing extends VoicePlaybackState {
  const VoicePlaybackPreparing();

  @override
  bool operator ==(Object other) => other is VoicePlaybackPreparing;

  @override
  int get hashCode => (VoicePlaybackPreparing).hashCode;
}

/// Phase one: the paper is being spoken as it arrives, on [engine].
///
/// [segmentId] is the card to highlight: the last one a position actually
/// landed in, held through the gaps between cards rather than cleared, which
/// is what a position event carrying `null` asks for. `null` here means no
/// position has landed in any card yet — before the spans resolve, mid-read,
/// there is nothing to highlight.
final class VoicePlaybackStreaming extends VoicePlaybackState {
  const VoicePlaybackStreaming({
    required this.engine,
    this.position = Duration.zero,
    this.segmentId,
    this.spans = const [],
    this.isPaused = false,
  });

  final VoiceEngine engine;
  final Duration position;
  final String? segmentId;

  /// Where each card falls on the reading's timeline — empty until they
  /// resolve, which on the Live tier is about halfway through what the user
  /// hears, and on the device tier at the very end (T07, T18).
  final List<SpokenCardSpan> spans;

  final bool isPaused;

  /// Never, in this phase. The audio is still arriving and the service cannot
  /// replay a partial turn, so there is no position to jump to (D7).
  @override
  bool get canSeek => false;

  @override
  bool get canPause => engine.canPauseMidRead;

  @override
  bool get isSpeaking => !isPaused;

  VoicePlaybackStreaming copyWith({
    Duration? position,
    String? segmentId,
    List<SpokenCardSpan>? spans,
    bool? isPaused,
  }) => VoicePlaybackStreaming(
    engine: engine,
    position: position ?? this.position,
    segmentId: segmentId ?? this.segmentId,
    spans: spans ?? this.spans,
    isPaused: isPaused ?? this.isPaused,
  );

  @override
  bool operator ==(Object other) =>
      other is VoicePlaybackStreaming &&
      other.engine == engine &&
      other.position == position &&
      other.segmentId == segmentId &&
      other.isPaused == isPaused &&
      listEquals(other.spans, spans);

  @override
  int get hashCode =>
      Object.hash(engine, position, segmentId, isPaused, spans.length);

  @override
  String toString() =>
      'VoicePlaybackStreaming($engine, $position, $segmentId, '
      '${spans.length} spans, paused: $isPaused)';
}

/// The read is over and the paper was heard to the end.
///
/// Not [VoicePlaybackIdle], because what is left behind decides what the
/// screen may offer next: [canReplay] is the difference between a paper that
/// plays again for free, offline, and one that would cost the service another
/// reading.
final class VoicePlaybackReadFinished extends VoicePlaybackState {
  const VoicePlaybackReadFinished(this.outcome);

  final VoiceReadOutcome outcome;

  /// Whether the reading can be replayed from the phone.
  ///
  /// False for a device-TTS read, which saves nothing, and false for a Live
  /// read whose encoder or store failed — the user heard their paper either
  /// way, which is why this is not derivable from the engine alone.
  bool get canReplay => outcome.audioSaved;

  @override
  bool operator ==(Object other) =>
      other is VoicePlaybackReadFinished && other.outcome == outcome;

  @override
  int get hashCode => outcome.hashCode;

  @override
  String toString() => 'VoicePlaybackReadFinished($outcome)';
}

/// Phase two: the saved reading is being replayed, with full seek.
///
/// A finished replay stays in this phase with [isPaused] true and [position]
/// at [duration] — the audio is still loaded, and the point of the phase is
/// that the user can drag back into it.
final class VoicePlaybackFile extends VoicePlaybackState {
  const VoicePlaybackFile({
    required this.duration,
    this.position = Duration.zero,
    this.segmentId,
    this.spans = const [],
    this.isPaused = false,
  });

  /// The reading's full length. [Duration.zero] means the player could not
  /// determine it: the paper plays, and a scrubber has nothing to draw.
  final Duration duration;

  final Duration position;
  final String? segmentId;

  /// Where each card falls — measured when the paper was read, and handed in
  /// with the replay. Empty is valid, and means no card can be jumped to.
  final List<SpokenCardSpan> spans;

  final bool isPaused;

  @override
  bool get canSeek => true;

  @override
  bool get canPause => true;

  @override
  bool get isSpeaking => !isPaused;

  VoicePlaybackFile copyWith({
    Duration? position,
    String? segmentId,
    List<SpokenCardSpan>? spans,
    bool? isPaused,
  }) => VoicePlaybackFile(
    duration: duration,
    position: position ?? this.position,
    segmentId: segmentId ?? this.segmentId,
    spans: spans ?? this.spans,
    isPaused: isPaused ?? this.isPaused,
  );

  @override
  bool operator ==(Object other) =>
      other is VoicePlaybackFile &&
      other.duration == duration &&
      other.position == position &&
      other.segmentId == segmentId &&
      other.isPaused == isPaused &&
      listEquals(other.spans, spans);

  @override
  int get hashCode =>
      Object.hash(duration, position, segmentId, isPaused, spans.length);

  @override
  String toString() =>
      'VoicePlaybackFile($position/$duration, $segmentId, '
      '${spans.length} spans, paused: $isPaused)';
}

/// The paper could not be read, or the saved reading could not be replayed.
///
/// Carries the failure rather than a sentence: the Arabic is the screen's to
/// pick (CLAUDE.md §B5), and on this pivot the screen also has to *say* it out
/// loud — from the bundled fixed lines (T20), never from an engine that has
/// just proved it cannot be reached.
final class VoicePlaybackFailed extends VoicePlaybackState {
  const VoicePlaybackFailed(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is VoicePlaybackFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'VoicePlaybackFailed($failure)';
}
