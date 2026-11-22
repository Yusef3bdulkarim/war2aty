import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/papers/paper_caution.dart';
import 'package:war2aty/core/papers/paper_contact.dart';
import 'package:war2aty/core/papers/paper_date.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_place.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';
import 'package:war2aty/core/papers/saved_paper.dart';
import 'package:war2aty/features/paper/presentation/models/paper_view.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  PaperExplanation explanation({
    PaperDate? date,
    PaperCaution? caution,
    PaperContact? contact,
    PaperPlace? place,
  }) => PaperExplanation(
    title: 'جواب من مدرسة النور',
    status: PaperStatus.success,
    paragraphs: const ['دي ورقة من مدرسة النور.'],
    todo: const PaperTodo(required: true, text: 'روح الاجتماع بنفسك.'),
    date: date,
    caution: caution,
    contact: contact,
    place: place,
  );

  SavedPaper paper({
    required PaperExplanation explanation,
    required DateTime savedAt,
  }) => SavedPaper(
    id: 'p1',
    explanation: explanation,
    sessionId: 's1',
    explainSchemaVersion: '1.0',
    photographedAt: savedAt,
    savedAt: savedAt,
  );

  group('title', () {
    test('passes the explanation title through unchanged', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(),
          savedAt: DateTime.utc(2026, 11, 20, 8),
        ),
        ar,
        now: DateTime.utc(2026, 11, 20, 8),
      );

      expect(view.title, 'جواب من مدرسة النور');
    });
  });

  group('headerDate', () {
    // Cairo is UTC+2 outside DST (January); see reminder_due_label_test.dart.
    final now = DateTime.utc(2026, 1, 22, 8); // 10:00 Cairo.

    test('reads as today for the same Cairo day', () {
      final savedAt = DateTime.utc(2026, 1, 22, 4);

      expect(
        PaperView.from(
          paper(explanation: explanation(), savedAt: savedAt),
          ar,
          now: now,
        ).headerDate,
        'النهارده',
      );
      expect(
        PaperView.from(
          paper(explanation: explanation(), savedAt: savedAt),
          en,
          now: now,
        ).headerDate,
        'Today',
      );
    });

    test('reads as yesterday for the previous Cairo day', () {
      final savedAt = DateTime.utc(2026, 1, 21, 20);
      final view = PaperView.from(
        paper(explanation: explanation(), savedAt: savedAt),
        ar,
        now: now,
      );

      expect(view.headerDate, 'امبارح');
    });

    test('falls back to day and month further back', () {
      final savedAt = DateTime.utc(2026, 1, 18, 8);
      final view = PaperView.from(
        paper(explanation: explanation(), savedAt: savedAt),
        ar,
        now: now,
      );

      expect(view.headerDate, '18 يناير');
    });

    test('groups by the Cairo day, not the UTC day, right after midnight', () {
      // 22:30 UTC on the 21st is 00:30 Cairo on the 22nd — "today", not
      // "yesterday", even though UTC still says the 21st.
      final savedAt = DateTime.utc(2026, 1, 21, 22, 30);
      final view = PaperView.from(
        paper(explanation: explanation(), savedAt: savedAt),
        ar,
        now: now,
      );

      expect(view.headerDate, 'النهارده');
    });
  });

  group('cardIds', () {
    test('is explain and todo only when nothing else is present', () {
      final view = PaperView.from(
        paper(explanation: explanation(), savedAt: DateTime.utc(2026)),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.cardIds, ['explain', 'todo']);
    });

    test('adds each present card in segment order', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(
            date: PaperDate(
              day: DateTime.utc(2026, 11, 19),
              time: const PaperTime(hour: 10, minute: 0),
              text: 'اجتماع أولياء الأمور',
            ),
            caution: const PaperCaution(text: 'لازم تبلّغ المدرسة.'),
            contact: const PaperContact(
              name: 'مدرسة النور',
              phone: '0453312244',
            ),
            place: const PaperPlace(text: 'شارع الجمهورية، دمنهور'),
          ),
          savedAt: DateTime.utc(2026),
        ),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.cardIds, [
        'explain',
        'todo',
        'date',
        'caution',
        'contact',
        'place',
      ]);
    });

    test('skips an absent card while keeping the rest in order', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(
            contact: const PaperContact(name: 'معمل البرج', phone: '19911'),
          ),
          savedAt: DateTime.utc(2026),
        ),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.cardIds, ['explain', 'todo', 'contact']);
    });
  });

  group('dateCard', () {
    test('is null when the paper carries no date', () {
      final view = PaperView.from(
        paper(explanation: explanation(), savedAt: DateTime.utc(2026)),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.dateCard, isNull);
    });

    test('formats month, day, weekday and time', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(
            date: PaperDate(
              day: DateTime.utc(2026, 11, 19),
              time: const PaperTime(hour: 10, minute: 0),
              text: 'اجتماع أولياء الأمور',
            ),
          ),
          savedAt: DateTime.utc(2026),
        ),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.dateCard!.month, 'نوفمبر');
      expect(view.dateCard!.day, '19');
      expect(view.dateCard!.weekday, 'يوم الخميس');
      expect(view.dateCard!.time, 'الساعة 10 الصبح');
    });

    test('has no time slot when the paper carries no time', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(
            date: PaperDate(
              day: DateTime.utc(2026, 11, 19),
              text: 'اجتماع أولياء الأمور',
            ),
          ),
          savedAt: DateTime.utc(2026),
        ),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.dateCard!.time, isNull);
    });

    test('reads midnight as 12 in the morning, not 0', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(
            date: PaperDate(
              day: DateTime.utc(2026, 11, 19),
              time: const PaperTime(hour: 0, minute: 0),
              text: 'اجتماع أولياء الأمور',
            ),
          ),
          savedAt: DateTime.utc(2026),
        ),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.dateCard!.time, 'الساعة 12 الصبح');
    });

    test('a minute past the hour is spelled out', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(
            date: PaperDate(
              day: DateTime.utc(2026, 11, 19),
              time: const PaperTime(hour: 18, minute: 30),
              text: 'اجتماع أولياء الأمور',
            ),
          ),
          savedAt: DateTime.utc(2026),
        ),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.dateCard!.time, 'الساعة 6:30 بالليل');
    });

    test('english month, weekday and time read naturally', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(
            date: PaperDate(
              day: DateTime.utc(2026, 11, 19),
              time: const PaperTime(hour: 10, minute: 0),
              text: 'Parent meeting',
            ),
          ),
          savedAt: DateTime.utc(2026),
        ),
        en,
        now: DateTime.utc(2026),
      );

      expect(view.dateCard!.month, 'November');
      expect(view.dateCard!.day, '19');
      expect(view.dateCard!.weekday, 'Thursday');
      expect(view.dateCard!.time, '10 AM');
    });
  });

  group('groupedPhone', () {
    test('is null when there is no contact', () {
      final view = PaperView.from(
        paper(explanation: explanation(), savedAt: DateTime.utc(2026)),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.groupedPhone, isNull);
    });

    test('groups a 10-digit number as 3-3-4', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(
            contact: const PaperContact(
              name: 'مدرسة النور',
              phone: '0453312244',
            ),
          ),
          savedAt: DateTime.utc(2026),
        ),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.groupedPhone, '045 331 2244');
    });

    test('groups a short hotline without a lone trailing digit', () {
      final view = PaperView.from(
        paper(
          explanation: explanation(
            contact: const PaperContact(name: 'معمل البرج', phone: '19911'),
          ),
          savedAt: DateTime.utc(2026),
        ),
        ar,
        now: DateTime.utc(2026),
      );

      expect(view.groupedPhone, '199 11');
    });
  });

  group('equality', () {
    test('two views built from the same inputs are equal', () {
      final now = DateTime.utc(2026);
      final a = PaperView.from(
        paper(explanation: explanation(), savedAt: now),
        ar,
        now: now,
      );
      final b = PaperView.from(
        paper(explanation: explanation(), savedAt: now),
        ar,
        now: now,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
