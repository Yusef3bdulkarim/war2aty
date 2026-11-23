import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/papers/paper_caution.dart';
import 'package:war2aty/core/papers/paper_contact.dart';
import 'package:war2aty/core/papers/paper_date.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_place.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';
import 'package:war2aty/features/paper/presentation/models/paper_voice_start.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';

import '../../../../support/fakes.dart';

void main() {
  const spans = [
    SpokenCardSpan(
      segmentId: 'explain',
      start: Duration.zero,
      end: Duration(seconds: 4),
      exact: true,
    ),
    SpokenCardSpan(
      segmentId: 'todo',
      start: Duration(seconds: 4),
      end: Duration(seconds: 6),
      exact: false,
    ),
  ];

  group('a fresh paper', () {
    test('is read aloud from the start under its own id', () {
      final paper = savedPaperWith(id: 'p-fresh');

      final start = PaperVoiceStart.of(paper, fresh: true);

      expect(start, isA<ReadPaperAloudFromStart>());
      expect((start as ReadPaperAloudFromStart).audioId, 'p-fresh');
    });

    test('is read aloud even when a saved reading is already flagged', () {
      final paper = savedPaperWith(audioSaved: true, spans: spans);

      expect(
        PaperVoiceStart.of(paper, fresh: true),
        isA<ReadPaperAloudFromStart>(),
      );
    });
  });

  group('an opened paper', () {
    test('with a saved reading replays it with the spans stored with it', () {
      final paper = savedPaperWith(
        id: 'p-saved',
        audioSaved: true,
        spans: spans,
      );

      final start = PaperVoiceStart.of(paper, fresh: false);

      expect(start, const ReplaySavedReading(audioId: 'p-saved', spans: spans));
    });

    test('without a saved reading is read aloud again', () {
      final paper = savedPaperWith(id: 'p-unread');

      final start = PaperVoiceStart.of(paper, fresh: false);

      expect(start, isA<ReadPaperAloudFromStart>());
      expect((start as ReadPaperAloudFromStart).audioId, 'p-unread');
    });

    test('with a saved reading and no spans still replays it', () {
      final paper = savedPaperWith(audioSaved: true);

      expect(
        PaperVoiceStart.of(paper, fresh: false),
        const ReplaySavedReading(audioId: 'p1', spans: []),
      );
    });
  });

  group('the segments a read starts with', () {
    test('are the present cards in page order, under their stored ids', () {
      final paper = savedPaperWith(
        explanation: PaperExplanation(
          title: 'فاتورة كهرباء',
          status: PaperStatus.success,
          paragraphs: const ['الفقرة الأولى.'],
          todo: const PaperTodo(required: true, text: 'ادفعها'),
          date: PaperDate(
            day: DateTime(2026, 12, 3),
            text: 'آخر ميعاد تلاتة ديسمبر',
          ),
          caution: const PaperCaution(text: 'هتتقطع'),
          contact: const PaperContact(name: 'شركة الكهرباء', phone: '16000'),
          place: const PaperPlace(text: 'شارع التحرير'),
        ),
      );

      final start =
          PaperVoiceStart.of(paper, fresh: true) as ReadPaperAloudFromStart;

      expect(start.segments.map((segment) => segment.id), [
        'explain',
        'todo',
        'date',
        'caution',
        'contact',
        'place',
      ]);
    });

    test('are just the two always-present cards for a bare paper', () {
      final start =
          PaperVoiceStart.of(savedPaperWith(), fresh: true)
              as ReadPaperAloudFromStart;

      expect(start.segments.map((segment) => segment.id), ['explain', 'todo']);
    });
  });

  test('toString carries no word of the paper', () {
    final paper = savedPaperWith();

    final read = PaperVoiceStart.of(paper, fresh: true).toString();
    final replay = PaperVoiceStart.of(
      savedPaperWith(audioSaved: true),
      fresh: false,
    ).toString();

    expect(read, isNot(contains('فاتورة')));
    expect(read, isNot(contains('روح لأقرب فرع')));
    expect(replay, isNot(contains('فاتورة')));
  });
}
