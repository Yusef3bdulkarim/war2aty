import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/ocr/domain/services/reference_extractor.dart';

void main() {
  const extractor = ReferenceExtractor();

  group('ReferenceExtractor', () {
    test('رقم الحساب + digits', () {
      final results = extractor.extract('رقم الحساب 1234567890');
      expect(results, hasLength(1));
      expect(results.first.value, equals('1234567890'));
      expect(results.first.isAmbiguous, isTrue);
    });

    test('رقم الفاتورة: digits', () {
      final results = extractor.extract('رقم الفاتورة: 98765');
      expect(results, hasLength(1));
      expect(results.first.value, equals('98765'));
    });

    test('رقم مرجعي # alphanumeric', () {
      final results = extractor.extract('رقم مرجعي# ABC-1234');
      expect(results, hasLength(1));
      expect(results.first.value, equals('ABC-1234'));
    });

    test('رقم الحجز with mixed case', () {
      final results = extractor.extract('رقم الحجز BK2026XY');
      expect(results, hasLength(1));
      expect(results.first.value, equals('BK2026XY'));
    });

    test('كود keyword', () {
      final results = extractor.extract('كود 5678');
      expect(results, hasLength(1));
      expect(results.first.value, equals('5678'));
    });

    test('English Ref keyword', () {
      final results = extractor.extract('Ref: INV-2026-001');
      expect(results, hasLength(1));
      expect(results.first.value, equals('INV-2026-001'));
    });

    test('Invoice keyword', () {
      final results = extractor.extract('Invoice 12345');
      expect(results, hasLength(1));
    });

    test('rejects values shorter than 4 characters', () {
      final results = extractor.extract('رقم الحساب 123');
      expect(results, isEmpty);
    });

    test('deduplicates same reference value', () {
      final results = extractor.extract('رقم الفاتورة 12345\nرقم الحساب 12345');
      expect(results, hasLength(1));
    });

    test('extracts multiple different references', () {
      final results = extractor.extract(
        'رقم الفاتورة 98765\nرقم الحساب 1234567890',
      );
      expect(results, hasLength(2));
    });

    test('does not extract bare numbers without keywords', () {
      final results = extractor.extract('المبلغ 250.50');
      expect(results, isEmpty);
    });
  });
}
