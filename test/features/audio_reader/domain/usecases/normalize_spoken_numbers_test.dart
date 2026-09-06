import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/normalize_spoken_numbers.dart';

void main() {
  group('normalizeSpokenNumbers', () {
    test('reads a phone number digit-by-digit', () {
      expect(
        normalizeSpokenNumbers('اتصل بينا على 01012345678 في أي وقت'),
        'اتصل بينا على '
        'صفر واحد صفر واحد اثنين ثلاثة أربعة خمسة ستة سبعة ثمانية'
        ' في أي وقت',
      );
    });

    test('reads a reference number preceded by "رقم" digit-by-digit', () {
      expect(
        normalizeSpokenNumbers('رقم المحضر 123456'),
        'رقم المحضر واحد اثنين ثلاثة أربعة خمسة ستة',
      );
    });

    test('reads a currency amount of 1200 as "ألف ومئتين"', () {
      expect(
        normalizeSpokenNumbers('المبلغ المطلوب 1200 جنيه'),
        'المبلغ المطلوب ألف ومئتين جنيه',
      );
    });

    test('reads a currency amount of 1500 as "ألف وخمسمائة"', () {
      expect(
        normalizeSpokenNumbers('الإيجار الشهري 1500 جنيه'),
        'الإيجار الشهري ألف وخمسمائة جنيه',
      );
    });

    test('reads a currency amount stated before the word جنيه', () {
      expect(
        normalizeSpokenNumbers('جنيه 1200 هو المطلوب'),
        'جنيه ألف ومئتين هو المطلوب',
      );
    });

    test('reads a D/M/YYYY date as day + month name + year in words', () {
      expect(
        normalizeSpokenNumbers('الموعد النهائي 24/08/2026'),
        'الموعد النهائي 24 أغسطس ألفين وستة وعشرين',
      );
    });

    test('reads a DD-MM-YYYY date, stripping a leading zero from the day', () {
      expect(
        normalizeSpokenNumbers('تاريخ الإصدار 05-01-2026'),
        'تاريخ الإصدار 5 يناير ألفين وستة وعشرين',
      );
    });

    test('reads a morning time as "الساعة … صباحًا"', () {
      expect(
        normalizeSpokenNumbers('الموعد: 10:30 ص'),
        'الموعد: الساعة عشرة وثلاثين دقيقة صباحًا',
      );
    });

    test('reads an evening time as "الساعة … مساءً"', () {
      expect(
        normalizeSpokenNumbers('الجلسة: 2:15 م'),
        'الجلسة: الساعة اثنين وخمسة عشر دقيقة مساءً',
      );
    });

    test('reads an on-the-hour time without a dangling "و"', () {
      expect(
        normalizeSpokenNumbers('يفتح: 9:00 ص'),
        'يفتح: الساعة تسعة تمامًا صباحًا',
      );
    });

    test('reads a time with no AM/PM marker without a period word', () {
      expect(
        normalizeSpokenNumbers('الموعد: 10:30'),
        'الموعد: الساعة عشرة وثلاثين دقيقة',
      );
    });

    test('a plain Arabic sentence with no numbers is untouched', () {
      const sentence =
          'الفاتورة دي عن استهلاك شهر مارس، والمبلغ لازم يتسدد قبل الموعد.';
      expect(normalizeSpokenNumbers(sentence), sentence);
    });

    test('a short number with no surrounding context is left alone', () {
      // Neither a phone number (too short), a reference number (no
      // keyword), nor next to a currency word — genuinely ambiguous.
      expect(normalizeSpokenNumbers('صفحة 12 من 30'), 'صفحة 12 من 30');
    });

    test('an out-of-range date-shaped number is left alone', () {
      // Month 13 cannot be a real date — do not guess.
      expect(normalizeSpokenNumbers('الكود 24/13/2026'), 'الكود 24/13/2026');
    });

    test('Arabic-Indic digits are read the same as Western digits', () {
      expect(
        normalizeSpokenNumbers('رقم الطلب ١٢٣'),
        'رقم الطلب واحد اثنين ثلاثة',
      );
    });
  });
}
