import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/ocr/domain/services/date_extractor.dart';

void main() {
  const extractor = DateExtractor();

  group('DateExtractor', () {
    group('numeric dates', () {
      test('DD/MM/YYYY', () {
        final results = extractor.extract('التاريخ 25/08/2026');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 8, 25));
        expect(results.first.isAmbiguous, isFalse);
      });

      test('DD-MM-YYYY', () {
        final results = extractor.extract('15-03-2026');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 3, 15));
      });

      test('DD.MM.YYYY', () {
        final results = extractor.extract('01.12.2025');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2025, 12, 1));
      });

      test('2-digit year expands to 20xx', () {
        final results = extractor.extract('25/08/26');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 8, 25));
      });

      test('ambiguous when day and month both <= 12', () {
        final results = extractor.extract('01/02/2026');
        expect(results, hasLength(1));
        expect(results.first.isAmbiguous, isTrue);
        // Parsed as DD/MM (day-first, Egyptian convention)
        expect(results.first.normalizedDate, DateTime(2026, 2, 1));
      });

      test('not ambiguous when day > 12', () {
        final results = extractor.extract('25/01/2026');
        expect(results, hasLength(1));
        expect(results.first.isAmbiguous, isFalse);
      });

      test('not ambiguous when day equals month', () {
        final results = extractor.extract('05/05/2026');
        expect(results, hasLength(1));
        expect(results.first.isAmbiguous, isFalse);
      });

      test('rejects invalid month > 12', () {
        final results = extractor.extract('25/13/2026');
        expect(results, isEmpty);
      });

      test('rejects invalid day > 31', () {
        final results = extractor.extract('32/01/2026');
        expect(results, isEmpty);
      });

      test('handles spaces around separators', () {
        final results = extractor.extract('25 / 08 / 2026');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 8, 25));
      });

      test('multiple dates in one text', () {
        final results = extractor.extract('من 01/01/2026 إلى 31/12/2026');
        expect(results, hasLength(2));
      });
    });

    group('Arabic month names', () {
      test('day + Arabic month + year', () {
        final results = extractor.extract('25 يناير 2026');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 1, 25));
        expect(results.first.isAmbiguous, isFalse);
      });

      test('with من prefix', () {
        final results = extractor.extract('15 من فبراير 2026');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 2, 15));
      });

      test('without year is ambiguous', () {
        final results = extractor.extract('25 مارس');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, isNull);
        expect(results.first.isAmbiguous, isTrue);
      });

      test('handles أبريل / إبريل / ابريل variants', () {
        for (final variant in ['أبريل', 'إبريل', 'ابريل']) {
          final results = extractor.extract('10 $variant 2026');
          expect(results, hasLength(1), reason: '$variant should match');
          expect(results.first.normalizedDate?.month, equals(4));
        }
      });

      test('handles يونيو / يونيه variants', () {
        final r1 = extractor.extract('1 يونيو 2026');
        final r2 = extractor.extract('1 يونيه 2026');
        expect(r1.first.normalizedDate?.month, equals(6));
        expect(r2.first.normalizedDate?.month, equals(6));
      });
    });

    group('English month names', () {
      test('day + English month + year', () {
        final results = extractor.extract('25 January 2026');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 1, 25));
      });

      test('abbreviated month', () {
        final results = extractor.extract('15 Feb 2026');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 2, 15));
      });

      test('case insensitive', () {
        final results = extractor.extract('1 MARCH 2026');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 3, 1));
      });

      test('with of prefix', () {
        final results = extractor.extract('5 of May 2026');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, DateTime(2026, 5, 5));
      });
    });

    group('Hijri dates', () {
      test('detects Hijri month name with year', () {
        final results = extractor.extract('5 محرم 1448');
        expect(results, hasLength(1));
        expect(results.first.normalizedDate, isNull);
        expect(results.first.isAmbiguous, isTrue);
        expect(results.first.rawText, contains('محرم'));
      });

      test('detects رمضان', () {
        final results = extractor.extract('1 رمضان 1448');
        expect(results, hasLength(1));
        expect(results.first.isAmbiguous, isTrue);
      });

      test('detects ذو الحجة', () {
        final results = extractor.extract('10 ذو الحجة 1448');
        expect(results, hasLength(1));
        expect(results.first.isAmbiguous, isTrue);
      });
    });

    group('no false positives', () {
      test('does not extract bare numbers', () {
        final results = extractor.extract('رقم الحساب 123456');
        expect(results, isEmpty);
      });

      test('does not extract phone numbers', () {
        final results = extractor.extract('01012345678');
        expect(results, isEmpty);
      });
    });
  });
}
