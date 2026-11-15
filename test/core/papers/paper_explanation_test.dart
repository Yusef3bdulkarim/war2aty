import 'package:flutter_test/flutter_test.dart';
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
  paragraphs: const ['دي فاتورة كهربا.'],
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
  test('two explanations built from the same fields are equal', () {
    expect(buildFull(), buildFull());
    expect(buildFull().hashCode, buildFull().hashCode);
  });

  test('a minimal explanation with every optional card null round-trips', () {
    final explanation = buildMinimal();

    expect(explanation.date, isNull);
    expect(explanation.caution, isNull);
    expect(explanation.contact, isNull);
    expect(explanation.place, isNull);
    expect(explanation, buildMinimal());
  });

  test('a changed paragraph breaks equality', () {
    final changed = PaperExplanation(
      title: buildFull().title,
      status: buildFull().status,
      paragraphs: const ['نص مختلف.'],
      todo: buildFull().todo,
      date: buildFull().date,
      caution: buildFull().caution,
      contact: buildFull().contact,
      place: buildFull().place,
    );

    expect(buildFull(), isNot(changed));
  });

  test('paragraphs are exposed as an unmodifiable list', () {
    expect(() => buildFull().paragraphs.add('extra'), throwsUnsupportedError);
  });

  test(
    'PaperTime exposes minuteOfDay for the eventMinuteOfDay denormalisation',
    () {
      const time = PaperTime(hour: 18, minute: 30);

      expect(time.minuteOfDay, 18 * 60 + 30);
      expect(time.formatted, '18:30');
    },
  );
}
