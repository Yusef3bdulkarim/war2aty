import '../../../../core/papers/build_paper_voice_segments.dart';
import '../../../../core/papers/saved_paper.dart';
import '../../../../core/utils/list_equality.dart';
import '../../../voice/domain/entities/spoken_card_span.dart';
import '../../../voice/domain/entities/voice_segment.dart';

sealed class PaperVoiceStart {
  const PaperVoiceStart();

  factory PaperVoiceStart.of(SavedPaper paper, {required bool fresh}) {
    if (!fresh && paper.audioSaved) {
      return ReplaySavedReading(audioId: paper.id, spans: paper.spans);
    }
    return ReadPaperAloudFromStart(
      audioId: paper.id,
      segments: const BuildPaperVoiceSegments()(paper.explanation),
    );
  }
}

final class ReadPaperAloudFromStart extends PaperVoiceStart {
  const ReadPaperAloudFromStart({
    required this.audioId,
    required this.segments,
  });

  final String audioId;
  final List<VoiceSegment> segments;

  @override
  bool operator ==(Object other) =>
      other is ReadPaperAloudFromStart &&
      other.audioId == audioId &&
      listEquals(other.segments, segments);

  @override
  int get hashCode => Object.hash(audioId, Object.hashAll(segments));

  @override
  String toString() =>
      'ReadPaperAloudFromStart($audioId, ${segments.length} segments)';
}

final class ReplaySavedReading extends PaperVoiceStart {
  const ReplaySavedReading({required this.audioId, required this.spans});

  final String audioId;
  final List<SpokenCardSpan> spans;

  @override
  bool operator ==(Object other) =>
      other is ReplaySavedReading &&
      other.audioId == audioId &&
      listEquals(other.spans, spans);

  @override
  int get hashCode => Object.hash(audioId, Object.hashAll(spans));

  @override
  String toString() => 'ReplaySavedReading($audioId, ${spans.length} spans)';
}
