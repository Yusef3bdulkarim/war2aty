import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/paper_tables.dart';

part 'papers_dao.g.dart';

final class PaperBundle {
  const PaperBundle({
    required this.paper,
    this.paragraphs = const [],
    this.spans = const [],
  });

  final PaperRow paper;
  final List<PaperParagraphRow> paragraphs;
  final List<PaperSpanRow> spans;
}

final class PaperWrite {
  const PaperWrite({required this.paper, this.paragraphs = const []});

  final PapersCompanion paper;
  final List<String> paragraphs;
}

@DriftAccessor(tables: [Papers, PaperParagraphs, PaperSpans])
class PapersDao extends DatabaseAccessor<AppDatabase> with _$PapersDaoMixin {
  PapersDao(super.db);

  Future<void> insertPaper(PaperWrite write) {
    return transaction(() async {
      final id = write.paper.id.value;

      await into(papers).insert(write.paper);
      await batch((b) {
        b.insertAll(paperParagraphs, [
          for (var i = 0; i < write.paragraphs.length; i++)
            PaperParagraphsCompanion.insert(
              paperId: id,
              position: i,
              value: write.paragraphs[i],
            ),
        ]);
      });
    });
  }

  Future<void> recordReading({
    required String id,
    String? engine,
    required int? durationMs,
    required bool? verified,
    required bool audioSaved,
    List<PaperSpansCompanion> spans = const [],
  }) {
    return transaction(() async {
      await (update(papers)..where((p) => p.id.equals(id))).write(
        PapersCompanion(
          voiceEngine: Value(engine),
          audioDurationMs: Value(durationMs),
          audioVerified: Value(verified),
          audioSaved: Value(audioSaved),
        ),
      );

      await (delete(paperSpans)..where((s) => s.paperId.equals(id))).go();
      await batch((b) {
        b.insertAll(paperSpans, [
          for (var i = 0; i < spans.length; i++)
            spans[i].copyWith(paperId: Value(id), position: Value(i)),
        ]);
      });
    });
  }

  Stream<List<PaperBundle>> watchPapers() {
    final trigger = customSelect(
      'SELECT 1',
      readsFrom: {papers, paperParagraphs, paperSpans},
    ).watch();
    return trigger.asyncMap((_) => _allPapers());
  }

  Future<PaperBundle?> paperById(String id) {
    return transaction(() async {
      final paper = await (select(
        papers,
      )..where((p) => p.id.equals(id))).getSingleOrNull();
      if (paper == null) return null;

      return PaperBundle(
        paper: paper,
        paragraphs: await _paragraphsOf(id),
        spans: await _spansOf(id),
      );
    });
  }

  Stream<PaperBundle?> watchPaper(String id) {
    final trigger = customSelect(
      'SELECT 1',
      readsFrom: {papers, paperParagraphs, paperSpans},
    ).watch();
    return trigger.asyncMap((_) => paperById(id));
  }

  Future<void> deletePaper(String id) {
    return (delete(papers)..where((p) => p.id.equals(id))).go();
  }

  Future<void> deleteAllPapers() => delete(papers).go();

  Future<List<PaperBundle>> _allPapers() async {
    final rows = await (select(
      papers,
    )..orderBy([(p) => OrderingTerm.desc(p.savedAt)])).get();

    final bundles = <PaperBundle>[];
    for (final row in rows) {
      bundles.add(
        PaperBundle(
          paper: row,
          paragraphs: await _paragraphsOf(row.id),
          spans: await _spansOf(row.id),
        ),
      );
    }
    return bundles;
  }

  Future<List<PaperParagraphRow>> _paragraphsOf(String id) {
    final query = select(paperParagraphs)
      ..where((t) => t.paperId.equals(id))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return query.get();
  }

  Future<List<PaperSpanRow>> _spansOf(String id) {
    final query = select(paperSpans)
      ..where((t) => t.paperId.equals(id))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return query.get();
  }
}
