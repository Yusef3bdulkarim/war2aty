import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/daos/documents_dao.dart';
import 'package:war2aty/core/documents/analysis_amount.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/analysis_warning.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/document_write_mapper.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/documents/required_action.dart';

void main() {
  final savedAt = DateTime(2026, 7, 29, 14, 30);

  DocumentWrite write({DocumentAnalysis? analysis, String text = 'نص'}) {
    return documentWriteOf(
      id: 'doc-1',
      analysis: analysis ?? _analysis(),
      extractedText: text,
      savedAt: savedAt,
    );
  }

  group('the document row', () {
    test('carries the analysis header', () {
      final row = write().document;

      expect(row.id.value, 'doc-1');
      expect(row.title.value, 'فاتورة كهرباء');
      expect(row.category.value, DocumentCategory.invoice);
      expect(row.kind.value, 'invoice');
      expect(row.status.value, 'success');
      expect(row.kindConfidence.value, 'high');
    });

    test('carries both summaries and the text they came from', () {
      final row = write(text: 'شركة الكهرباء').document;

      expect(row.summaryShort.value, 'فاتورة عليك تسددها');
      expect(row.summaryDetailed.value, 'الفاتورة دي عن شهر يوليو.');
      expect(row.extractedText.value, 'شركة الكهرباء');
    });

    test('stamps savedAt and updatedAt with the same instant', () {
      final row = write().document;

      expect(row.savedAt.value, savedAt);
      expect(row.updatedAt.value, savedAt);
    });

    test('is result-only, with no image path', () {
      final row = write().document;

      expect(row.storageMode.value, DocumentStorageMode.resultOnly);
      expect(row.encryptedImagePath.present, isFalse);
    });

    test('keeps the session it came from', () {
      expect(write().document.sessionId.value, 'session-1');
    });
  });

  group('the child rows', () {
    test('carry key information with its confidence and source', () {
      final info = write().keyInformation.single;

      expect(info.label.value, 'رقم الحساب');
      expect(info.value.value, '12345');
      expect(info.confidence.value, 'medium');
      expect(info.source.value, 'extracted');
    });

    test('carry a date, its role and its reminder hint', () {
      final date = write().dates.single;

      expect(date.label.value, 'آخر موعد للسداد');
      expect(date.date.value, DateTime(2026, 8, 15));
      expect(date.role.value, 'deadline');
      expect(date.isReminderWorthy.value, isTrue);
      expect(date.confidence.value, 'high');
    });

    test('write a time of day as minutes since midnight', () {
      final analysis = _analysis(
        dates: [_date(time: const AnalysisTime(hour: 9, minute: 30))],
      );

      expect(write(analysis: analysis).dates.single.minuteOfDay.value, 570);
    });

    test('leave the time absent when the paper gave none', () {
      expect(write().dates.single.minuteOfDay.value, isNull);
    });

    test('carry an amount with its currency', () {
      final amount = write().amounts.single;

      expect(amount.label.value, 'إجمالي المبلغ');
      expect(amount.value.value, 250.5);
      expect(amount.currency.value, 'EGP');
    });

    test('carry an action with its basis and priority', () {
      final action = write().actions.single;

      expect(action.description.value, 'سدد الفاتورة');
      expect(action.basis.value, 'explicit');
      expect(action.priority.value, 'high');
    });

    test('carry a warning under `message`', () {
      final warning = write().warnings.single;

      expect(warning.message.value, 'راجع الجهة');
      expect(warning.kind.value, 'financial');
    });

    test('keep the three plain-text lists apart', () {
      final result = write();

      expect(result.requiredDocuments, ['بطاقة الرقم القومي']);
      expect(result.instructions, ['روح لأقرب فرع']);
      expect(result.missingFields, ['dueDate']);
    });
  });

  group('an analysis with nothing in its lists', () {
    test('produces a document and no children', () {
      final result = write(analysis: _bareAnalysis());

      expect(result.document.title.value, 'ورقة');
      expect(result.keyInformation, isEmpty);
      expect(result.dates, isEmpty);
      expect(result.amounts, isEmpty);
      expect(result.actions, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.requiredDocuments, isEmpty);
      expect(result.instructions, isEmpty);
      expect(result.missingFields, isEmpty);
    });
  });

  group('a partial analysis', () {
    test('keeps its status and its missing fields', () {
      final analysis = _analysis(status: AnalysisStatus.partial);
      final result = write(analysis: analysis);

      expect(result.document.status.value, 'partial');
      expect(result.missingFields, ['dueDate']);
    });
  });
}

AnalysisDate _date({AnalysisTime? time}) => AnalysisDate(
  label: 'آخر موعد للسداد',
  date: DateTime(2026, 8, 15),
  time: time,
  role: DateRole.deadline,
  isReminderWorthy: true,
  confidence: ConfidenceBand.high,
);

DocumentAnalysis _analysis({
  AnalysisStatus status = AnalysisStatus.success,
  List<AnalysisDate>? dates,
}) {
  return DocumentAnalysis(
    sessionId: 'session-1',
    status: status,
    kind: DocumentKind.invoice,
    title: 'فاتورة كهرباء',
    kindConfidence: ConfidenceBand.high,
    summary: const AnalysisSummary(
      short: 'فاتورة عليك تسددها',
      detailed: 'الفاتورة دي عن شهر يوليو.',
    ),
    keyInformation: const [
      KeyInformation(
        label: 'رقم الحساب',
        value: '12345',
        confidence: ConfidenceBand.medium,
        source: InfoSource.extracted,
      ),
    ],
    dates: dates ?? [_date()],
    amounts: const [
      AnalysisAmount(
        label: 'إجمالي المبلغ',
        value: 250.5,
        currency: 'EGP',
        confidence: ConfidenceBand.high,
      ),
    ],
    actions: const [
      RequiredAction(
        description: 'سدد الفاتورة',
        basis: ActionBasis.explicit,
        priority: ActionPriority.high,
      ),
    ],
    requiredDocuments: const ['بطاقة الرقم القومي'],
    instructions: const ['روح لأقرب فرع'],
    warnings: const [
      AnalysisWarning(text: 'راجع الجهة', kind: WarningKind.financial),
    ],
    missingFields: const ['dueDate'],
  );
}

DocumentAnalysis _bareAnalysis() => const DocumentAnalysis(
  sessionId: 'session-1',
  status: AnalysisStatus.success,
  kind: DocumentKind.other,
  title: 'ورقة',
  kindConfidence: ConfidenceBand.low,
  summary: AnalysisSummary(short: 'ورقة', detailed: 'مش واضح.'),
);
