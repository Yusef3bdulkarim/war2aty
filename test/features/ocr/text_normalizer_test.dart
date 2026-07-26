import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/ocr/domain/entities/ocr_result.dart';
import 'package:war2aty/features/ocr/domain/services/text_normalizer.dart';

void main() {
  const normalizer = TextNormalizer();

  String clean(String text) =>
      normalizer.normalize(OcrResult(originalText: text)).cleanedText;

  group('TextNormalizer', () {
    group('Arabic-Indic digit conversion', () {
      test('converts standard Arabic-Indic digits', () {
        expect(clean('٠١٢٣٤٥٦٧٨٩'), equals('0123456789'));
      });

      test('converts extended Arabic-Indic digits (Farsi/Urdu)', () {
        expect(clean('۰۱۲۳۴۵۶۷۸۹'), equals('0123456789'));
      });

      test('leaves Western digits unchanged', () {
        expect(clean('0123456789'), equals('0123456789'));
      });

      test('handles mixed Arabic-Indic and Western digits', () {
        expect(clean('٢٥/08/٢٠٢٦'), equals('25/08/2026'));
      });

      test('handles digits embedded in Arabic text', () {
        expect(clean('المبلغ ٢٥٠ جنيه'), equals('المبلغ 250 EGP'));
      });
    });

    group('currency unification', () {
      test('converts ج.م to EGP', () {
        expect(clean('250 ج.م'), equals('250 EGP'));
      });

      test('converts ج.م. (with trailing dot) to EGP', () {
        expect(clean('250 ج.م.'), equals('250 EGP'));
      });

      test('converts جنيه to EGP', () {
        expect(clean('250 جنيه'), equals('250 EGP'));
      });

      test('converts جنيه مصري to EGP', () {
        expect(clean('250 جنيه مصري'), equals('250 EGP'));
      });

      test('does not match ج م inside words like إجمالي', () {
        expect(clean('إجمالي'), equals('إجمالي'));
      });

      test('leaves non-Egyptian currencies alone', () {
        expect(clean('100 USD'), equals('100 USD'));
        expect(clean('100 €'), equals('100 €'));
      });
    });

    group('whitespace normalization', () {
      test('collapses multiple spaces to single space', () {
        expect(clean('hello   world'), equals('hello world'));
      });

      test('collapses tabs', () {
        expect(clean('hello\t\tworld'), equals('hello world'));
      });

      test('trims leading and trailing whitespace per line', () {
        expect(clean('  hello  \n  world  '), equals('hello\nworld'));
      });

      test('drops blank lines', () {
        expect(clean('hello\n\n\nworld'), equals('hello\nworld'));
      });

      test('drops lines that are only whitespace', () {
        expect(clean('hello\n   \n  \t \nworld'), equals('hello\nworld'));
      });

      test('preserves single newlines between content', () {
        expect(clean('line1\nline2\nline3'), equals('line1\nline2\nline3'));
      });
    });

    group('preserves original', () {
      test('original text is untouched', () {
        const input = '٢٥ ج.م   \n\n  مبلغ';
        final result = normalizer.normalize(
          const OcrResult(originalText: input),
        );
        expect(result.originalText, equals(input));
        expect(result.cleanedText, isNot(equals(input)));
      });
    });

    group('combined normalization', () {
      test('full Egyptian invoice line', () {
        expect(
          clean('إجمالي   الفاتورة :  ٢٥٠.٥٠   ج.م.'),
          equals('إجمالي الفاتورة : 250.50 EGP'),
        );
      });

      test('date with Arabic-Indic digits and extra spacing', () {
        expect(
          clean('التاريخ :  ٢٥ / ٠٨ / ٢٠٢٦'),
          equals('التاريخ : 25 / 08 / 2026'),
        );
      });
    });
  });
}
