import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/network/api_error_dto.dart';
import 'package:war2aty/features/analysis/data/models/analysis_response_dto.dart';

const _fullResponse = '''
{
  "schema_version": "1.0",
  "session_id": "3f2a7c1e-0000-4000-8000-000000000000",
  "status": "success",
  "document_type": {
    "type": "invoice",
    "title": "فاتورة كهرباء",
    "confidence": "high"
  },
  "summary": {
    "short": "فاتورة كهرباء لشهر مارس 2024 بمبلغ 850 جنيه.",
    "detailed": "دي فاتورة كهرباء من شركة جنوب القاهرة لتوزيع الكهرباء."
  },
  "key_information": [
    {
      "label": "رقم الحساب",
      "value": "12345678",
      "confidence": "high",
      "source": "extracted"
    }
  ],
  "dates": [
    {
      "label": "آخر موعد للسداد",
      "date": "2024-04-15",
      "time": "14:30",
      "role": "deadline",
      "is_reminder_worthy": true,
      "confidence": "high"
    },
    {
      "label": "تاريخ الإصدار",
      "date": "2024-03-20",
      "time": null,
      "role": "issued",
      "is_reminder_worthy": false,
      "confidence": "medium"
    }
  ],
  "amounts": [
    { "label": "إجمالي المبلغ", "value": 850.50, "currency": "EGP", "confidence": "high" },
    { "label": "رسوم", "value": 12, "currency": "EGP", "confidence": "low" }
  ],
  "actions_required": [
    { "description": "سدد الفاتورة قبل 15 أبريل 2024.", "basis": "explicit", "priority": "high" }
  ],
  "required_documents": ["بطاقة الرقم القومي"],
  "instructions": ["توجه لأقرب فرع شركة الكهرباء."],
  "warnings": [
    { "text": "المبالغ المذكورة قراءة غير مؤكدة — راجع الأصل.", "type": "general" }
  ],
  "missing_fields": ["account_holder"]
}
''';

/// Only the five required properties of the v1 schema.
const _minimalResponse = '''
{
  "schema_version": "1.0",
  "session_id": "3f2a7c1e-0000-4000-8000-000000000000",
  "status": "unsupported",
  "document_type": { "type": "other", "title": "ورقة غير معروفة", "confidence": "low" },
  "summary": { "short": "لم نتمكن من قراءة الورقة.", "detailed": "النص غير واضح." }
}
''';

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  group('AnalysisResponseDto.fromJson', () {
    test('parses a full success body', () {
      final dto = AnalysisResponseDto.fromJson(_decode(_fullResponse));

      expect(dto.schemaVersion, '1.0');
      expect(dto.status, 'success');
      expect(dto.documentType.type, 'invoice');
      expect(dto.documentType.title, 'فاتورة كهرباء');
      expect(dto.summary.short, startsWith('فاتورة كهرباء'));
      expect(dto.keyInformation.single.source, 'extracted');
      expect(dto.requiredDocuments, ['بطاقة الرقم القومي']);
      expect(dto.instructions, hasLength(1));
      expect(dto.warnings.single.type, 'general');
      expect(dto.missingFields, ['account_holder']);
    });

    test('keeps date time null when the document carries no time', () {
      final dto = AnalysisResponseDto.fromJson(_decode(_fullResponse));

      expect(dto.dates.first.time, '14:30');
      expect(dto.dates.first.isReminderWorthy, isTrue);
      expect(dto.dates.last.time, isNull);
      expect(dto.dates.last.role, 'issued');
    });

    test('reads integer amounts as double', () {
      final dto = AnalysisResponseDto.fromJson(_decode(_fullResponse));

      expect(dto.amounts.first.value, 850.50);
      expect(dto.amounts.last.value, 12.0);
    });

    test('defaults every optional array to empty when absent', () {
      final dto = AnalysisResponseDto.fromJson(_decode(_minimalResponse));

      expect(dto.status, 'unsupported');
      expect(dto.keyInformation, isEmpty);
      expect(dto.dates, isEmpty);
      expect(dto.amounts, isEmpty);
      expect(dto.actionsRequired, isEmpty);
      expect(dto.requiredDocuments, isEmpty);
      expect(dto.instructions, isEmpty);
      expect(dto.warnings, isEmpty);
      expect(dto.missingFields, isEmpty);
    });

    test('round-trips through toJson', () {
      final original = _decode(_fullResponse);
      final roundTripped = AnalysisResponseDto.fromJson(original).toJson();

      expect(
        AnalysisResponseDto.fromJson(roundTripped).toJson(),
        equals(roundTripped),
      );
      expect(roundTripped['session_id'], original['session_id']);
      expect(roundTripped['missing_fields'], original['missing_fields']);
    });
  });

  group('ApiErrorDto.fromJson', () {
    test('parses an error without details', () {
      final dto = ApiErrorDto.fromJson(
        _decode('{"error":{"code":"UNAUTHORIZED","message":"Invalid JWT."}}'),
      );

      expect(dto.code, 'UNAUTHORIZED');
      expect(dto.message, 'Invalid JWT.');
      expect(dto.details, isNull);
      expect(dto.toJson(), {
        'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid JWT.'},
      });
    });

    test('parses reset_at from DAILY_LIMIT_REACHED details', () {
      final dto = ApiErrorDto.fromJson(
        _decode('''
        {
          "error": {
            "code": "DAILY_LIMIT_REACHED",
            "message": "Daily analysis limit exceeded.",
            "details": { "reset_at": "2024-03-16T00:00:00+02:00" }
          }
        }
        '''),
      );

      expect(dto.code, 'DAILY_LIMIT_REACHED');
      expect(dto.details?.resetAt, '2024-03-16T00:00:00+02:00');
    });

    test('tolerates an empty details object', () {
      final dto = ApiErrorDto.fromJson(
        _decode(
          '{"error":{"code":"TIMEOUT","message":"Timed out.","details":{}}}',
        ),
      );

      expect(dto.details, isNotNull);
      expect(dto.details?.resetAt, isNull);
    });
  });
}
