import 'package:drift/drift.dart';

import '../../papers/paper_status.dart';

@DataClassName('PaperRow')
@TableIndex(name: 'papers_event_day', columns: {#eventDay, #eventMinuteOfDay})
class Papers extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();
  TextColumn get status => textEnum<PaperStatus>()();

  BoolColumn get todoRequired => boolean()();
  TextColumn get todoText => text()();

  DateTimeColumn get dateDay => dateTime().nullable()();
  IntColumn get dateMinuteOfDay => integer().nullable()();
  TextColumn get dateText => text().nullable()();

  TextColumn get cautionText => text().nullable()();

  TextColumn get contactName => text().nullable()();
  TextColumn get contactPhone => text().nullable()();

  TextColumn get placeText => text().nullable()();

  DateTimeColumn get photographedAt => dateTime()();
  DateTimeColumn get savedAt => dateTime()();
  TextColumn get encryptedImagePath => text().nullable()();

  DateTimeColumn get eventDay => dateTime().nullable()();
  IntColumn get eventMinuteOfDay => integer().nullable()();

  TextColumn get sessionId => text()();
  TextColumn get explainSchemaVersion => text()();

  TextColumn get voiceEngine => text().nullable()();
  BoolColumn get audioSaved => boolean().withDefault(const Constant(false))();
  BoolColumn get audioVerified => boolean().nullable()();
  IntColumn get audioDurationMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PaperParagraphRow')
class PaperParagraphs extends Table {
  TextColumn get paperId =>
      text().references(Papers, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {paperId, position};
}

@DataClassName('PaperSpanRow')
class PaperSpans extends Table {
  TextColumn get paperId =>
      text().references(Papers, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  TextColumn get segmentId => text()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  BoolColumn get exact => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {paperId, position};
}
