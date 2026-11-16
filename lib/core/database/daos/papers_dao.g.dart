// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'papers_dao.dart';

// ignore_for_file: type=lint
mixin _$PapersDaoMixin on DatabaseAccessor<AppDatabase> {
  $PapersTable get papers => attachedDatabase.papers;
  $PaperParagraphsTable get paperParagraphs => attachedDatabase.paperParagraphs;
  $PaperSpansTable get paperSpans => attachedDatabase.paperSpans;
  PapersDaoManager get managers => PapersDaoManager(this);
}

class PapersDaoManager {
  final _$PapersDaoMixin _db;
  PapersDaoManager(this._db);
  $$PapersTableTableManager get papers =>
      $$PapersTableTableManager(_db.attachedDatabase, _db.papers);
  $$PaperParagraphsTableTableManager get paperParagraphs =>
      $$PaperParagraphsTableTableManager(
        _db.attachedDatabase,
        _db.paperParagraphs,
      );
  $$PaperSpansTableTableManager get paperSpans =>
      $$PaperSpansTableTableManager(_db.attachedDatabase, _db.paperSpans);
}
