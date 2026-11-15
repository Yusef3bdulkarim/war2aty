import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/explain/data/models/explain_response_dto.dart';

const _fullResponse = '''
{
  "explain_schema_version": "1.0",
  "session_id": "3f2a7c1e-0000-4000-8000-000000000000",
  "status": "success",
  "paper": { "title": "جواب من مدرسة النور" },
  "explain": [
    "دي ورقة من مدرسة النور لولي أمر الطالب أحمد محمود في الصف الرابع.",
    "الاجتماع هيبقى مع مدرّس الفصل."
  ],
  "todo": {
    "required": true,
    "text": "روح الاجتماع بنفسك، وخد معاك بطاقتك الشخصية."
  },
  "date": {
    "date": "2026-11-20",
    "time": "10:00",
    "text": "اجتماع أولياء الأمور"
  },
  "caution": { "text": "لو مش هتقدر تروح، لازم تبلّغ المدرسة قبل الميعاد." },
  "contact": { "name": "مدرسة النور", "phone": "0453312244" },
  "place": null
}
''';

const _minimalResponse = '''
{
  "explain_schema_version": "1.0",
  "session_id": "3f2a7c1e-0000-4000-8000-000000000000",
  "status": "success",
  "paper": { "title": "جواب من البنك" },
  "explain": ["دي ورقة من البنك الأهلي."],
  "todo": { "required": false, "text": "مش مطلوب منك حاجة." },
  "date": null,
  "caution": null,
  "contact": null,
  "place": null
}
''';

Map<String, dynamic> _decode(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  group('ExplainResponseDto.fromJson', () {
    test('parses a full success body', () {
      final dto = ExplainResponseDto.fromJson(_decode(_fullResponse));

      expect(dto.explainSchemaVersion, '1.0');
      expect(dto.status, 'success');
      expect(dto.paper.title, 'جواب من مدرسة النور');
      expect(dto.explain, hasLength(2));
      expect(dto.todo.required, isTrue);
      expect(dto.date?.date, '2026-11-20');
      expect(dto.date?.time, '10:00');
      expect(dto.caution?.text, isNotEmpty);
      expect(dto.contact?.phone, '0453312244');
      expect(dto.place, isNull);
    });

    test('parses a minimal body with every optional card null', () {
      final dto = ExplainResponseDto.fromJson(_decode(_minimalResponse));

      expect(dto.date, isNull);
      expect(dto.caution, isNull);
      expect(dto.contact, isNull);
      expect(dto.place, isNull);
      expect(dto.todo.required, isFalse);
    });

    test('keeps date.time null when the paper prints no time', () {
      final withNullTime = _decode(_fullResponse);
      (withNullTime['date'] as Map<String, dynamic>)['time'] = null;

      final dto = ExplainResponseDto.fromJson(withNullTime);

      expect(dto.date?.time, isNull);
    });

    test('round-trips through toJson', () {
      final original = _decode(_fullResponse);
      final roundTripped = ExplainResponseDto.fromJson(original).toJson();

      expect(
        ExplainResponseDto.fromJson(roundTripped).toJson(),
        equals(roundTripped),
      );
      expect(roundTripped['session_id'], original['session_id']);
      expect(roundTripped['explain'], original['explain']);
    });
  });
}
