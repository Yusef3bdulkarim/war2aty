import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/ocr/domain/services/amount_extractor.dart';

void main() {
  const extractor = AmountExtractor();

  group('AmountExtractor', () {
    group('explicit currency', () {
      test('number + EGP', () {
        final results = extractor.extract('250.50 EGP');
        expect(results, hasLength(1));
        expect(results.first.value, equals(250.50));
        expect(results.first.currency, equals('EGP'));
        expect(results.first.isAmbiguous, isFalse);
      });

      test('EGP + number', () {
        final results = extractor.extract('EGP 1000');
        expect(results, hasLength(1));
        expect(results.first.value, equals(1000));
        expect(results.first.currency, equals('EGP'));
      });

      test('number + LE', () {
        final results = extractor.extract('125.00 LE');
        expect(results, hasLength(1));
        expect(results.first.currency, equals('EGP'));
      });

      test('number with commas', () {
        final results = extractor.extract('1,250.50 EGP');
        expect(results, hasLength(1));
        expect(results.first.value, equals(1250.50));
      });

      test('dollar sign', () {
        final results = extractor.extract('\$100');
        expect(results, hasLength(1));
        expect(results.first.currency, equals('USD'));
      });

      test('euro sign', () {
        final results = extractor.extract('€50.00');
        expect(results, hasLength(1));
        expect(results.first.currency, equals('EUR'));
      });
    });

    group('keyword-adjacent', () {
      test('إجمالي + number', () {
        final results = extractor.extract('إجمالي 250.50');
        expect(results, hasLength(1));
        expect(results.first.value, equals(250.50));
        expect(results.first.isAmbiguous, isTrue);
      });

      test('المطلوب: number', () {
        final results = extractor.extract('المطلوب: 1500');
        expect(results, hasLength(1));
        expect(results.first.value, equals(1500));
        expect(results.first.isAmbiguous, isTrue);
      });

      test('القيمة number', () {
        final results = extractor.extract('القيمة 300');
        expect(results, hasLength(1));
      });

      test('مبلغ number', () {
        final results = extractor.extract('مبلغ 500');
        expect(results, hasLength(1));
      });

      test('ضريبة number', () {
        final results = extractor.extract('ضريبة 14.00');
        expect(results, hasLength(1));
        expect(results.first.value, equals(14.00));
      });

      test('خصم number', () {
        final results = extractor.extract('خصم 50');
        expect(results, hasLength(1));
      });
    });

    group('dedup', () {
      test('does not duplicate when explicit and keyword overlap', () {
        final results = extractor.extract('إجمالي 250.50 EGP');
        expect(results, hasLength(1));
        expect(results.first.currency, equals('EGP'));
        expect(results.first.isAmbiguous, isFalse);
      });
    });

    group('multiple amounts', () {
      test('extracts multiple amounts in one text', () {
        final results = extractor.extract('ضريبة 14.00 EGP\nإجمالي 250');
        expect(results, hasLength(2));
      });
    });

    group('no false positives', () {
      test('does not extract bare numbers without context', () {
        final results = extractor.extract('رقم الحساب 123456');
        expect(results, isEmpty);
      });
    });
  });
}
