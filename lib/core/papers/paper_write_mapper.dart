import 'package:drift/drift.dart';

import '../../features/voice/domain/entities/spoken_card_span.dart';
import '../database/app_database.dart';
import '../database/daos/papers_dao.dart';
import 'explain_outcome.dart';

PaperWrite paperWriteOf({
  required String id,
  required ExplainOutcome outcome,
  required DateTime photographedAt,
  required DateTime savedAt,
  String? encryptedImagePath,
}) {
  final explanation = outcome.explanation;
  final date = explanation.date;

  return PaperWrite(
    paper: PapersCompanion.insert(
      id: id,
      title: explanation.title,
      status: explanation.status,
      todoRequired: explanation.todo.required,
      todoText: explanation.todo.text,
      dateDay: Value(date?.day),
      dateMinuteOfDay: Value(date?.minuteOfDay),
      dateText: Value(date?.text),
      cautionText: Value(explanation.caution?.text),
      contactName: Value(explanation.contact?.name),
      contactPhone: Value(explanation.contact?.phone),
      placeText: Value(explanation.place?.text),
      photographedAt: photographedAt,
      savedAt: savedAt,
      encryptedImagePath: encryptedImagePath == null
          ? const Value.absent()
          : Value(encryptedImagePath),
      eventDay: Value(date?.day),
      eventMinuteOfDay: Value(date?.minuteOfDay),
      sessionId: outcome.sessionId,
      explainSchemaVersion: outcome.explainSchemaVersion,
    ),
    paragraphs: explanation.paragraphs,
  );
}

List<PaperSpansCompanion> paperSpansOf(
  String paperId,
  List<SpokenCardSpan> spans,
) {
  return [
    for (final span in spans)
      PaperSpansCompanion.insert(
        paperId: paperId,
        position: 0,
        segmentId: span.segmentId,
        startMs: span.start.inMilliseconds,
        endMs: span.end.inMilliseconds,
        exact: span.exact,
      ),
  ];
}
