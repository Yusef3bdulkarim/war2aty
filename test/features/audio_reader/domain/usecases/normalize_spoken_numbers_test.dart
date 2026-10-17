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

  // F30-T02. Two amounts used to throw out of here rather than read: a
  // `RangeError` anywhere in 10,000-10,999, and a null check at 1,000,000 and
  // up. Both killed the whole reading before a word was spoken, in every
  // mode, since `BuildReadingText` funnels all four through this function —
  // and in a release build the throw escapes an unawaited callback, so the
  // user got silence with no error at all.
  group('normalizeSpokenNumbers · amounts that used to crash', () {
    test('reads 10,000 as "عشرة آلاف" instead of throwing RangeError', () {
      expect(
        normalizeSpokenNumbers('المبلغ 10000 جنيه'),
        'المبلغ عشرة آلاف جنيه',
      );
    });

    test('reads 10,500 — the whole 10,000-10,999 band was a RangeError', () {
      expect(
        normalizeSpokenNumbers('المبلغ 10500 جنيه'),
        'المبلغ عشرة آلاف وخمسمائة جنيه',
      );
    });

    test('reads 1,000,000 as "مليون" instead of throwing on a null check', () {
      expect(
        normalizeSpokenNumbers('المبلغ 1000000 جنيه'),
        'المبلغ مليون جنيه',
      );
    });

    test('reads 1,500,000 across both the million and thousand scales', () {
      expect(
        normalizeSpokenNumbers('المبلغ 1500000 جنيه'),
        'المبلغ مليون وخمسمائة ألف جنيه',
      );
    });

    test('a decimal part in the crashing band reads too', () {
      // The piastres go through the same number words, so the band had to be
      // fixed on both sides of the dot, not just the left.
      expect(
        normalizeSpokenNumbers('المبلغ 1200.10500 جنيه'),
        'المبلغ ألف ومئتين جنيه وعشرة آلاف وخمسمائة قرش',
      );
    });

    test('no amount from 0 to 1,200,000 throws', () {
      // The band fixed here is 10,000-10,999 and 1,000,000 up; this sweeps
      // across both edges rather than trusting the three samples above.
      for (var amount = 0; amount <= 1200000; amount++) {
        expect(
          () => normalizeSpokenNumbers('$amount جنيه'),
          returnsNormally,
          reason: 'threw on $amount',
        );
      }
    });
  });

  // F30-T02. `_parseDigits` wraps around silently past 2^63, so a long
  // enough run would otherwise be read aloud as a number the paper does not
  // carry — the invented figure CLAUDE.md §7 forbids. Too long to speak now
  // means left alone.
  group('normalizeSpokenNumbers · runs too long to speak', () {
    test('a 12-digit amount is left as digits, not spoken as words', () {
      expect(
        normalizeSpokenNumbers('المبلغ 123456789012 جنيه'),
        'المبلغ 123456789012 جنيه',
      );
    });

    test('a 20-digit run is never read as a wrapped-around number', () {
      const noise = 'المبلغ 99999999999999999999 جنيه';
      expect(normalizeSpokenNumbers(noise), noise);
    });

    test('an over-long run before the currency word is left alone too', () {
      expect(normalizeSpokenNumbers('جنيه 123456789012'), 'جنيه 123456789012');
    });

    test('an over-long decimal part leaves the whole amount alone', () {
      const noise = 'المبلغ 1.99999999999999999999 جنيه';
      expect(normalizeSpokenNumbers(noise), noise);
    });

    test('9 digits is still spoken — the limit is not off by one', () {
      expect(
        normalizeSpokenNumbers('المبلغ 999999999 جنيه'),
        'المبلغ تسعمائة وتسعة وتسعين مليون '
        'وتسعمائة وتسعة وتسعين ألف '
        'وتسعمائة وتسعة وتسعين جنيه',
      );
    });
  });

  // F30-T22. Two faults in the clock reading, found while testing T02:
  // «الساعة» was prepended even when the text already said it, and a
  // 24-hour hour was read as its own number — «14:30» as «أربعة عشر»,
  // which is not how anybody says half past two.
  group('normalizeSpokenNumbers · the clock', () {
    test('«الساعة» in the text is not doubled', () {
      expect(
        normalizeSpokenNumbers('الموعد الساعة 10:30 ص'),
        'الموعد الساعة عشرة وثلاثين دقيقة صباحًا',
      );
    });

    test('«الساعه» with a final ه is swallowed the same way', () {
      expect(
        normalizeSpokenNumbers('الموعد الساعه 10:30 ص'),
        'الموعد الساعة عشرة وثلاثين دقيقة صباحًا',
      );
    });

    test('a 24-hour hour reads as the 12-hour one, with مساءً', () {
      expect(
        normalizeSpokenNumbers('الجلسة 14:30'),
        'الجلسة الساعة اثنين وثلاثين دقيقة مساءً',
      );
    });

    test('a 24-hour hour and a written «الساعة» both resolve at once', () {
      expect(
        normalizeSpokenNumbers('الجلسة الساعة 14:30 م'),
        'الجلسة الساعة اثنين وثلاثين دقيقة مساءً',
      );
    });

    test('23:00 reads as eleven in the evening, on the hour', () {
      expect(
        normalizeSpokenNumbers('يقفل 23:00'),
        'يقفل الساعة أحد عشر تمامًا مساءً',
      );
    });

    test('midnight reads as twelve in the morning', () {
      expect(
        normalizeSpokenNumbers('من 0:30'),
        'من الساعة اثنا عشر وثلاثين دقيقة صباحًا',
      );
    });

    test('a marker contradicting a 24-hour hour loses to the clock', () {
      // «14:30 ص» cannot both be 2:30pm and morning. The 24-hour reading is
      // the one that cannot be misread, so it wins.
      expect(
        normalizeSpokenNumbers('الموعد 14:30 ص'),
        'الموعد الساعة اثنين وثلاثين دقيقة مساءً',
      );
    });

    test('hours 1-12 still take no period word unless one was written', () {
      expect(
        normalizeSpokenNumbers('الموعد 12:00'),
        'الموعد الساعة اثنا عشر تمامًا',
      );
    });

    test('an out-of-range hour is left alone, «الساعة» included', () {
      expect(
        normalizeSpokenNumbers('الكود الساعة 99:99'),
        'الكود الساعة 99:99',
      );
    });
  });

  // F30-T21. The currency word belongs between the pounds and the piastres.
  // It used to be appended after both, so every bill with piastres on it —
  // which is most of them — read as «… وخمسين قرش جنيه».
  group('normalizeSpokenNumbers · piastres', () {
    test('the currency word sits between the pounds and the piastres', () {
      expect(
        normalizeSpokenNumbers('المبلغ 250.50 جنيه'),
        'المبلغ مئتين وخمسين جنيه وخمسين قرش',
      );
    });

    test('an amount with no piastres is unchanged by the split', () {
      expect(
        normalizeSpokenNumbers('المبلغ 250 جنيه'),
        'المبلغ مئتين وخمسين جنيه',
      );
    });

    test('a zero piastres part is dropped, not read as «وصفر قرش»', () {
      expect(
        normalizeSpokenNumbers('المبلغ 250.00 جنيه'),
        'المبلغ مئتين وخمسين جنيه',
      );
    });

    test('piastres work with «ج.م» too, not only «جنيه»', () {
      expect(
        normalizeSpokenNumbers('المبلغ 250.50 ج.م'),
        'المبلغ مئتين وخمسين ج.م وخمسين قرش',
      );
    });

    test('an amount stated before the currency word keeps source order', () {
      expect(
        normalizeSpokenNumbers('جنيه 250.50 هو المطلوب'),
        'جنيه مئتين وخمسين وخمسين قرش هو المطلوب',
      );
    });
  });

  // F30-T02. The scale words carry Arabic's own agreement: one and two have
  // their own forms, 3-10 take the plural, 11 and up go back to the singular.
  group('normalizeSpokenNumbers · scale-word agreement', () {
    test('2,000 is "ألفين", not "اثنين ألف"', () {
      expect(normalizeSpokenNumbers('المبلغ 2000 جنيه'), 'المبلغ ألفين جنيه');
    });

    test('3,000 takes the plural "آلاف"', () {
      expect(
        normalizeSpokenNumbers('المبلغ 3000 جنيه'),
        'المبلغ ثلاثة آلاف جنيه',
      );
    });

    test('11,000 goes back to the singular "ألف"', () {
      expect(
        normalizeSpokenNumbers('المبلغ 11000 جنيه'),
        'المبلغ أحد عشر ألف جنيه',
      );
    });

    test('2,000,000 is "مليونين"', () {
      expect(
        normalizeSpokenNumbers('المبلغ 2000000 جنيه'),
        'المبلغ مليونين جنيه',
      );
    });

    test('3,000,000 takes the plural "ملايين"', () {
      expect(
        normalizeSpokenNumbers('المبلغ 3000000 جنيه'),
        'المبلغ ثلاثة ملايين جنيه',
      );
    });
  });
}
