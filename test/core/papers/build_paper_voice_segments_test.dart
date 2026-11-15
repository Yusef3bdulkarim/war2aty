import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/papers/build_paper_voice_segments.dart';
import 'package:war2aty/core/papers/paper_caution.dart';
import 'package:war2aty/core/papers/paper_contact.dart';
import 'package:war2aty/core/papers/paper_date.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_place.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';

PaperExplanation buildFull() => PaperExplanation(
  title: 'فاتورة الكهربا',
  status: PaperStatus.success,
  paragraphs: const [
    'دي فاتورة كهربا من الشركة.',
    'المفروض تدفعها قبل الميعاد.',
  ],
  todo: const PaperTodo(required: true, text: 'ادفع قبل الميعاد.'),
  date: PaperDate(day: DateTime(2026, 11, 25), text: 'آخر ميعاد للدفع'),
  caution: const PaperCaution(text: 'بيتضاف رسم تأخير.'),
  contact: const PaperContact(name: 'شركة الكهرباء', phone: '121'),
  place: const PaperPlace(text: 'شارع الجمهورية'),
);

PaperExplanation buildMinimal() => PaperExplanation(
  title: 'جواب من البنك',
  status: PaperStatus.success,
  paragraphs: const ['دي ورقة من البنك.'],
  todo: const PaperTodo(required: false, text: 'مش مطلوب منك حاجة.'),
);

void main() {
  const build = BuildPaperVoiceSegments();

  group('BuildPaperVoiceSegments', () {
    test('a full paper yields one segment per card, in card order', () {
      final segments = build(buildFull());

      expect(segments.map((s) => s.id).toList(), [
        'explain',
        'todo',
        'date',
        'caution',
        'contact',
        'place',
      ]);
    });

    test('the explain segment opens with the title', () {
      final segments = build(buildFull());

      expect(
        segments.first.text,
        'فاتورة الكهربا. دي فاتورة كهربا من الشركة. المفروض تدفعها قبل الميعاد.',
      );
    });

    test('the todo segment is the todo text, unchanged', () {
      final segments = build(buildFull());

      expect(segments[1].text, 'ادفع قبل الميعاد.');
    });

    test('the date segment speaks date.text, never a formatted date', () {
      final segments = build(buildFull());

      final dateSegment = segments.firstWhere((s) => s.id == 'date');
      expect(dateSegment.text, 'آخر ميعاد للدفع');
      expect(dateSegment.text, isNot(contains('2026')));
      expect(dateSegment.text, isNot(contains('25')));
    });

    test('the caution segment is the caution text, unchanged', () {
      final segments = build(buildFull());

      expect(
        segments.firstWhere((s) => s.id == 'caution').text,
        'بيتضاف رسم تأخير.',
      );
    });

    test('the contact segment speaks the name only, never the phone', () {
      final segments = build(buildFull());

      final contactSegment = segments.firstWhere((s) => s.id == 'contact');
      expect(contactSegment.text, 'شركة الكهرباء');
      expect(contactSegment.text, isNot(contains('121')));
    });

    test('the place segment is the place text, unchanged', () {
      final segments = build(buildFull());

      expect(
        segments.firstWhere((s) => s.id == 'place').text,
        'شارع الجمهورية',
      );
    });

    test(
      'a paper with only the two required cards yields exactly two segments',
      () {
        final segments = build(buildMinimal());

        expect(segments.length, 2);
        expect(segments.map((s) => s.id).toList(), ['explain', 'todo']);
      },
    );

    test(
      'null cards produce no segment; order is preserved among the rest',
      () {
        final explanation = PaperExplanation(
          title: 'إيصال',
          status: PaperStatus.success,
          paragraphs: const ['إيصال دفع.'],
          todo: const PaperTodo(required: false, text: 'احفظه.'),
          caution: const PaperCaution(text: 'خليك فاكر الميعاد.'),
          place: const PaperPlace(text: 'الفرع الرئيسي'),
        );

        final segments = build(explanation);

        expect(segments.map((s) => s.id).toList(), [
          'explain',
          'todo',
          'caution',
          'place',
        ]);
      },
    );

    test('a paper with every optional card null yields only two segments', () {
      final segments = build(buildMinimal());

      expect(segments.any((s) => s.id == 'date'), isFalse);
      expect(segments.any((s) => s.id == 'caution'), isFalse);
      expect(segments.any((s) => s.id == 'contact'), isFalse);
      expect(segments.any((s) => s.id == 'place'), isFalse);
    });

    test('multiple explain paragraphs join into exactly one segment', () {
      final segments = build(buildFull());

      expect(segments.where((s) => s.id == 'explain'), hasLength(1));
    });

    test('calling twice on the same paper yields byte-identical segments', () {
      final explanation = buildFull();

      expect(build(explanation), build(explanation));
    });

    test('the returned list is unmodifiable', () {
      final segments = build(buildFull());

      expect(() => segments.add(segments.first), throwsUnsupportedError);
    });
  });
}
