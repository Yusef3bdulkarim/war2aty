import '../database/app_database.dart';
import '../database/daos/documents_dao.dart';
import '../database/tables/document_tables.dart';
import 'analysis_amount.dart';
import 'analysis_date.dart';
import 'analysis_status.dart';
import 'analysis_summary.dart';
import 'analysis_warning.dart';
import 'confidence_band.dart';
import 'document_analysis.dart';
import 'document_kind.dart';
import 'key_information.dart';
import 'recent_document.dart';
import 'required_action.dart';
import 'saved_document.dart';

/// Turns a stored row back into the little a list row needs.
///
/// The reverse of [documentWriteOf] (`document_write_mapper.dart`), but far
/// smaller: [RecentDocument] carries only what Home's strip and the documents
/// list (F08-T05) show, so nothing else on [row] is read here.
RecentDocument recentDocumentOf(DocumentRow row) => RecentDocument(
  id: row.id,
  title: row.title,
  category: row.category,
  storageMode: row.storageMode,
  savedAt: row.savedAt,
);

/// Turns a stored [DocumentBundle] back into the whole document the details
/// screen shows (F08-T08).
///
/// The reverse of [documentWriteOf], over every child table instead of just
/// the one row [recentDocumentOf] reads.
///
/// Enum columns are read back by name rather than parsed strictly: `core/
/// database` stores them as plain text so it need not import a feature's
/// domain (see `Documents`), and a value that no longer matches any member —
/// a row written by an older app version whose enum has since changed —
/// degrades to a safe default here rather than throwing and breaking the
/// details screen over one stored document.
SavedDocument savedDocumentOf(DocumentBundle bundle) {
  final row = bundle.document;

  return SavedDocument(
    id: row.id,
    analysis: DocumentAnalysis(
      sessionId: row.sessionId,
      status: _enumOf(
        AnalysisStatus.values,
        row.status,
        AnalysisStatus.partial,
      ),
      kind: _enumOf(DocumentKind.values, row.kind, DocumentKind.other),
      title: row.title,
      kindConfidence: _confidenceOf(row.kindConfidence),
      summary: AnalysisSummary(
        short: row.summaryShort,
        detailed: row.summaryDetailed,
      ),
      keyInformation: [
        for (final info in bundle.keyInformation)
          KeyInformation(
            label: info.label,
            value: info.value,
            confidence: _confidenceOf(info.confidence),
            source: _enumOf(
              InfoSource.values,
              info.source,
              InfoSource.inferred,
            ),
          ),
      ],
      dates: [
        for (final date in bundle.dates)
          AnalysisDate(
            label: date.label,
            date: date.date,
            time: _timeOf(date.minuteOfDay),
            role: _enumOf(DateRole.values, date.role, DateRole.event),
            isReminderWorthy: date.isReminderWorthy,
            confidence: _confidenceOf(date.confidence),
          ),
      ],
      amounts: [
        for (final amount in bundle.amounts)
          AnalysisAmount(
            label: amount.label,
            value: amount.value,
            currency: amount.currency,
            confidence: _confidenceOf(amount.confidence),
          ),
      ],
      actions: [
        for (final action in bundle.actions)
          RequiredAction(
            description: action.description,
            basis: _enumOf(
              ActionBasis.values,
              action.basis,
              ActionBasis.inferred,
            ),
            priority: _enumOf(
              ActionPriority.values,
              action.priority,
              ActionPriority.normal,
            ),
          ),
      ],
      requiredDocuments: bundle.textItemsOf(
        DocumentTextItemKind.requiredDocument,
      ),
      instructions: bundle.textItemsOf(DocumentTextItemKind.instruction),
      warnings: [
        for (final warning in bundle.warnings)
          AnalysisWarning(
            text: warning.message,
            kind: _enumOf(
              WarningKind.values,
              warning.kind,
              WarningKind.general,
            ),
          ),
      ],
      missingFields: bundle.textItemsOf(DocumentTextItemKind.missingField),
    ),
    extractedText: row.extractedText,
    storageMode: row.storageMode,
    note: row.note,
    savedAt: row.savedAt,
    updatedAt: row.updatedAt,
  );
}

ConfidenceBand _confidenceOf(String raw) =>
    _enumOf(ConfidenceBand.values, raw, ConfidenceBand.low);

/// Reads an enum back by its stored [Enum.name], falling back to [fallback]
/// instead of throwing — see [savedDocumentOf].
T _enumOf<T extends Enum>(List<T> values, String raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

/// The reverse of the `hour * 60 + minute` [documentWriteOf] writes. `null`
/// stays `null` — the paper gave no time, not midnight.
AnalysisTime? _timeOf(int? minuteOfDay) => minuteOfDay == null
    ? null
    : AnalysisTime(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60);
