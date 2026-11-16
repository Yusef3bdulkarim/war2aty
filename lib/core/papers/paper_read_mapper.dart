import '../../features/voice/domain/entities/spoken_card_span.dart';
import '../../features/voice/domain/entities/voice_engine.dart';
import '../database/app_database.dart';
import '../database/daos/papers_dao.dart';
import 'paper_caution.dart';
import 'paper_contact.dart';
import 'paper_date.dart';
import 'paper_explanation.dart';
import 'paper_place.dart';
import 'paper_todo.dart';
import 'saved_paper.dart';

SavedPaper savedPaperOf(PaperBundle bundle) {
  final row = bundle.paper;

  return SavedPaper(
    id: row.id,
    explanation: PaperExplanation(
      title: row.title,
      status: row.status,
      paragraphs: [for (final paragraph in bundle.paragraphs) paragraph.value],
      todo: PaperTodo(required: row.todoRequired, text: row.todoText),
      date: _dateOf(row),
      caution: row.cautionText == null
          ? null
          : PaperCaution(text: row.cautionText!),
      contact: _contactOf(row),
      place: row.placeText == null ? null : PaperPlace(text: row.placeText!),
    ),
    sessionId: row.sessionId,
    explainSchemaVersion: row.explainSchemaVersion,
    photographedAt: row.photographedAt,
    savedAt: row.savedAt,
    encryptedImagePath: row.encryptedImagePath,
    eventDay: row.eventDay,
    eventMinuteOfDay: row.eventMinuteOfDay,
    voiceEngine: _voiceEngineOf(row.voiceEngine),
    audioSaved: row.audioSaved,
    audioVerified: row.audioVerified,
    audioDurationMs: row.audioDurationMs,
    spans: [for (final span in bundle.spans) _spanOf(span)],
  );
}

PaperDate? _dateOf(PaperRow row) {
  final day = row.dateDay;
  final text = row.dateText;
  if (day == null || text == null) return null;

  return PaperDate(day: day, time: _timeOf(row.dateMinuteOfDay), text: text);
}

PaperContact? _contactOf(PaperRow row) {
  final name = row.contactName;
  final phone = row.contactPhone;
  if (name == null || phone == null) return null;

  return PaperContact(name: name, phone: phone);
}

PaperTime? _timeOf(int? minuteOfDay) => minuteOfDay == null
    ? null
    : PaperTime(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60);

VoiceEngine? _voiceEngineOf(String? raw) {
  if (raw == null) return null;
  for (final engine in VoiceEngine.values) {
    if (engine.name == raw) return engine;
  }
  return null;
}

SpokenCardSpan _spanOf(PaperSpanRow row) => SpokenCardSpan(
  segmentId: row.segmentId,
  start: Duration(milliseconds: row.startMs),
  end: Duration(milliseconds: row.endMs),
  exact: row.exact,
);
