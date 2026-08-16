import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/analysis/data/models/ocr_response_dto.dart';

const _fullResponse = '''
{
  "schema_version": "2.0",
  "session_id": "3f2a7c1e-0000-4000-8000-000000000000",
  "ocr_text": "فاتورة كهرباء 850.50 جنيه بتاريخ 15/04/2024",
  "detected_languages": ["ar"],
  "candidates": {
    "dates": [
      { "raw_text": "15/04/2024", "normalized_date": "2024-04-15", "is_ambiguous": false }
    ],
    "times": [
      { "raw_text": "2:30 م", "hour": 14, "minute": 30, "is_ambiguous": false }
    ],
    "amounts": [
      { "raw_text": "850.50 جنيه", "value": 850.5, "currency": "EGP", "is_ambiguous": false }
    ],
    "phones": [
      { "raw_text": "0100-123-4567", "normalized_number": "01001234567", "is_ambiguous": false }
    ],
    "references": [
      { "raw_text": "رقم الفاتورة 12345678", "value": "12345678", "is_ambiguous": true }
    ]
  }
}
''';

void main() {
  group('OcrResponseDto.fromJson', () {
    test('reads the envelope fields', () {
      final dto = OcrResponseDto.fromJson(
        jsonDecode(_fullResponse) as Map<String, dynamic>,
      );

      expect(dto.schemaVersion, '2.0');
      expect(dto.sessionId, '3f2a7c1e-0000-4000-8000-000000000000');
      expect(dto.ocrText, 'فاتورة كهرباء 850.50 جنيه بتاريخ 15/04/2024');
      expect(dto.detectedLanguages, ['ar']);
      expect(dto.candidates.dates, hasLength(1));
      expect(dto.candidates.times, hasLength(1));
      expect(dto.candidates.amounts, hasLength(1));
      expect(dto.candidates.phones, hasLength(1));
      expect(dto.candidates.references, hasLength(1));
    });
  });

  group('OcrResponseDto.toExtractionResult', () {
    test('mirrors ocr_text into both original and cleaned text', () {
      final dto = OcrResponseDto.fromJson(
        jsonDecode(_fullResponse) as Map<String, dynamic>,
      );

      final extraction = dto.toExtractionResult();

      expect(
        extraction.text.originalText,
        'فاتورة كهرباء 850.50 جنيه بتاريخ 15/04/2024',
      );
      expect(extraction.text.cleanedText, extraction.text.originalText);
      expect(extraction.detectedLanguages, ['ar']);
    });

    test('maps every candidate type into its entity', () {
      final dto = OcrResponseDto.fromJson(
        jsonDecode(_fullResponse) as Map<String, dynamic>,
      );

      final extraction = dto.toExtractionResult();

      final date = extraction.dates.single;
      expect(date.rawText, '15/04/2024');
      expect(date.normalizedDate, DateTime(2024, 4, 15));
      expect(date.isAmbiguous, isFalse);

      final time = extraction.times.single;
      expect(time.hour, 14);
      expect(time.minute, 30);

      final amount = extraction.amounts.single;
      expect(amount.value, 850.5);
      expect(amount.currency, 'EGP');

      final phone = extraction.phones.single;
      expect(phone.normalizedNumber, '01001234567');

      final reference = extraction.references.single;
      expect(reference.value, '12345678');
      expect(reference.isAmbiguous, isTrue);
    });

    test('leaves normalizedDate null when Azure found no parseable date', () {
      final json = jsonDecode(_fullResponse) as Map<String, dynamic>;
      (json['candidates'] as Map<String, dynamic>)['dates'] = [
        {
          'raw_text': 'شهر رمضان',
          'normalized_date': null,
          'is_ambiguous': true,
        },
      ];
      final dto = OcrResponseDto.fromJson(json);

      final extraction = dto.toExtractionResult();

      expect(extraction.dates.single.normalizedDate, isNull);
      expect(extraction.dates.single.isAmbiguous, isTrue);
    });

    test('leaves normalizedDate null on a malformed date string', () {
      final json = jsonDecode(_fullResponse) as Map<String, dynamic>;
      (json['candidates'] as Map<String, dynamic>)['dates'] = [
        {
          'raw_text': 'x',
          'normalized_date': 'not-a-date',
          'is_ambiguous': false,
        },
      ];
      final dto = OcrResponseDto.fromJson(json);

      expect(dto.toExtractionResult().dates.single.normalizedDate, isNull);
    });

    test('produces an empty ExtractionResult when every list is empty', () {
      const empty = '''
      {
        "schema_version": "2.0",
        "session_id": "session-1",
        "ocr_text": "",
        "detected_languages": [],
        "candidates": {
          "dates": [], "times": [], "amounts": [], "phones": [], "references": []
        }
      }
      ''';
      final dto = OcrResponseDto.fromJson(
        jsonDecode(empty) as Map<String, dynamic>,
      );

      final extraction = dto.toExtractionResult();

      expect(extraction.totalCandidates, 0);
      expect(extraction.hasAmbiguousCandidates, isFalse);
    });
  });
}
