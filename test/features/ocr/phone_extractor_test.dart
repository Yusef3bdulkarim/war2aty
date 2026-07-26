import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/ocr/domain/services/phone_extractor.dart';

void main() {
  const extractor = PhoneExtractor();

  group('PhoneExtractor', () {
    group('local mobile numbers', () {
      test('contiguous 11-digit mobile', () {
        final results = extractor.extract('اتصل 01012345678');
        expect(results, hasLength(1));
        expect(results.first.normalizedNumber, equals('01012345678'));
        expect(results.first.isAmbiguous, isFalse);
      });

      test('010 prefix', () {
        final results = extractor.extract('01098765432');
        expect(results, hasLength(1));
      });

      test('011 prefix', () {
        final results = extractor.extract('01112345678');
        expect(results, hasLength(1));
      });

      test('012 prefix', () {
        final results = extractor.extract('01212345678');
        expect(results, hasLength(1));
      });

      test('015 prefix', () {
        final results = extractor.extract('01512345678');
        expect(results, hasLength(1));
      });
    });

    group('whitespace reassembly', () {
      test('spaces between groups', () {
        final results = extractor.extract('010 1234 5678');
        expect(results, hasLength(1));
        expect(results.first.normalizedNumber, equals('01012345678'));
        expect(results.first.isAmbiguous, isTrue);
      });

      test('dashes between groups', () {
        final results = extractor.extract('010-1234-5678');
        expect(results, hasLength(1));
        expect(results.first.normalizedNumber, equals('01012345678'));
      });

      test('dots between groups', () {
        final results = extractor.extract('010.1234.5678');
        expect(results, hasLength(1));
        expect(results.first.normalizedNumber, equals('01012345678'));
      });

      test('mixed separators', () {
        final results = extractor.extract('010 1234-5678');
        expect(results, hasLength(1));
        expect(results.first.normalizedNumber, equals('01012345678'));
      });
    });

    group('international format', () {
      test('+20 prefix', () {
        final results = extractor.extract('+201012345678');
        expect(results, hasLength(1));
        expect(results.first.normalizedNumber, equals('01012345678'));
      });

      test('002 prefix', () {
        final results = extractor.extract('00201012345678');
        expect(results, hasLength(1));
        expect(results.first.normalizedNumber, equals('01012345678'));
      });
    });

    group('invalid numbers', () {
      test('rejects non-Egyptian prefix', () {
        final results = extractor.extract('01312345678');
        expect(results, isEmpty);
      });

      test('rejects too few digits', () {
        final results = extractor.extract('0101234567');
        expect(results, isEmpty);
      });

      test('deduplicates same number appearing twice', () {
        final results = extractor.extract('01012345678 or 01012345678');
        expect(results, hasLength(1));
      });
    });

    group('multiple numbers', () {
      test('extracts two different numbers', () {
        final results = extractor.extract(
          'خدمة العملاء 01012345678 أو 01198765432',
        );
        expect(results, hasLength(2));
      });
    });
  });
}
