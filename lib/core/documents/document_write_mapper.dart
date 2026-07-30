import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/daos/documents_dao.dart';
import 'analysis_date.dart';
import 'document_analysis.dart';
import 'recent_document.dart';

/// Turns an understood paper into the rows that keep it.
///
/// Every enum is written by name — `kind.name`, `confidence.name` — because
/// those columns are plain text on purpose (see [Documents]); the reader maps
/// them back. Positions are left to the DAO, which numbers each list by the
/// order it arrives in.
///
/// Result-only by default: [storageMode] is [DocumentStorageMode.resultOnly]
/// and `encryptedImagePath` is never set here. Keeping the picture is a
/// separate, explicit step (F08-T04) — the privacy default cannot be reached
/// by forgetting to pass something.
DocumentWrite documentWriteOf({
  required String id,
  required DocumentAnalysis analysis,
  required String extractedText,
  required DateTime savedAt,
}) {
  return DocumentWrite(
    document: DocumentsCompanion.insert(
      id: id,
      title: analysis.title,
      category: analysis.category,
      kind: analysis.kind.name,
      status: analysis.status.name,
      kindConfidence: analysis.kindConfidence.name,
      summaryShort: analysis.summary.short,
      summaryDetailed: analysis.summary.detailed,
      extractedText: extractedText,
      storageMode: DocumentStorageMode.resultOnly,
      sessionId: analysis.sessionId,
      savedAt: savedAt,
      updatedAt: savedAt,
    ),
    keyInformation: [
      for (final info in analysis.keyInformation)
        DocumentKeyInformationCompanion.insert(
          documentId: id,
          position: 0,
          label: info.label,
          value: info.value,
          confidence: info.confidence.name,
          source: info.source.name,
        ),
    ],
    dates: [
      for (final date in analysis.dates)
        DocumentDatesCompanion.insert(
          documentId: id,
          position: 0,
          label: date.label,
          date: date.date,
          minuteOfDay: Value(_minuteOfDay(date.time)),
          role: date.role.name,
          isReminderWorthy: date.isReminderWorthy,
          confidence: date.confidence.name,
        ),
    ],
    amounts: [
      for (final amount in analysis.amounts)
        DocumentAmountsCompanion.insert(
          documentId: id,
          position: 0,
          label: amount.label,
          value: amount.value,
          currency: amount.currency,
          confidence: amount.confidence.name,
        ),
    ],
    actions: [
      for (final action in analysis.actions)
        DocumentActionsCompanion.insert(
          documentId: id,
          position: 0,
          description: action.description,
          basis: action.basis.name,
          priority: action.priority.name,
        ),
    ],
    warnings: [
      for (final warning in analysis.warnings)
        DocumentWarningsCompanion.insert(
          documentId: id,
          position: 0,
          message: warning.text,
          kind: warning.kind.name,
        ),
    ],
    requiredDocuments: analysis.requiredDocuments,
    instructions: analysis.instructions,
    missingFields: analysis.missingFields,
  );
}

/// A time of day as minutes since midnight, or `null` when the paper gave
/// none. Never defaulted to zero: "no time on the paper" and "midnight" mean
/// different things to a reminder.
int? _minuteOfDay(AnalysisTime? time) =>
    time == null ? null : time.hour * 60 + time.minute;
