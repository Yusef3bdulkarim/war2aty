import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/papers/paper_date.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/features/explain/data/mappers/explain_response_mapper.dart';
import 'package:war2aty/features/explain/data/models/explain_response_dto.dart';

ExplainResponseDto _dto({
  String status = 'success',
  List<String> explain = const ['دي ورقة من البنك.'],
  ExplainTodoDto todo = const ExplainTodoDto(
    required: true,
    text: 'ادفع قبل الميعاد.',
  ),
  ExplainDateDto? date,
  ExplainCautionDto? caution,
  ExplainContactDto? contact,
  ExplainPlaceDto? place,
}) {
  return ExplainResponseDto(
    explainSchemaVersion: '1.0',
    sessionId: 'session-1',
    status: status,
    paper: const ExplainPaperDto(title: 'فاتورة الكهربا'),
    explain: explain,
    todo: todo,
    date: date,
    caution: caution,
    contact: contact,
    place: place,
  );
}

void main() {
  group('ExplainResponseMapper.toDomain', () {
    test('maps the header and the always-present cards', () {
      final explanation = _dto().toDomain();

      expect(explanation.title, 'فاتورة الكهربا');
      expect(explanation.status, PaperStatus.success);
      expect(explanation.paragraphs, ['دي ورقة من البنك.']);
      expect(explanation.todo.required, isTrue);
      expect(explanation.todo.text, 'ادفع قبل الميعاد.');
    });

    test('maps every status', () {
      const wire = {
        'success': PaperStatus.success,
        'partial': PaperStatus.partial,
        'unsupported': PaperStatus.unsupported,
      };

      for (final entry in wire.entries) {
        expect(
          _dto(status: entry.key).toDomain().status,
          entry.value,
          reason: entry.key,
        );
      }
      expect(wire.length, PaperStatus.values.length);
    });

    test('a paper with every optional card null maps to null cards', () {
      final explanation = _dto().toDomain();

      expect(explanation.date, isNull);
      expect(explanation.caution, isNull);
      expect(explanation.contact, isNull);
      expect(explanation.place, isNull);
    });

    test('maps every optional card when present', () {
      final explanation = _dto(
        date: const ExplainDateDto(
          date: '2026-11-25',
          time: '18:30',
          text: 'آخر ميعاد للدفع',
        ),
        caution: const ExplainCautionDto(text: 'بيتضاف رسم تأخير.'),
        contact: const ExplainContactDto(name: 'شركة الكهرباء', phone: '121'),
        place: const ExplainPlaceDto(text: 'شارع الجمهورية'),
      ).toDomain();

      expect(explanation.date?.day, DateTime(2026, 11, 25));
      expect(explanation.date?.time, const PaperTime(hour: 18, minute: 30));
      expect(explanation.caution?.text, 'بيتضاف رسم تأخير.');
      expect(explanation.contact?.name, 'شركة الكهرباء');
      expect(explanation.contact?.phone, '121');
      expect(explanation.place?.text, 'شارع الجمهورية');
    });

    test('keeps date.time null when the paper prints no time', () {
      final explanation = _dto(
        date: const ExplainDateDto(date: '2026-12-01', text: 'بداية العقد'),
      ).toDomain();

      expect(explanation.date?.time, isNull);
    });
  });

  group('date and time parsing', () {
    test('rejects a date that would silently roll over', () {
      for (final bad in ['2024-13-45', '2024-00-15', '2023-02-29']) {
        expect(
          () => _dto(
            date: ExplainDateDto(date: bad, text: 'نص'),
          ).toDomain(),
          throwsA(isA<ExplainMappingException>()),
          reason: bad,
        );
      }
    });

    test('rejects a malformed date or time', () {
      expect(
        () => _dto(
          date: const ExplainDateDto(date: '15/04/2024', text: 'نص'),
        ).toDomain(),
        throwsA(isA<ExplainMappingException>()),
      );
      expect(
        () => _dto(
          date: const ExplainDateDto(
            date: '2026-11-25',
            time: '25:00',
            text: 'نص',
          ),
        ).toDomain(),
        throwsA(isA<ExplainMappingException>()),
      );
    });
  });

  group('unknown wire values', () {
    test('unknown status throws rather than guessing', () {
      expect(
        () => _dto(status: 'maybe').toDomain(),
        throwsA(isA<ExplainMappingException>()),
      );
    });
  });
}
