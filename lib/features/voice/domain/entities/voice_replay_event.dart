import '../../../../core/error/app_failure.dart';

/// What the app learns while a saved reading is replayed (F37-T19).
///
/// Deliberately **not** `VoiceReadEvent`. A replay is not a read: nothing is
/// being spoken for the first time, no engine is chosen, nothing is verified
/// and nothing is saved — so `VoiceReadStarted`'s engine and
/// `VoiceReadOutcome`'s `verified` / `audioSaved` would all have to be
/// answered with something invented. The two unions share only the question
/// "where has it reached", and that one answer is cheaper to repeat than a
/// shape that lies.
sealed class VoiceReplayEvent {
  const VoiceReplayEvent();
}

/// The audio is loaded and playing, and runs for [duration].
///
/// The first event of every replay, and the one that makes the phase seekable:
/// a scrubber cannot be drawn without a length. [Duration.zero] means the
/// player could not determine it — the reading still plays.
final class VoiceReplayReady extends VoiceReplayEvent {
  const VoiceReplayReady(this.duration);

  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is VoiceReplayReady && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  String toString() => 'VoiceReplayReady($duration)';
}

/// The replay reached [position], which falls inside [segmentId].
///
/// [segmentId] is `null` where no span covers the position, and the screen
/// holds the highlight it has rather than clearing it — the same contract
/// `VoiceReadPositionChanged` carries, for the same reason.
final class VoiceReplayPositionChanged extends VoiceReplayEvent {
  const VoiceReplayPositionChanged({required this.position, this.segmentId});

  final Duration position;
  final String? segmentId;

  @override
  bool operator ==(Object other) =>
      other is VoiceReplayPositionChanged &&
      other.position == position &&
      other.segmentId == segmentId;

  @override
  int get hashCode => Object.hash(position, segmentId);

  @override
  String toString() => 'VoiceReplayPositionChanged($position, $segmentId)';
}

/// The replay reached the end of the audio.
///
/// Not the end of the replay: the audio is still loaded and can be seeked back
/// into, which is why this can arrive more than once.
final class VoiceReplayFinished extends VoiceReplayEvent {
  const VoiceReplayFinished();

  @override
  bool operator ==(Object other) => other is VoiceReplayFinished;

  @override
  int get hashCode => (VoiceReplayFinished).hashCode;

  @override
  String toString() => 'VoiceReplayFinished()';
}

/// The saved reading could not be replayed.
///
/// There is no fallback to fall to: the audio is either on this phone or it is
/// not, and re-reading the paper is a decision for the screen (and costs the
/// service a session), not for a replay.
final class VoiceReplayFailed extends VoiceReplayEvent {
  const VoiceReplayFailed(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is VoiceReplayFailed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'VoiceReplayFailed($failure)';
}
