import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_warning.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/core/documents/required_action.dart';
import 'package:war2aty/features/analysis/data/mappers/analysis_response_mapper.dart';
import 'package:war2aty/features/analysis/data/models/action_item_dto.dart';
import 'package:war2aty/features/analysis/data/models/amount_item_dto.dart';
import 'package:war2aty/features/analysis/data/models/analysis_response_dto.dart';
import 'package:war2aty/features/analysis/data/models/date_item_dto.dart';
import 'package:war2aty/features/analysis/data/models/document_type_dto.dart';
import 'package:war2aty/features/analysis/data/models/key_info_item_dto.dart';
import 'package:war2aty/features/analysis/data/models/summary_dto.dart';
import 'package:war2aty/features/analysis/data/models/warning_item_dto.dart';

AnalysisResponseDto _dto({
  String status = 'success',
  DocumentTypeDto? documentType,
  List<KeyInfoItemDto> keyInformation = const [],
  List<DateItemDto> dates = const [],
  List<AmountItemDto> amounts = const [],
  List<ActionItemDto> actionsRequired = const [],
  List<String> requiredDocuments = const [],
  List<String> instructions = const [],
  List<WarningItemDto> warnings = const [],
  List<String> missingFields = const [],
}) {
  return AnalysisResponseDto(
    schemaVersion: '1.0',
    sessionId: 'session-1',
    status: status,
    documentType:
        documentType ??
        const DocumentTypeDto(
          type: 'invoice',
          title: 'فاتورة كهرباء',
          confidence: 'high',
        ),
    summary: const SummaryDto(short: 'قصير.', detailed: 'تفصيلي.'),
    keyInformation: keyInformation,
    dates: dates,
    amounts: amounts,
    actionsRequired: actionsRequired,
    requiredDocuments: requiredDocuments,
    instructions: instructions,
    warnings: warnings,
    missingFields: missingFields,
  );
}

DateItemDto _dateItem({
  String date = '2024-04-15',
  String? time = '14:30',
  String role = 'deadline',
  String confidence = 'high',
}) {
  return DateItemDto(
    label: 'آخر موعد للسداد',
    date: date,
    time: time,
    role: role,
    isReminderWorthy: true,
    confidence: confidence,
  );
}

void main() {
  group('AnalysisResponseMapper.toDomain', () {
    test('maps the envelope and summary', () {
      final analysis = _dto(
        requiredDocuments: const ['بطاقة الرقم القومي'],
        instructions: const ['توجه لأقرب فرع.'],
        missingFields: const ['payer'],
      ).toDomain();

      expect(analysis.sessionId, 'session-1');
      expect(analysis.status, AnalysisStatus.success);
      expect(analysis.kind, DocumentKind.invoice);
      expect(analysis.title, 'فاتورة كهرباء');
      expect(analysis.kindConfidence, ConfidenceBand.high);
      expect(analysis.summary.short, 'قصير.');
      expect(analysis.summary.detailed, 'تفصيلي.');
      expect(analysis.requiredDocuments, ['بطاقة الرقم القومي']);
      expect(analysis.instructions, ['توجه لأقرب فرع.']);
      expect(analysis.missingFields, ['payer']);
    });

    test('maps every status', () {
      const wire = {
        'success': AnalysisStatus.success,
        'partial': AnalysisStatus.partial,
        'unsupported': AnalysisStatus.unsupported,
      };

      for (final entry in wire.entries) {
        expect(
          _dto(status: entry.key).toDomain().status,
          entry.value,
          reason: entry.key,
        );
      }
      expect(wire.length, AnalysisStatus.values.length);
    });

    test('maps every document kind', () {
      const wire = {
        'invoice': DocumentKind.invoice,
        'receipt': DocumentKind.receipt,
        'appointment': DocumentKind.appointment,
        'government': DocumentKind.government,
        'exam': DocumentKind.exam,
        'medical': DocumentKind.medical,
        'legal': DocumentKind.legal,
        'financial': DocumentKind.financial,
        'educational': DocumentKind.educational,
        'other': DocumentKind.other,
      };

      for (final entry in wire.entries) {
        final analysis = _dto(
          documentType: DocumentTypeDto(
            type: entry.key,
            title: 'عنوان',
            confidence: 'high',
          ),
        ).toDomain();

        expect(analysis.kind, entry.value, reason: entry.key);
      }
      expect(wire.length, DocumentKind.values.length);
    });

    test('maps every date role', () {
      const wire = {
        'deadline': DateRole.deadline,
        'appointment': DateRole.appointment,
        'issued': DateRole.issued,
        'expiry': DateRole.expiry,
        'event': DateRole.event,
        'period_start': DateRole.periodStart,
        'period_end': DateRole.periodEnd,
      };

      for (final entry in wire.entries) {
        final analysis = _dto(dates: [_dateItem(role: entry.key)]).toDomain();

        expect(analysis.dates.single.role, entry.value, reason: entry.key);
      }
      expect(wire.length, DateRole.values.length);
    });

    test('maps every warning kind', () {
      const wire = {
        'medical': WarningKind.medical,
        'legal': WarningKind.legal,
        'government': WarningKind.government,
        'financial': WarningKind.financial,
        'general': WarningKind.general,
      };

      for (final entry in wire.entries) {
        final analysis = _dto(
          warnings: [WarningItemDto(text: 'تنبيه', type: entry.key)],
        ).toDomain();

        expect(analysis.warnings.single.kind, entry.value, reason: entry.key);
      }
      expect(wire.length, WarningKind.values.length);
    });

    test('maps key information with its source', () {
      final analysis = _dto(
        keyInformation: const [
          KeyInfoItemDto(
            label: 'رقم الحساب',
            value: '12345678',
            confidence: 'medium',
            source: 'extracted',
          ),
          KeyInfoItemDto(
            label: 'المستهلك',
            value: 'أحمد',
            confidence: 'low',
            source: 'inferred',
          ),
        ],
      ).toDomain();

      expect(analysis.keyInformation.first.value, '12345678');
      expect(analysis.keyInformation.first.confidence, ConfidenceBand.medium);
      expect(analysis.keyInformation.first.source, InfoSource.extracted);
      expect(analysis.keyInformation.last.source, InfoSource.inferred);
    });

    test('maps amounts and actions', () {
      final analysis = _dto(
        amounts: const [
          AmountItemDto(
            label: 'الإجمالي',
            value: 850.5,
            currency: 'EGP',
            confidence: 'high',
          ),
        ],
        actionsRequired: const [
          ActionItemDto(
            description: 'سدد الفاتورة.',
            basis: 'explicit',
            priority: 'high',
          ),
        ],
      ).toDomain();

      expect(analysis.amounts.single.value, 850.5);
      expect(analysis.amounts.single.currency, 'EGP');
      expect(analysis.actions.single.basis, ActionBasis.explicit);
      expect(analysis.actions.single.priority, ActionPriority.high);
    });

    test('leaves empty wire lists empty', () {
      final analysis = _dto().toDomain();

      expect(analysis.keyInformation, isEmpty);
      expect(analysis.dates, isEmpty);
      expect(analysis.amounts, isEmpty);
      expect(analysis.actions, isEmpty);
      expect(analysis.warnings, isEmpty);
      expect(analysis.missingFields, isEmpty);
    });
  });

  group('date and time parsing', () {
    test('parses a date to local midnight', () {
      final analysis = _dto(dates: [_dateItem(date: '2025-01-09')]).toDomain();

      expect(analysis.dates.single.date, DateTime(2025, 1, 9));
    });

    test('parses HH:mm, and keeps a missing time null', () {
      final withTime = _dto(dates: [_dateItem(time: '09:05')]).toDomain();
      final withoutTime = _dto(dates: [_dateItem(time: null)]).toDomain();

      expect(
        withTime.dates.single.time,
        const AnalysisTime(hour: 9, minute: 5),
      );
      expect(withoutTime.dates.single.time, isNull);
    });

    test('rejects a date that would silently roll over', () {
      // DateTime.parse turns each of these into a plausible-looking wrong
      // date rather than failing: 2025-02-14, 2023-12-15, 2023-12-31,
      // 2023-03-01. A wrong deadline is worse than no result.
      for (final bad in [
        '2024-13-45',
        '2024-00-15',
        '2024-01-00',
        '2023-02-29',
      ]) {
        expect(
          () => _dto(dates: [_dateItem(date: bad)]).toDomain(),
          throwsA(isA<AnalysisMappingException>()),
          reason: bad,
        );
      }
    });

    test('accepts a real leap day', () {
      final analysis = _dto(dates: [_dateItem(date: '2024-02-29')]).toDomain();

      expect(analysis.dates.single.date, DateTime(2024, 2, 29));
    });

    test('rejects a malformed date', () {
      for (final bad in ['15/04/2024', '2024-4-15', '', 'tomorrow']) {
        expect(
          () => _dto(dates: [_dateItem(date: bad)]).toDomain(),
          throwsA(isA<AnalysisMappingException>()),
          reason: bad,
        );
      }
    });

    test('rejects a malformed time', () {
      for (final bad in ['25:00', '14:60', '2:30 PM', '1430']) {
        expect(
          () => _dto(dates: [_dateItem(time: bad)]).toDomain(),
          throwsA(isA<AnalysisMappingException>()),
          reason: bad,
        );
      }
    });
  });

  group('unknown wire values', () {
    test('unknown document kind falls back to other', () {
      final analysis = _dto(
        documentType: const DocumentTypeDto(
          type: 'spaceship_manual',
          title: 'عنوان',
          confidence: 'high',
        ),
      ).toDomain();

      expect(analysis.kind, DocumentKind.other);
    });

    test('unknown warning kind falls back to general', () {
      final analysis = _dto(
        warnings: const [WarningItemDto(text: 'تنبيه', type: 'astrological')],
      ).toDomain();

      expect(analysis.warnings.single.kind, WarningKind.general);
    });

    test('unknown confidence falls back to low, never high', () {
      final analysis = _dto(
        documentType: const DocumentTypeDto(
          type: 'invoice',
          title: 'عنوان',
          confidence: 'very-sure',
        ),
        keyInformation: const [
          KeyInfoItemDto(
            label: 'رقم',
            value: '1',
            confidence: 'probably',
            source: 'extracted',
          ),
        ],
        amounts: const [
          AmountItemDto(
            label: 'الإجمالي',
            value: 1,
            currency: 'EGP',
            confidence: '',
          ),
        ],
      ).toDomain();

      expect(analysis.kindConfidence, ConfidenceBand.low);
      expect(analysis.keyInformation.single.confidence, ConfidenceBand.low);
      expect(analysis.amounts.single.confidence, ConfidenceBand.low);
    });

    test('unknown source and basis fall back to inferred', () {
      final analysis = _dto(
        keyInformation: const [
          KeyInfoItemDto(
            label: 'رقم',
            value: '1',
            confidence: 'high',
            source: 'guessed',
          ),
        ],
        actionsRequired: const [
          ActionItemDto(
            description: 'افعل كذا.',
            basis: 'assumed',
            priority: 'urgent',
          ),
        ],
      ).toDomain();

      expect(analysis.keyInformation.single.source, InfoSource.inferred);
      expect(analysis.actions.single.basis, ActionBasis.inferred);
      expect(analysis.actions.single.priority, ActionPriority.normal);
    });

    test('unknown status throws rather than guessing', () {
      expect(
        () => _dto(status: 'maybe').toDomain(),
        throwsA(isA<AnalysisMappingException>()),
      );
    });

    test('unknown date role throws rather than downgrading a deadline', () {
      expect(
        () => _dto(dates: [_dateItem(role: 'reminder')]).toDomain(),
        throwsA(isA<AnalysisMappingException>()),
      );
    });
  });

  group('AnalysisMappingException', () {
    test('names the offending field with its index', () {
      Object? caught;
      try {
        _dto(
          dates: [
            _dateItem(),
            _dateItem(role: 'nonsense'),
          ],
        ).toDomain();
      } on AnalysisMappingException catch (e) {
        caught = e;
      }

      expect(caught, isA<AnalysisMappingException>());
      expect((caught! as AnalysisMappingException).field, 'dates[1].role');
    });

    test('never carries the offending value', () {
      Object? caught;
      try {
        _dto(dates: [_dateItem(date: '99/99/9999')]).toDomain();
      } on AnalysisMappingException catch (e) {
        caught = e;
      }

      expect(caught.toString(), isNot(contains('99/99/9999')));
      expect(caught.toString(), contains('dates[0].date'));
    });
  });
}
