import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/papers/explain_outcome.dart';
import 'package:war2aty/core/papers/paper_caution.dart';
import 'package:war2aty/core/papers/paper_contact.dart';
import 'package:war2aty/core/papers/paper_date.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_place.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';
import 'package:war2aty/core/papers/paper_write_mapper.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';

void main() {
  final photographedAt = DateTime(2026, 11, 16, 9);
  final savedAt = DateTime(2026, 11, 16, 9, 2);

  ExplainOutcome outcome({
    PaperDate? date,
    PaperCaution? caution,
    PaperContact? contact,
    PaperPlace? place,
    List<String> paragraphs = const ['الفقرة الأولى.'],
  }) {
    return (
      explanation: PaperExplanation(
        title: 'فاتورة كهرباء',
        status: PaperStatus.success,
        paragraphs: paragraphs,
        todo: const PaperTodo(required: true, text: 'روح لأقرب فرع'),
        date: date,
        caution: caution,
        contact: contact,
        place: place,
      ),
      sessionId: 'session-1',
      explainSchemaVersion: '1.0',
    );
  }

  group('the paper row', () {
    test('carries the title, status and the two required cards', () {
      final row = paperWriteOf(
        id: 'p1',
        outcome: outcome(),
        photographedAt: photographedAt,
        savedAt: savedAt,
      ).paper;

      expect(row.id.value, 'p1');
      expect(row.title.value, 'فاتورة كهرباء');
      expect(row.status.value, PaperStatus.success);
      expect(row.todoRequired.value, isTrue);
      expect(row.todoText.value, 'روح لأقرب فرع');
    });

    test('stamps photographedAt and savedAt separately', () {
      final row = paperWriteOf(
        id: 'p1',
        outcome: outcome(),
        photographedAt: photographedAt,
        savedAt: savedAt,
      ).paper;

      expect(row.photographedAt.value, photographedAt);
      expect(row.savedAt.value, savedAt);
    });

    test('has no image path when none is given', () {
      final row = paperWriteOf(
        id: 'p1',
        outcome: outcome(),
        photographedAt: photographedAt,
        savedAt: savedAt,
      ).paper;

      expect(row.encryptedImagePath.present, isFalse);
    });

    test('carries an already-encrypted image path when given one', () {
      final row = paperWriteOf(
        id: 'p1',
        outcome: outcome(),
        photographedAt: photographedAt,
        savedAt: savedAt,
        encryptedImagePath: '/private/paper_images/p1/image.enc',
      ).paper;

      expect(
        row.encryptedImagePath.value,
        '/private/paper_images/p1/image.enc',
      );
    });

    test('leaves every optional card column null when the card is absent', () {
      final row = paperWriteOf(
        id: 'p1',
        outcome: outcome(),
        photographedAt: photographedAt,
        savedAt: savedAt,
      ).paper;

      expect(row.dateDay.value, isNull);
      expect(row.dateMinuteOfDay.value, isNull);
      expect(row.dateText.value, isNull);
      expect(row.cautionText.value, isNull);
      expect(row.contactName.value, isNull);
      expect(row.contactPhone.value, isNull);
      expect(row.placeText.value, isNull);
      expect(row.eventDay.value, isNull);
      expect(row.eventMinuteOfDay.value, isNull);
    });

    test(
      'writes the date card, denormalising eventDay/eventMinuteOfDay to agree',
      () {
        final date = PaperDate(
          day: DateTime(2026, 11, 20),
          time: const PaperTime(hour: 9, minute: 30),
          text: '20 نوفمبر، يوم الجمعة',
        );

        final row = paperWriteOf(
          id: 'p1',
          outcome: outcome(date: date),
          photographedAt: photographedAt,
          savedAt: savedAt,
        ).paper;

        expect(row.dateDay.value, date.day);
        expect(row.dateMinuteOfDay.value, 570);
        expect(row.dateText.value, '20 نوفمبر، يوم الجمعة');
        expect(row.eventDay.value, row.dateDay.value);
        expect(row.eventMinuteOfDay.value, row.dateMinuteOfDay.value);
      },
    );

    test('a date with no time of day leaves eventMinuteOfDay absent too', () {
      final date = PaperDate(day: DateTime(2026, 11, 20), text: '20 نوفمبر');

      final row = paperWriteOf(
        id: 'p1',
        outcome: outcome(date: date),
        photographedAt: photographedAt,
        savedAt: savedAt,
      ).paper;

      expect(row.dateMinuteOfDay.value, isNull);
      expect(row.eventMinuteOfDay.value, isNull);
    });

    test('writes the caution, contact and place cards', () {
      final row = paperWriteOf(
        id: 'p1',
        outcome: outcome(
          caution: const PaperCaution(text: 'خد بالك من الغرامة'),
          contact: const PaperContact(
            name: 'مكتب الشهر العقاري',
            phone: '0223456789',
          ),
          place: const PaperPlace(text: 'مصلحة الضرائب'),
        ),
        photographedAt: photographedAt,
        savedAt: savedAt,
      ).paper;

      expect(row.cautionText.value, 'خد بالك من الغرامة');
      expect(row.contactName.value, 'مكتب الشهر العقاري');
      expect(row.contactPhone.value, '0223456789');
      expect(row.placeText.value, 'مصلحة الضرائب');
    });

    test('carries the session id and schema version from the outcome', () {
      final row = paperWriteOf(
        id: 'p1',
        outcome: outcome(),
        photographedAt: photographedAt,
        savedAt: savedAt,
      ).paper;

      expect(row.sessionId.value, 'session-1');
      expect(row.explainSchemaVersion.value, '1.0');
    });
  });

  test('keeps the paragraphs in order', () {
    final write = paperWriteOf(
      id: 'p1',
      outcome: outcome(paragraphs: ['الأولى', 'الثانية']),
      photographedAt: photographedAt,
      savedAt: savedAt,
    );

    expect(write.paragraphs, ['الأولى', 'الثانية']);
  });

  group('paperSpansOf', () {
    test('carries each span\'s id, timing and exactness', () {
      final rows = paperSpansOf('p1', [
        const SpokenCardSpan(
          segmentId: 'explain',
          start: Duration.zero,
          end: Duration(seconds: 4),
          exact: true,
        ),
        const SpokenCardSpan(
          segmentId: 'todo',
          start: Duration(seconds: 4),
          end: Duration(seconds: 8),
          exact: false,
        ),
      ]);

      expect(rows.map((r) => r.paperId.value), ['p1', 'p1']);
      expect(rows.map((r) => r.segmentId.value), ['explain', 'todo']);
      expect(rows[0].startMs.value, 0);
      expect(rows[0].endMs.value, 4000);
      expect(rows[0].exact.value, isTrue);
      expect(rows[1].exact.value, isFalse);
    });

    test('an empty read produces no spans', () {
      expect(paperSpansOf('p1', const []), isEmpty);
    });
  });
}
