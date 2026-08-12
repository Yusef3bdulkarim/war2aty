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

    // Regression: "Ref" previously matched as a bare prefix inside
    // "Reference", capturing the leftover "erence" as the value instead of
    // the real reference number after "Number:". "Reference" is now its own
    // keyword, so it matches directly and the full "REF-9948271" becomes the
    // value (rather than the earlier, more lossy fix that only kept the
    // digits after "REF").
    test('does not match "Ref" as a prefix inside "Reference"', () {
      final results = extractor.extract('Reference Number: REF-9948271');
      expect(results, hasLength(1));
      expect(results.first.value, equals('REF-9948271'));
    });

    // Regression (found in code review of the fix above): adding the
    // `(?![A-Za-z])` guard, without giving "Reference" its own keyword
    // entry, meant a document spelling the label out in full with no
    // separate bare "REF"/"Ref" token anywhere else matched nothing at all
    // — the reference number was silently dropped.
    test(
      'matches "Reference" spelled out with no separate bare "REF" elsewhere',
      () {
        final results = extractor.extract('Reference Number: 8821345');
        expect(results, hasLength(1));
        expect(results.first.value, equals('8821345'));
      },
    );

    // Regression: "Account" followed by the common "Number:" label word
    // previously captured "Number" itself as the value.
    test('skips the "Number" label after an English keyword', () {
      final results = extractor.extract('Account Number: 8827-4419-02');
      expect(results, hasLength(1));
      expect(results.first.value, equals('8827-4419-02'));
    });
  });
}
