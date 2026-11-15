import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/database/daos/papers_dao.dart';
import 'package:war2aty/core/papers/paper_read_mapper.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/features/voice/domain/entities/voice_engine.dart';

void main() {
  PaperRow row({
    String id = 'p1',
    String title = 'فاتورة كهرباء',
    PaperStatus status = PaperStatus.success,
    DateTime? dateDay,
    int? dateMinuteOfDay,
    String? dateText,
    String? cautionText,
    String? contactName,
    String? contactPhone,
    String? placeText,
    String? voiceEngine,
    bool audioSaved = false,
    bool? audioVerified,
    int? audioDurationMs,
  }) {
    final at = DateTime(2026, 11, 16, 10);
    return PaperRow(
      id: id,
      title: title,
      status: status,
      todoRequired: true,
      todoText: 'روح لأقرب فرع',
      dateDay: dateDay,
      dateMinuteOfDay: dateMinuteOfDay,
      dateText: dateText,
      cautionText: cautionText,
      contactName: contactName,
      contactPhone: contactPhone,
      placeText: placeText,
      photographedAt: at,
      savedAt: at,
      eventDay: dateDay,
      eventMinuteOfDay: dateMinuteOfDay,
      sessionId: 'session-1',
      explainSchemaVersion: '1.0',
      voiceEngine: voiceEngine,
      audioSaved: audioSaved,
      audioVerified: audioVerified,
      audioDurationMs: audioDurationMs,
    );
  }

  test('carries the header, the two required cards and the timestamps', () {
    final paper = savedPaperOf(
      PaperBundle(
        paper: row(),
        paragraphs: const [
          PaperParagraphRow(paperId: 'p1', position: 0, value: 'الأولى'),
          PaperParagraphRow(paperId: 'p1', position: 1, value: 'الثانية'),
        ],
      ),
    );

    expect(paper.id, 'p1');
    expect(paper.explanation.title, 'فاتورة كهرباء');
    expect(paper.explanation.status, PaperStatus.success);
    expect(paper.explanation.paragraphs, ['الأولى', 'الثانية']);
    expect(paper.explanation.todo.required, isTrue);
    expect(paper.explanation.todo.text, 'روح لأقرب فرع');
    expect(paper.sessionId, 'session-1');
    expect(paper.explainSchemaVersion, '1.0');
  });

  test('a paper with only the two required cards has every optional null', () {
    final paper = savedPaperOf(PaperBundle(paper: row()));

    expect(paper.explanation.date, isNull);
    expect(paper.explanation.caution, isNull);
    expect(paper.explanation.contact, isNull);
    expect(paper.explanation.place, isNull);
  });

  test('reads the date card with a time of day', () {
    final paper = savedPaperOf(
      PaperBundle(
        paper: row(
          dateDay: DateTime(2026, 11, 20),
          dateMinuteOfDay: 570,
          dateText: '20 نوفمبر',
        ),
      ),
    );

    expect(paper.explanation.date!.day, DateTime(2026, 11, 20));
    expect(paper.explanation.date!.time!.hour, 9);
    expect(paper.explanation.date!.time!.minute, 30);
    expect(paper.explanation.date!.text, '20 نوفمبر');
  });

  test('reads a date with no time as absent rather than midnight', () {
    final paper = savedPaperOf(
      PaperBundle(
        paper: row(dateDay: DateTime(2026, 11, 20), dateText: '20 نوفمبر'),
      ),
    );

    expect(paper.explanation.date!.time, isNull);
  });

  test('reads the caution, contact and place cards', () {
    final paper = savedPaperOf(
      PaperBundle(
        paper: row(
          cautionText: 'خد بالك من الغرامة',
          contactName: 'مكتب الشهر العقاري',
          contactPhone: '0223456789',
          placeText: 'مصلحة الضرائب',
        ),
      ),
    );

    expect(paper.explanation.caution!.text, 'خد بالك من الغرامة');
    expect(paper.explanation.contact!.name, 'مكتب الشهر العقاري');
    expect(paper.explanation.contact!.phone, '0223456789');
    expect(paper.explanation.place!.text, 'مصلحة الضرائب');
  });

  test('a contact needs both a name and a phone to count as one', () {
    final paper = savedPaperOf(
      PaperBundle(paper: row(contactName: 'مكتب الشهر العقاري')),
    );

    expect(paper.explanation.contact, isNull);
  });

  test('reads the voice engine back by name', () {
    final paper = savedPaperOf(
      PaperBundle(paper: row(voiceEngine: 'geminiLive')),
    );

    expect(paper.voiceEngine, VoiceEngine.geminiLive);
  });

  test('degrades an unparsable voice engine to null rather than throwing', () {
    final paper = savedPaperOf(
      PaperBundle(paper: row(voiceEngine: 'some-future-engine')),
    );

    expect(paper.voiceEngine, isNull);
  });

  test('a null stored voice engine stays null', () {
    final paper = savedPaperOf(PaperBundle(paper: row()));

    expect(paper.voiceEngine, isNull);
  });

  test('reads the spans in order with exact intact', () {
    final paper = savedPaperOf(
      PaperBundle(
        paper: row(voiceEngine: 'geminiLive', audioSaved: true),
        spans: const [
          PaperSpanRow(
            paperId: 'p1',
            position: 0,
            segmentId: 'explain',
            startMs: 0,
            endMs: 4000,
            exact: true,
          ),
          PaperSpanRow(
            paperId: 'p1',
            position: 1,
            segmentId: 'todo',
            startMs: 4000,
            endMs: 8000,
            exact: false,
          ),
        ],
      ),
    );

    expect(paper.spans.map((s) => s.segmentId), ['explain', 'todo']);
    expect(paper.spans[0].start, Duration.zero);
    expect(paper.spans[0].end, const Duration(seconds: 4));
    expect(paper.spans[0].exact, isTrue);
    expect(paper.spans[1].exact, isFalse);
  });

  test('carries the voice bookkeeping fields across', () {
    final paper = savedPaperOf(
      PaperBundle(
        paper: row(
          voiceEngine: 'deviceTts',
          audioVerified: true,
          audioDurationMs: 60000,
        ),
      ),
    );

    expect(paper.voiceEngine, VoiceEngine.deviceTts);
    expect(paper.audioSaved, isFalse);
    expect(paper.audioVerified, isTrue);
    expect(paper.audioDurationMs, 60000);
  });
}
