import '../../features/voice/domain/entities/spoken_card_span.dart';
import '../../features/voice/domain/entities/voice_engine.dart';
import '../utils/list_equality.dart';
import 'paper_explanation.dart';

final class SavedPaper {
  SavedPaper({
    required this.id,
    required this.explanation,
    required this.sessionId,
    required this.explainSchemaVersion,
    required this.photographedAt,
    required this.savedAt,
    this.encryptedImagePath,
    this.eventDay,
    this.eventMinuteOfDay,
    this.voiceEngine,
    this.audioSaved = false,
    this.audioVerified,
    this.audioDurationMs,
    List<SpokenCardSpan> spans = const [],
  }) : spans = List.unmodifiable(spans);

  final String id;
  final PaperExplanation explanation;
  final String sessionId;
  final String explainSchemaVersion;
  final DateTime photographedAt;
  final DateTime savedAt;
  final String? encryptedImagePath;
  final DateTime? eventDay;
  final int? eventMinuteOfDay;
  final VoiceEngine? voiceEngine;
  final bool audioSaved;
  final bool? audioVerified;
  final int? audioDurationMs;
  final List<SpokenCardSpan> spans;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedPaper &&
          other.id == id &&
          other.explanation == explanation &&
          other.sessionId == sessionId &&
          other.explainSchemaVersion == explainSchemaVersion &&
          other.photographedAt == photographedAt &&
          other.savedAt == savedAt &&
          other.encryptedImagePath == encryptedImagePath &&
          other.eventDay == eventDay &&
          other.eventMinuteOfDay == eventMinuteOfDay &&
          other.voiceEngine == voiceEngine &&
          other.audioSaved == audioSaved &&
          other.audioVerified == audioVerified &&
          other.audioDurationMs == audioDurationMs &&
          listEquals(other.spans, spans);

  @override
  int get hashCode => Object.hash(
    id,
    explanation,
    sessionId,
    explainSchemaVersion,
    photographedAt,
    savedAt,
    encryptedImagePath,
    eventDay,
    eventMinuteOfDay,
    voiceEngine,
    audioSaved,
    audioVerified,
    audioDurationMs,
    Object.hashAll(spans),
  );

  @override
  String toString() =>
      'SavedPaper($id, ${explanation.status}, engine: $voiceEngine, '
      'audioSaved: $audioSaved, ${spans.length} spans)';
}
