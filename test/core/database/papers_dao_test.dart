import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/database/daos/papers_dao.dart';
import 'package:war2aty/core/papers/paper_status.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late PapersDao dao;

  setUp(() {
    db = memoryDatabase();
    dao = db.papersDao;
  });
  tearDown(() => db.close());

  group('insertPaper', () {
    test('round-trips a paper with no paragraphs', () async {
      await dao.insertPaper(PaperWrite(paper: _paper('p1')));

      final bundle = await dao.paperById('p1');

      expect(bundle, isNotNull);
      expect(bundle!.paper.title, 'فاتورة كهرباء');
      expect(bundle.paper.status, PaperStatus.success);
      expect(bundle.paragraphs, isEmpty);
      expect(bundle.spans, isEmpty);
    });

    test('keeps paragraphs in order', () async {
      await dao.insertPaper(
        PaperWrite(paper: _paper('p1'), paragraphs: ['الأولى', 'الثانية']),
      );

      final bundle = await dao.paperById('p1');

      expect(bundle!.paragraphs.map((p) => p.value), ['الأولى', 'الثانية']);
      expect(bundle.paragraphs.map((p) => p.position), [0, 1]);
    });

    test('round-trips a paper with every optional card', () async {
      await dao.insertPaper(
        PaperWrite(
          paper: _paper(
            'p1',
            dateDay: DateTime(2026, 11, 20),
            dateMinuteOfDay: 570,
            dateText: '20 نوفمبر',
          ),
        ),
      );

      final bundle = await dao.paperById('p1');

      expect(bundle!.paper.dateDay, DateTime(2026, 11, 20));
      expect(bundle.paper.dateMinuteOfDay, 570);
      expect(bundle.paper.dateText, '20 نوفمبر');
    });

    test('stores a date with no time as absent rather than midnight', () async {
      await dao.insertPaper(
        PaperWrite(
          paper: _paper(
            'p1',
            dateDay: DateTime(2026, 11, 20),
            dateText: '20 نوفمبر',
          ),
        ),
      );

      final bundle = await dao.paperById('p1');

      expect(bundle!.paper.dateMinuteOfDay, isNull);
    });
  });

  group('paperById', () {
    test('returns null for an unknown id', () async {
      expect(await dao.paperById('nope'), isNull);
    });
  });

  group('watchPapers', () {
    test('emits the newest paper first', () async {
      await dao.insertPaper(
        PaperWrite(paper: _paper('old', savedAt: DateTime(2026, 7, 5))),
      );
      await dao.insertPaper(
        PaperWrite(paper: _paper('new', savedAt: DateTime(2026, 7, 20))),
      );

      final bundles = await dao.watchPapers().first;

      expect(bundles.map((b) => b.paper.id), ['new', 'old']);
    });

    test('carries each paper\'s own paragraphs', () async {
      await dao.insertPaper(
        PaperWrite(paper: _paper('p1'), paragraphs: ['نص الورقة الأولى']),
      );
      await dao.insertPaper(
        PaperWrite(
          paper: _paper('p2', savedAt: DateTime(2026, 7, 30)),
          paragraphs: ['نص الورقة الثانية'],
        ),
      );

      final bundles = await dao.watchPapers().first;

      expect(bundles[0].paragraphs.single.value, 'نص الورقة الثانية');
      expect(bundles[1].paragraphs.single.value, 'نص الورقة الأولى');
    });

    test('re-emits when a paper is saved', () async {
      final counts = <int>[];
      final sub = dao.watchPapers().listen((rows) => counts.add(rows.length));
      await pumpEventQueue();

      await dao.insertPaper(PaperWrite(paper: _paper('p1')));
      await pumpEventQueue();
      await sub.cancel();

      expect(counts, [0, 1]);
    });
  });

  group('watchPaper', () {
    test('re-emits when the paper\'s spans change', () async {
      await dao.insertPaper(PaperWrite(paper: _paper('p1')));

      final counts = <int?>[];
      final sub = dao
          .watchPaper('p1')
          .listen((bundle) => counts.add(bundle?.spans.length));
      await pumpEventQueue();

      await dao.recordReading(
        id: 'p1',
        engine: 'geminiLive',
        durationMs: 12000,
        verified: true,
        audioSaved: true,
        spans: [_span('explain', 0, 2000)],
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(counts, [0, 1]);
    });

    test('emits null once the paper is deleted', () async {
      await dao.insertPaper(PaperWrite(paper: _paper('p1')));

      final ids = <String?>[];
      final sub = dao
          .watchPaper('p1')
          .listen((bundle) => ids.add(bundle?.paper.id));
      await pumpEventQueue();

      await dao.deletePaper('p1');
      await pumpEventQueue();
      await sub.cancel();

      expect(ids, ['p1', null]);
    });
  });

  group('recordReading', () {
    test('writes the engine, duration, verified and audioSaved', () async {
      await dao.insertPaper(PaperWrite(paper: _paper('p1')));

      await dao.recordReading(
        id: 'p1',
        engine: 'geminiLive',
        durationMs: 75000,
        verified: true,
        audioSaved: true,
      );

      final bundle = await dao.paperById('p1');

      expect(bundle!.paper.voiceEngine, 'geminiLive');
      expect(bundle.paper.audioDurationMs, 75000);
      expect(bundle.paper.audioVerified, isTrue);
      expect(bundle.paper.audioSaved, isTrue);
    });

    test('stores a device-TTS reading with audioSaved false', () async {
      await dao.insertPaper(PaperWrite(paper: _paper('p1')));

      await dao.recordReading(
        id: 'p1',
        engine: 'deviceTts',
        durationMs: 60000,
        verified: true,
        audioSaved: false,
      );

      final bundle = await dao.paperById('p1');

      expect(bundle!.paper.voiceEngine, 'deviceTts');
      expect(bundle.paper.audioSaved, isFalse);
    });

    test('writes the spans in order with exact intact', () async {
      await dao.insertPaper(PaperWrite(paper: _paper('p1')));

      await dao.recordReading(
        id: 'p1',
        engine: 'geminiLive',
        durationMs: 10000,
        verified: true,
        audioSaved: true,
        spans: [
          _span('explain', 0, 4000),
          _span('todo', 4000, 8000, exact: false),
        ],
      );

      final bundle = await dao.paperById('p1');

      expect(bundle!.spans.map((s) => s.segmentId), ['explain', 'todo']);
      expect(bundle.spans.map((s) => s.position), [0, 1]);
      expect(bundle.spans[0].exact, isTrue);
      expect(bundle.spans[1].exact, isFalse);
      expect(bundle.spans[1].startMs, 4000);
      expect(bundle.spans[1].endMs, 8000);
    });

    test(
      'replaces a previous reading\'s spans rather than keeping both',
      () async {
        await dao.insertPaper(PaperWrite(paper: _paper('p1')));
        await dao.recordReading(
          id: 'p1',
          engine: 'deviceTts',
          durationMs: 5000,
          verified: true,
          audioSaved: false,
          spans: [_span('explain', 0, 1000)],
        );

        await dao.recordReading(
          id: 'p1',
          engine: 'geminiLive',
          durationMs: 9000,
          verified: true,
          audioSaved: true,
          spans: [_span('explain', 0, 2000), _span('todo', 2000, 4000)],
        );

        final bundle = await dao.paperById('p1');

        expect(bundle!.spans, hasLength(2));
        expect(bundle.spans[0].endMs, 2000);
      },
    );
  });

  group('deletePaper', () {
    test('takes its paragraphs and spans with it', () async {
      await dao.insertPaper(
        PaperWrite(paper: _paper('p1'), paragraphs: ['نص']),
      );
      await dao.recordReading(
        id: 'p1',
        engine: 'geminiLive',
        durationMs: 2000,
        verified: true,
        audioSaved: true,
        spans: [_span('explain', 0, 2000)],
      );

      await dao.deletePaper('p1');

      expect(await dao.paperById('p1'), isNull);
      expect(await db.select(db.paperParagraphs).get(), isEmpty);
      expect(await db.select(db.paperSpans).get(), isEmpty);
    });

    test('leaves other papers alone', () async {
      await dao.insertPaper(
        PaperWrite(paper: _paper('p1'), paragraphs: ['أول']),
      );
      await dao.insertPaper(
        PaperWrite(
          paper: _paper('p2', savedAt: DateTime(2026, 7, 30)),
          paragraphs: ['ثاني'],
        ),
      );

      await dao.deletePaper('p1');

      final kept = await dao.paperById('p2');
      expect(kept!.paragraphs.single.value, 'ثاني');
    });
  });

  test('deleteAllPapers empties the table', () async {
    await dao.insertPaper(PaperWrite(paper: _paper('p1')));
    await dao.insertPaper(
      PaperWrite(paper: _paper('p2', savedAt: DateTime(2026, 7, 30))),
    );

    await dao.deleteAllPapers();

    expect(await dao.paperById('p1'), isNull);
    expect(await dao.paperById('p2'), isNull);
  });
}

PapersCompanion _paper(
  String id, {
  String title = 'فاتورة كهرباء',
  PaperStatus status = PaperStatus.success,
  DateTime? savedAt,
  DateTime? dateDay,
  int? dateMinuteOfDay,
  String? dateText,
}) {
  final at = savedAt ?? DateTime(2026, 7, 29);
  return PapersCompanion.insert(
    id: id,
    title: title,
    status: status,
    todoRequired: true,
    todoText: 'روح لأقرب فرع',
    dateDay: Value(dateDay),
    dateMinuteOfDay: Value(dateMinuteOfDay),
    dateText: Value(dateText),
    photographedAt: at,
    savedAt: at,
    eventDay: Value(dateDay),
    eventMinuteOfDay: Value(dateMinuteOfDay),
    sessionId: 'session-1',
    explainSchemaVersion: '1.0',
  );
}

PaperSpansCompanion _span(
  String segmentId,
  int startMs,
  int endMs, {
  bool exact = true,
}) {
  return PaperSpansCompanion.insert(
    paperId: '',
    position: 0,
    segmentId: segmentId,
    startMs: startMs,
    endMs: endMs,
    exact: exact,
  );
}
