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

const _summary = AnalysisSummary(short: 'فاتورة كهرباء.', detailed: 'تفاصيل.');

DocumentAnalysis _analysis({
  AnalysisStatus status = AnalysisStatus.success,
  DocumentKind kind = DocumentKind.invoice,
  ConfidenceBand kindConfidence = ConfidenceBand.high,
  List<KeyInformation> keyInformation = const [],
  List<AnalysisDate> dates = const [],
  List<AnalysisAmount> amounts = const [],
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
        ...analysis.dates.map((d) => d.toString()),
        ...analysis.dates.map((d) => d.time.toString()),
        ...analysis.actions.map((a) => a.toString()),
        ...analysis.warnings.map((w) => w.toString()),
      ].join(' ');

      // Values read off the paper.
      expect(printed, isNot(contains('12345678')));
      expect(printed, isNot(contains('850.5')));
      expect(printed, isNot(contains('فاتورة كهرباء')));
      expect(printed, isNot(contains('14:30')), reason: 'appointment time');
      // The summary quotes the paper.
      expect(printed, isNot(contains(_summary.short)));
      expect(printed, isNot(contains(_summary.detailed)));
      // Labels are AI-written text about this document, not fixed field names.
      expect(printed, isNot(contains('رقم الحساب')));
      expect(printed, isNot(contains('الإجمالي')));
      expect(printed, isNot(contains('آخر موعد للسداد')));
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
