import 'package:drift/drift.dart';

import '../../documents/document_category.dart';
import '../../documents/recent_document.dart';

/// Which of a document's plain-text lists a row belongs to.
///
/// `requiredDocuments`, `instructions` and `missingFields` are three lists of
/// bare strings on the analysis. They share one table rather than three
/// identical ones; this column says which list a row came from so the mapper
/// can split them apart again.
enum DocumentTextItemKind {
  /// A paper the user has to bring along — «المستندات المطلوبة».
  requiredDocument,

  /// One step of the guidance — «الخطوات».
  instruction,

  /// A field the analysis could not resolve; drives the partial banner.
  missingField,
}

/// A paper the user chose to keep.
///
/// One row per saved document, holding what the analysis understood about it
/// plus how much of it was kept. The lists it produced (key information,
/// dates, amounts, …) live in the child tables below, each cascading on
/// delete so removing a document cannot leave its details behind.
///
/// Privacy (CLAUDE.md §7): rows never leave the device. [encryptedImagePath]
/// points at a file inside the app's private directory that is encrypted at
/// rest (F08-T03/T04); the plaintext picture is deleted after encryption and
/// the key lives in secure storage, never here. The AES-GCM nonce is written
/// into the file's own header, so it needs no column.
///
/// Enum columns: [category] and [storageMode] are stored by name and read back
/// as enums — both live in `core/` and the list screen filters on them.
/// [kind], [status] and [kindConfidence] are analysis vocabulary and stay
/// plain text: `core/database` must not import a feature's domain, and a
/// stored string that no longer parses is a mapper concern the feature can
/// degrade gracefully rather than a read that throws.
@DataClassName('DocumentRow')
@TableIndex(name: 'documents_saved_at', columns: {#savedAt})
@TableIndex(name: 'documents_category', columns: {#category})
class Documents extends Table {
  /// Client-generated identifier — also what F09 links a reminder to.
  TextColumn get id => text()();

  /// Arabic display title, editable by the user (F08-T10).
  TextColumn get title => text()();

  /// Coarse category behind Home's recent strip and the list filters.
  TextColumn get category => textEnum<DocumentCategory>()();

  /// `DocumentKind` name, e.g. `invoice`.
  TextColumn get kind => text()();

  /// `AnalysisStatus` name — `partial` still shows the review banner on a
  /// saved document, exactly as it did on the result screen.
  TextColumn get status => text()();

  /// `ConfidenceBand` name for [kind] and [title].
  TextColumn get kindConfidence => text()();

  /// One-line «الخلاصة السريعة».
  TextColumn get summaryShort => text()();

  /// The full explanation, also what the audio reader speaks.
  TextColumn get summaryDetailed => text()();

  /// The normalized OCR text the analysis was built from (UX §5.12).
  TextColumn get extractedText => text()();

  /// Result-only or result-plus-image. The default is result-only.
  TextColumn get storageMode => textEnum<DocumentStorageMode>()();

  /// Path to the encrypted picture, or `null` in result-only mode.
  TextColumn get encryptedImagePath => text().nullable()();

  /// The user's own note — «ملاحظتي» (F08-T09). `null` until they write one.
  TextColumn get note => text().nullable()();

  /// The capture session this came from. A per-run id, not a user identifier.
  TextColumn get sessionId => text()();

  DateTimeColumn get savedAt => dateTime()();

  /// Last edit to title, category, note or stored image.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One labelled fact read off a document — «المعلومات المهمة».
///
/// [position] preserves the order the analysis reported, so the details screen
/// reads the same as the result screen did.
@DataClassName('DocumentInfoRow')
class DocumentKeyInformation extends Table {
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  TextColumn get label => text()();
  TextColumn get value => text()();

  /// `ConfidenceBand` name — confidence is per field, never per document.
  TextColumn get confidence => text()();

  /// `InfoSource` name: read off the paper, or worked out by the analysis.
  TextColumn get source => text()();

  @override
  Set<Column<Object>> get primaryKey => {documentId, position};
}

/// A date found on a document, and whether it is worth a reminder.
@DataClassName('DocumentDateRow')
class DocumentDates extends Table {
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  TextColumn get label => text()();

  /// The calendar day, at local midnight.
  DateTimeColumn get date => dateTime()();

  /// Time of day as minutes since midnight, or `null` when the paper gave a
  /// day but no hour. The distinction is load-bearing: a reminder on a date
  /// with no time has to ask the user rather than invent one, so "no time" is
  /// stored as absent and never as `00:00`.
  IntColumn get minuteOfDay => integer().nullable()();

  /// `DateRole` name — deadline, appointment, expiry, …
  TextColumn get role => text()();

  /// What the analysis suggested. Nothing is ever scheduled off this alone.
  BoolColumn get isReminderWorthy => boolean()();

  /// `ConfidenceBand` name.
  TextColumn get confidence => text()();

  @override
  Set<Column<Object>> get primaryKey => {documentId, position};
}

/// A money figure read off a document.
@DataClassName('DocumentAmountRow')
class DocumentAmounts extends Table {
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  TextColumn get label => text()();
  RealColumn get value => real()();

  /// Currency code as the analysis reported it, e.g. `EGP`.
  TextColumn get currency => text()();

  /// `ConfidenceBand` name.
  TextColumn get confidence => text()();

  @override
  Set<Column<Object>> get primaryKey => {documentId, position};
}

/// Something the user has to do about a document — «المطلوب منك».
@DataClassName('DocumentActionRow')
class DocumentActions extends Table {
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  TextColumn get description => text()();

  /// `ActionBasis` name: written on the paper, or inferred.
  TextColumn get basis => text()();

  /// `ActionPriority` name.
  TextColumn get priority => text()();

  @override
  Set<Column<Object>> get primaryKey => {documentId, position};
}

/// A disclaimer shown alongside a document.
@DataClassName('DocumentWarningRow')
class DocumentWarnings extends Table {
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  /// Arabic warning copy, ready to display. Named `message` rather than
  /// `text` because `text` is [Table]'s own column builder.
  TextColumn get message => text()();

  /// `WarningKind` name — drives the icon and tone.
  TextColumn get kind => text()();

  @override
  Set<Column<Object>> get primaryKey => {documentId, position};
}

/// One entry of a document's required-documents, instructions or
/// missing-fields list. See [DocumentTextItemKind].
@DataClassName('DocumentTextItemRow')
class DocumentTextItems extends Table {
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();

  /// Which list this row belongs to.
  TextColumn get kind => textEnum<DocumentTextItemKind>()();

  /// Order within that list.
  IntColumn get position => integer()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {documentId, kind, position};
}
