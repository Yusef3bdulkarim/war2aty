import '../../../../core/voice/voice_playback_state.dart';
import '../../../voice/domain/entities/spoken_card_span.dart';

final class PaperVoiceProgress {
  const PaperVoiceProgress({this.activeId, this.fillFraction = 0});

  factory PaperVoiceProgress.of(VoicePlaybackState state) => switch (state) {
    VoicePlaybackStreaming(:final segmentId, :final spans, :final position) =>
      PaperVoiceProgress._within(segmentId, spans, position),
    VoicePlaybackFile(:final segmentId, :final spans, :final position) =>
      PaperVoiceProgress._within(segmentId, spans, position),
    _ => const PaperVoiceProgress(),
  };

  factory PaperVoiceProgress._within(
    String? segmentId,
    List<SpokenCardSpan> spans,
    Duration position,
  ) {
    if (segmentId == null) return const PaperVoiceProgress();
    for (final span in spans) {
      if (span.segmentId != segmentId) continue;
      final length = span.duration.inMicroseconds;
      if (length <= 0) return PaperVoiceProgress(activeId: segmentId);
      final elapsed = (position - span.start).inMicroseconds;
      return PaperVoiceProgress(
        activeId: segmentId,
        fillFraction: (elapsed / length).clamp(0.0, 1.0),
      );
    }
    return PaperVoiceProgress(activeId: segmentId);
  }

  final String? activeId;
  final double fillFraction;

  @override
  bool operator ==(Object other) =>
      other is PaperVoiceProgress &&
      other.activeId == activeId &&
      other.fillFraction == fillFraction;

  @override
  int get hashCode => Object.hash(activeId, fillFraction);

  @override
  String toString() => 'PaperVoiceProgress($activeId, $fillFraction)';
}
