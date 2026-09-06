import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_amount.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/analysis_warning.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_phone.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_reference.dart';

const _summary = AnalysisSummary(short: 'فاتورة كهرباء.', detailed: 'تفاصيل.');

DocumentAnalysis _analysis({
  AnalysisStatus status = AnalysisStatus.success,
  DocumentKind kind = DocumentKind.invoice,
  ConfidenceBand kindConfidence = ConfidenceBand.high,
  List<KeyInformation> keyInformation = const [],
  List<AnalysisDate> dates = const [],
  List<AnalysisAmount> amounts = const [],
  List<AnalysisPhone> phones = const [],
  List<AnalysisReference> references = const [],
  List<String> missingFields = const [],
}) {
  return DocumentAnalysis(
    sessionId: 'session-1',
    status: status,
    kind: kind,
    title: 'فاتورة كهرباء',
    kindConfidence: kindConfidence,
    summary: _summary,
    keyInformation: keyInformation,
    dates: dates,
    amounts: amounts,
    phones: phones,
    references: references,
    missingFields: missingFields,
  );
}

AnalysisDate _date({
  String label = 'آخر موعد للسداد',
  required bool isReminderWorthy,
  ConfidenceBand confidence = ConfidenceBand.high,
}) {
  return AnalysisDate(
    label: label,
    date: DateTime(2024, 4, 15),
    // Non-null on purpose: a null time silently skipped AnalysisTime from the
    // privacy audit below and let a leak through review twice.
    time: const AnalysisTime(hour: 14, minute: 30),
    role: DateRole.deadline,
    isReminderWorthy: isReminderWorthy,
    confidence: confidence,
  );
}

void main() {
  group('AnalysisTime', () {
    test('formats as zero-padded HH:mm', () {
      expect(const AnalysisTime(hour: 9, minute: 5).formatted, '09:05');
      expect(const AnalysisTime(hour: 14, minute: 30).formatted, '14:30');
      expect(const AnalysisTime(hour: 0, minute: 0).formatted, '00:00');
    });
  });

  group('DocumentKind.category', () {
    test('maps money papers to the invoice category', () {
      expect(DocumentKind.invoice.category, DocumentCategory.invoice);
      expect(DocumentKind.receipt.category, DocumentCategory.invoice);
    });

    test('maps school papers to the education category', () {
      expect(DocumentKind.exam.category, DocumentCategory.education);
      expect(DocumentKind.educational.category, DocumentCategory.education);
    });

    test('maps kinds without an MVP category to other', () {
      expect(DocumentKind.medical.category, DocumentCategory.other);
      expect(DocumentKind.legal.category, DocumentCategory.other);
      expect(DocumentKind.financial.category, DocumentCategory.other);
      expect(DocumentKind.other.category, DocumentCategory.other);
    });

    test('covers every kind', () {
      for (final kind in DocumentKind.values) {
        expect(kind.category, isA<DocumentCategory>());
      }
    });
  });

  group('DocumentAnalysis', () {
    test('exposes the category of its kind', () {
      expect(
        _analysis(kind: DocumentKind.appointment).category,
        DocumentCategory.appointment,
      );
    });

    test('isPartial is true only for the partial status', () {
      for (final status in AnalysisStatus.values) {
        expect(
          _analysis(status: status).isPartial,
          status == AnalysisStatus.partial,
          reason: '$status',
        );
      }
    });

    test('reminderCandidates keeps only reminder-worthy dates, in order', () {
      final analysis = _analysis(
        dates: [
          _date(label: 'أول', isReminderWorthy: true),
          _date(label: 'تاني', isReminderWorthy: false),
          _date(label: 'تالت', isReminderWorthy: true),
        ],
      );

      expect(analysis.reminderCandidates.map((d) => d.label), ['أول', 'تالت']);
    });

    test('reminderCandidates is empty when nothing is worth a reminder', () {
      final analysis = _analysis(dates: [_date(isReminderWorthy: false)]);

      expect(analysis.reminderCandidates, isEmpty);
    });

    test('hasUncertainFields is false when everything is high confidence', () {
      final analysis = _analysis(
        keyInformation: const [
          KeyInformation(
            label: 'رقم الحساب',
            value: '12345678',
            confidence: ConfidenceBand.high,
            source: InfoSource.extracted,
          ),
        ],
        dates: [_date(isReminderWorthy: true)],
        amounts: const [
          AnalysisAmount(
            label: 'الإجمالي',
            value: 850.5,
            currency: 'EGP',
            confidence: ConfidenceBand.high,
          ),
        ],
      );

      expect(analysis.hasUncertainFields, isFalse);
    });

    test('hasUncertainFields catches a low-confidence amount', () {
      final analysis = _analysis(
        amounts: const [
          AnalysisAmount(
            label: 'الإجمالي',
            value: 850.5,
            currency: 'EGP',
            confidence: ConfidenceBand.low,
          ),
        ],
      );

      expect(analysis.hasUncertainFields, isTrue);
    });

    test('hasUncertainFields catches a medium-confidence date', () {
      final analysis = _analysis(
        dates: [
          _date(isReminderWorthy: true, confidence: ConfidenceBand.medium),
        ],
      );

      expect(analysis.hasUncertainFields, isTrue);
    });

    test('hasUncertainFields catches an uncertain document kind', () {
      expect(
        _analysis(kindConfidence: ConfidenceBand.medium).hasUncertainFields,
        isTrue,
      );
    });

    // F13-T17: needsUserReview is phones/references' only trust signal, and
    // it must move hasUncertainFields the same way a sub-high ConfidenceBand
    // does for dates/amounts — confidence parity.
    test('hasUncertainFields catches a phone flagged for review', () {
      final analysis = _analysis(
        phones: const [
          AnalysisPhone(
            rawValue: '0100-123-4567',
            value: '01001234567',
            needsUserReview: true,
          ),
        ],
      );

      expect(analysis.hasUncertainFields, isTrue);
    });

    test('hasUncertainFields catches a reference flagged for review', () {
      final analysis = _analysis(
        references: const [
          AnalysisReference(
            rawValue: 'رقم الفاتورة 12345678',
            value: '12345678',
            needsUserReview: true,
          ),
        ],
      );

      expect(analysis.hasUncertainFields, isTrue);
    });

    test(
      'hasUncertainFields stays false when no phone/reference needs review',
      () {
        final analysis = _analysis(
          phones: const [
            AnalysisPhone(
              rawValue: '0100-123-4567',
              value: '01001234567',
              needsUserReview: false,
            ),
          ],
          references: const [
            AnalysisReference(
              rawValue: 'رقم الفاتورة 12345678',
              value: '12345678',
              needsUserReview: false,
            ),
          ],
        );

        expect(analysis.hasUncertainFields, isFalse);
      },
    );

    test('is equal by value, including its lists', () {
      final a = _analysis(
        dates: [_date(isReminderWorthy: true)],
        missingFields: const ['payer'],
      );
      final b = _analysis(
        dates: [_date(isReminderWorthy: true)],
        missingFields: const ['payer'],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differs when a list element differs', () {
      final a = _analysis(dates: [_date(label: 'أول', isReminderWorthy: true)]);
      final b = _analysis(
        dates: [_date(label: 'تاني', isReminderWorthy: true)],
      );

      expect(a, isNot(equals(b)));
    });

    test('never puts document contents in toString', () {
      final analysis = _analysis(
        keyInformation: const [
          KeyInformation(
            label: 'رقم الحساب',
            value: '12345678',
            confidence: ConfidenceBand.high,
            source: InfoSource.extracted,
          ),
        ],
        amounts: const [
          AnalysisAmount(
            label: 'الإجمالي',
            value: 850.5,
            currency: 'EGP',
            confidence: ConfidenceBand.high,
            rawValue: '850.50 جنيه',
          ),
        ],
        phones: const [
          AnalysisPhone(
            rawValue: '0100-123-4567',
            value: '01001234567',
            needsUserReview: true,
          ),
        ],
        references: const [
          AnalysisReference(
            rawValue: 'رقم الفاتورة 12345678',
            value: '12345678',
            needsUserReview: true,
          ),
        ],
      );

      // Every part reachable from the aggregate, and every part reachable
      // from those parts. Two leaks got through review by hiding one level
      // deeper than the audit reached.
      final printed = [
        analysis.toString(),
        analysis.summary.toString(),
        analysis.keyInformation.single.toString(),
        analysis.amounts.single.toString(),
        analysis.phones.single.toString(),
        analysis.references.single.toString(),
        ...analysis.dates.map((d) => d.toString()),
        ...analysis.dates.map((d) => d.time.toString()),
        ...analysis.actions.map((a) => a.toString()),
        ...analysis.warnings.map((w) => w.toString()),
      ].join(' ');

      // Values read off the paper.
      expect(printed, isNot(contains('12345678')));
      expect(printed, isNot(contains('850.5')));
      expect(
        printed,
        isNot(contains('850.50 جنيه')),
        reason: 'amount rawValue',
      );
      expect(printed, isNot(contains('فاتورة كهرباء')));
      expect(printed, isNot(contains('14:30')), reason: 'appointment time');
      expect(
        printed,
        isNot(contains('0100-123-4567')),
        reason: 'phone rawValue',
      );
      expect(printed, isNot(contains('01001234567')), reason: 'phone value');
      expect(
        printed,
        isNot(contains('رقم الفاتورة 12345678')),
        reason: 'reference rawValue',
      );
      // The summary quotes the paper.
      expect(printed, isNot(contains(_summary.short)));
      expect(printed, isNot(contains(_summary.detailed)));
      // Labels are AI-written text about this document, not fixed field names.
      expect(printed, isNot(contains('رقم الحساب')));
      expect(printed, isNot(contains('الإجمالي')));
      expect(printed, isNot(contains('آخر موعد للسداد')));
    });
  });

  group('AnalysisDate/AnalysisAmount rawValue', () {
    test('AnalysisDate is equal by value, including rawValue', () {
      AnalysisDate withRawValue(String? rawValue) => AnalysisDate(
        label: 'آخر موعد للسداد',
        date: DateTime(2024, 4, 15),
        role: DateRole.deadline,
        isReminderWorthy: true,
        confidence: ConfidenceBand.high,
        rawValue: rawValue,
      );

      final a = withRawValue('15/4/2024');
      final b = withRawValue('15/4/2024');
      final c = withRawValue('different text');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('AnalysisAmount is equal by value, including rawValue', () {
      const a = AnalysisAmount(
        label: 'الإجمالي',
        value: 850.5,
        currency: 'EGP',
        confidence: ConfidenceBand.high,
        rawValue: '850.50 جنيه',
      );
      const b = AnalysisAmount(
        label: 'الإجمالي',
        value: 850.5,
        currency: 'EGP',
        confidence: ConfidenceBand.high,
        rawValue: '850.50 جنيه',
      );
      const c = AnalysisAmount(
        label: 'الإجمالي',
        value: 850.5,
        currency: 'EGP',
        confidence: ConfidenceBand.high,
        rawValue: 'different text',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('rawValue defaults to null when inferred rather than read', () {
      expect(_date(isReminderWorthy: true).rawValue, isNull);
      expect(
        const AnalysisAmount(
          label: 'الإجمالي',
          value: 1,
          currency: 'EGP',
          confidence: ConfidenceBand.high,
        ).rawValue,
        isNull,
      );
    });
  });

  group('AnalysisPhone', () {
    test('is equal by value', () {
      const a = AnalysisPhone(
        rawValue: '0100-123-4567',
        value: '01001234567',
        needsUserReview: false,
      );
      const b = AnalysisPhone(
        rawValue: '0100-123-4567',
        value: '01001234567',
        needsUserReview: false,
      );
      const c = AnalysisPhone(
        rawValue: '0100-123-4567',
        value: '01001234567',
        needsUserReview: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('never puts rawValue or value in toString', () {
      const phone = AnalysisPhone(
        rawValue: '0100-123-4567',
        value: '01001234567',
        needsUserReview: true,
      );

      expect(phone.toString(), isNot(contains('0100-123-4567')));
      expect(phone.toString(), isNot(contains('01001234567')));
    });
  });

  group('AnalysisReference', () {
    test('is equal by value', () {
      const a = AnalysisReference(
        rawValue: 'رقم الفاتورة 12345678',
        value: '12345678',
        needsUserReview: false,
      );
      const b = AnalysisReference(
        rawValue: 'رقم الفاتورة 12345678',
        value: '12345678',
        needsUserReview: false,
      );
      const c = AnalysisReference(
        rawValue: 'رقم الفاتورة 12345678',
        value: '12345678',
        needsUserReview: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('never puts rawValue or value in toString', () {
      const reference = AnalysisReference(
        rawValue: 'رقم الفاتورة 12345678',
        value: '12345678',
        needsUserReview: true,
      );

      expect(reference.toString(), isNot(contains('رقم الفاتورة 12345678')));
      expect(reference.toString(), isNot(contains('12345678')));
    });
  });

  group('AnalysisWarning', () {
    test('is equal by value', () {
      const a = AnalysisWarning(text: 'راجع الأصل.', kind: WarningKind.general);
      const b = AnalysisWarning(text: 'راجع الأصل.', kind: WarningKind.general);
      const c = AnalysisWarning(text: 'راجع الأصل.', kind: WarningKind.medical);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
