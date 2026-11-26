import 'package:war2aty/core/documents/analysis_amount.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/analysis_warning.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/core/documents/required_action.dart';

DocumentAnalysis invoiceAnalysis({
  AnalysisStatus status = AnalysisStatus.success,
  AnalysisSummary summary = const AnalysisSummary(
    short: 'فاتورة كهرباء لازم تتدفع.',
    detailed: 'الفاتورة دي عن استهلاك شهر مارس، والمبلغ لازم يتسدد قبل الموعد.',
  ),
}) => DocumentAnalysis(
  sessionId: 'session-1',
  status: status,
  kind: DocumentKind.invoice,
  title: 'فاتورة كهرباء',
  kindConfidence: ConfidenceBand.high,
  summary: summary,
  keyInformation: const [
    KeyInformation(
      label: 'رقم الحساب',
      value: '1234',
      confidence: ConfidenceBand.high,
      source: InfoSource.extracted,
    ),
  ],
  dates: [
    AnalysisDate(
      label: 'آخر موعد للسداد',
      date: DateTime(2026, 4, 15),
      role: DateRole.deadline,
      isReminderWorthy: true,
      confidence: ConfidenceBand.high,
    ),
  ],
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
      description: 'سدد الفاتورة قبل 15 أبريل.',
      basis: ActionBasis.explicit,
      priority: ActionPriority.high,
    ),
  ],
  requiredDocuments: const ['بطاقة الرقم القومي'],
  instructions: const ['روح لأقرب فرع.'],
  warnings: const [
    AnalysisWarning(
      text: 'تأكد من صحة البيانات من الجهة الرسمية.',
      kind: WarningKind.government,
    ),
  ],
);

const DocumentAnalysis unsupportedAnalysis = DocumentAnalysis(
  sessionId: 'session-2',
  status: AnalysisStatus.unsupported,
  kind: DocumentKind.other,
  title: 'ورقة غير مدعومة',
  kindConfidence: ConfidenceBand.low,
  summary: AnalysisSummary(short: '', detailed: ''),
);
