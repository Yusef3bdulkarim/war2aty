import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/ocr/domain/entities/ocr_result.dart';
import 'package:war2aty/features/ocr/domain/services/amount_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/date_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/phone_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/reference_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/text_normalizer.dart';
import 'package:war2aty/features/ocr/domain/services/time_extractor.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_candidates.dart';

void main() {
  late ExtractCandidates useCase;

  setUp(() {
    useCase = ExtractCandidates(
      normalizer: TextNormalizer(),
      dateExtractor: const DateExtractor(),
      timeExtractor: const TimeExtractor(),
      amountExtractor: const AmountExtractor(),
      phoneExtractor: const PhoneExtractor(),
      referenceExtractor: const ReferenceExtractor(),
    );
  });

  group('ExtractCandidates', () {
    test('normalizes text and populates cleanedText', () {
      final result = useCase(const OcrResult(originalText: '١٢٣ ج.م.'));

      expect(result.text.originalText, '١٢٣ ج.م.');
      expect(result.text.cleanedText, contains('123'));
      expect(result.text.cleanedText, contains('EGP'));
    });

    test('extracts dates from normalized text', () {
      final result = useCase(
        const OcrResult(originalText: 'تاريخ الفاتورة 15/07/2026'),
      );

      expect(result.dates, hasLength(1));
      expect(result.dates.first.normalizedDate, DateTime(2026, 7, 15));
    });

    test('extracts times from normalized text', () {
      final result = useCase(
        const OcrResult(originalText: 'الموعد الساعة 02:30 مساءً'),
      );

      expect(result.times, hasLength(1));
      expect(result.times.first.hour, 14);
      expect(result.times.first.minute, 30);
    });

    test('extracts amounts from normalized text', () {
      final result = useCase(const OcrResult(originalText: 'المطلوب ٢٥٠ ج.م.'));

      expect(result.amounts, hasLength(1));
      expect(result.amounts.first.value, 250.0);
    });

    test('extracts phone numbers from normalized text', () {
      final result = useCase(
        const OcrResult(originalText: 'اتصل على 01012345678'),
      );

      expect(result.phones, hasLength(1));
      expect(result.phones.first.normalizedNumber, '01012345678');
    });

    test('extracts references from normalized text', () {
      final result = useCase(
        const OcrResult(originalText: 'رقم الفاتورة ABC12345'),
      );

      expect(result.references, hasLength(1));
      expect(result.references.first.value, 'ABC12345');
    });

    test('returns empty lists when no candidates found', () {
      final result = useCase(
        const OcrResult(originalText: 'نص بسيط بدون أي معلومات مستخرجة'),
      );

      expect(result.dates, isEmpty);
      expect(result.times, isEmpty);
      expect(result.amounts, isEmpty);
      expect(result.phones, isEmpty);
      expect(result.references, isEmpty);
    });

    test('extracts multiple candidate types from one document', () {
      final result = useCase(
        const OcrResult(
          originalText:
              'فاتورة كهرباء\n'
              'التاريخ: 15/07/2026\n'
              'المبلغ: 350 EGP\n'
              'رقم الحساب: 1234567890\n'
              'للاستفسار: 01234567890',
        ),
      );

      expect(result.dates, isNotEmpty);
      expect(result.amounts, isNotEmpty);
      expect(result.references, isNotEmpty);
      expect(result.phones, isNotEmpty);
    });

    test('totalCandidates sums all lists', () {
      final result = useCase(
        const OcrResult(
          originalText: '15/07/2026 الساعة 10:00 صباحاً المبلغ 100 EGP',
        ),
      );

      expect(
        result.totalCandidates,
        result.dates.length +
            result.times.length +
            result.amounts.length +
            result.phones.length +
            result.references.length,
      );
    });
  });
}
