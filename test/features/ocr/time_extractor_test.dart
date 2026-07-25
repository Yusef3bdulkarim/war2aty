import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/ocr/domain/services/time_extractor.dart';

void main() {
  const extractor = TimeExtractor();

  group('TimeExtractor', () {
    group('24h format', () {
      test('HH:MM', () {
        final results = extractor.extract('الساعة 14:30');
        expect(results, hasLength(1));
        expect(results.first.hour, equals(14));
        expect(results.first.minute, equals(30));
        expect(results.first.isAmbiguous, isFalse);
      });

      test('HH.MM', () {
        final results = extractor.extract('الموعد 09.00');
        expect(results, hasLength(1));
        expect(results.first.hour, equals(9));
        expect(results.first.minute, equals(0));
      });

      test('13:00-23:59 are unambiguous', () {
        final results = extractor.extract('13:00');
        expect(results.first.isAmbiguous, isFalse);
      });

      test('00:00 is unambiguous', () {
        final results = extractor.extract('00:00');
        expect(results.first.isAmbiguous, isFalse);
      });

      test('1:00-12:59 without marker are ambiguous', () {
        final results = extractor.extract('9:30');
        expect(results.first.isAmbiguous, isTrue);
      });
    });

    group('Arabic AM/PM', () {
      test('صباحاً (AM)', () {
        final results = extractor.extract('9:30 صباحاً');
        expect(results, hasLength(1));
        expect(results.first.hour, equals(9));
        expect(results.first.minute, equals(30));
        expect(results.first.isAmbiguous, isFalse);
      });

      test('مساءً (PM)', () {
        final results = extractor.extract('3:00 مساءً');
        expect(results, hasLength(1));
        expect(results.first.hour, equals(15));
        expect(results.first.minute, equals(0));
      });

      test('ص abbreviation (AM)', () {
        final results = extractor.extract('10:00 ص');
        expect(results, hasLength(1));
        expect(results.first.hour, equals(10));
      });

      test('م abbreviation (PM)', () {
        final results = extractor.extract('7:45 م');
        expect(results, hasLength(1));
        expect(results.first.hour, equals(19));
        expect(results.first.minute, equals(45));
      });

      test('12 PM stays 12', () {
        final results = extractor.extract('12:00 مساءً');
        expect(results.first.hour, equals(12));
      });

      test('12 AM becomes 0', () {
        final results = extractor.extract('12:00 صباحاً');
        expect(results.first.hour, equals(0));
      });
    });

    group('English AM/PM', () {
      test('AM', () {
        final results = extractor.extract('9:30 AM');
        expect(results, hasLength(1));
        expect(results.first.hour, equals(9));
      });

      test('PM', () {
        final results = extractor.extract('3:00 PM');
        expect(results.first.hour, equals(15));
      });

      test('a.m.', () {
        final results = extractor.extract('10:00 a.m.');
        expect(results.first.hour, equals(10));
      });

      test('p.m.', () {
        final results = extractor.extract('5:30 p.m.');
        expect(results.first.hour, equals(17));
      });
    });

    group('edge cases', () {
      test('rejects invalid minute > 59', () {
        final results = extractor.extract('10:60');
        expect(results, isEmpty);
      });

      test('rejects hour > 23 without AM/PM', () {
        final results = extractor.extract('25:00');
        expect(results, isEmpty);
      });

      test('multiple times in one text', () {
        final results = extractor.extract('من 9:00 صباحاً إلى 5:00 مساءً');
        expect(results, hasLength(2));
        expect(results[0].hour, equals(9));
        expect(results[1].hour, equals(17));
      });
    });
  });
}
