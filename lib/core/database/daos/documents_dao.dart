import 'package:drift/drift.dart';

import '../../documents/document_category.dart';
import '../../documents/recent_document.dart';
import '../app_database.dart';
import '../tables/document_tables.dart';

part 'documents_dao.g.dart';

/// One saved document with every child row that belongs to it.
///
/// A raw storage aggregate, not a domain entity: it carries generated row
/// classes and stays inside the data layer, where the feature's mapper turns
/// it into a document entity. Grouping the rows here means a caller reads a
/// whole document in one transaction instead of six sequential queries.
final class DocumentBundle {
  const DocumentBundle({
    required this.document,
    this.keyInformation = const [],
    this.dates = const [],
    this.amounts = const [],
    this.actions = const [],
    this.warnings = const [],
    this.textItems = const [],
  });

  final DocumentRow document;
  final List<DocumentInfoRow> keyInformation;
  final List<DocumentDateRow> dates;
  final List<DocumentAmountRow> amounts;
  final List<DocumentActionRow> actions;
  final List<DocumentWarningRow> warnings;
  final List<DocumentTextItemRow> textItems;

  /// The entries of one of the plain-text lists, in order.
  List<String> textItemsOf(DocumentTextItemKind kind) => textItems
      .where((item) => item.kind == kind)
      .map((item) => item.value)
      .toList(growable: false);
}

/// Everything that is written when a document is saved.
///
/// The child lists arrive in display order; the DAO derives each row's
/// `position` from that order, so no caller has to number them by hand.
final class DocumentWrite {
  const DocumentWrite({
    required this.document,
    this.keyInformation = const [],
    this.dates = const [],
    this.amounts = const [],
    this.actions = const [],
    this.warnings = const [],
    this.requiredDocuments = const [],
    this.instructions = const [],
    this.missingFields = const [],
  });

  final DocumentsCompanion document;
  final List<DocumentKeyInformationCompanion> keyInformation;
  final List<DocumentDatesCompanion> dates;
  final List<DocumentAmountsCompanion> amounts;
  final List<DocumentActionsCompanion> actions;
  final List<DocumentWarningsCompanion> warnings;
  final List<String> requiredDocuments;
  final List<String> instructions;
  final List<String> missingFields;
}

/// Local storage for saved documents (F08).
///
/// The only place that touches the document tables. It hands out rows and
/// streams of rows — no domain types, no failures, no Arabic copy: mapping
/// and error translation belong to the repository above it.
///
/// Nothing here reaches the network. Saved documents never leave the device
/// (CLAUDE.md §7).
@DriftAccessor(
  tables: [
    Documents,
    DocumentKeyInformation,
    DocumentDates,
    DocumentAmounts,
    DocumentActions,
    DocumentWarnings,
    DocumentTextItems,
  ],
)
class DocumentsDao extends DatabaseAccessor<AppDatabase>
    with _$DocumentsDaoMixin {
  DocumentsDao(super.db);

  /// Writes a document and all of its children in one transaction.
  ///
  /// All-or-nothing on purpose: a half-written document would show up in the
  /// list with its dates missing, and the user would have no way to tell.
  /// Re-saving the same id replaces the previous version, children included.
  Future<void> saveDocument(DocumentWrite write) {
    return transaction(() async {
      final id = write.document.id.value;

      await _deleteChildren(id);
      await into(documents).insertOnConflictUpdate(write.document);

      // Each child is stamped with its list index here rather than by the
      // caller: order is what the details screen renders, and a mapper that
      // forgot to number a row would corrupt it silently.
      await batch((b) {
        b
          ..insertAll(documentKeyInformation, [
            for (var i = 0; i < write.keyInformation.length; i++)
              write.keyInformation[i].copyWith(
                documentId: Value(id),
                position: Value(i),
              ),
          ])
          ..insertAll(documentDates, [
            for (var i = 0; i < write.dates.length; i++)
              write.dates[i].copyWith(
                documentId: Value(id),
                position: Value(i),
              ),
          ])
          ..insertAll(documentAmounts, [
            for (var i = 0; i < write.amounts.length; i++)
              write.amounts[i].copyWith(
                documentId: Value(id),
                position: Value(i),
              ),
          ])
          ..insertAll(documentActions, [
            for (var i = 0; i < write.actions.length; i++)
              write.actions[i].copyWith(
                documentId: Value(id),
                position: Value(i),
              ),
          ])
          ..insertAll(documentWarnings, [
            for (var i = 0; i < write.warnings.length; i++)
              write.warnings[i].copyWith(
                documentId: Value(id),
                position: Value(i),
              ),
          ])
          ..insertAll(documentTextItems, [
            ..._textItems(
              id,
              DocumentTextItemKind.requiredDocument,
              write.requiredDocuments,
            ),
            ..._textItems(
              id,
              DocumentTextItemKind.instruction,
              write.instructions,
            ),
            ..._textItems(
              id,
              DocumentTextItemKind.missingField,
              write.missingFields,
            ),
          ]);
      });
    });
  }

  /// Watches saved documents, newest first.
  ///
  /// [titleQuery] matches anywhere in the title, case-insensitively (F08-T06);
  /// [category] narrows to one filter chip (F08-T07); [limit] caps the result
  /// for Home's recent strip. Each is optional and they combine.
  ///
  /// Only [Documents] rows are read — a list row needs a title, a category and
  /// a badge, so the children stay unread until a document is opened.
  Stream<List<DocumentRow>> watchDocuments({
    String? titleQuery,
    DocumentCategory? category,
    int? limit,
  }) {
    final query = select(documents)
      ..orderBy([(d) => OrderingTerm.desc(d.savedAt)]);

    final trimmed = titleQuery?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      query.where((d) => d.title.lower().contains(trimmed.toLowerCase()));
    }
    if (category != null) {
      query.where((d) => d.category.equalsValue(category));
    }
    if (limit != null) {
      query.limit(limit);
    }

    return query.watch();
  }

  /// Reads one document with its children, or `null` if it is not there.
  Future<DocumentBundle?> documentById(String id) {
    return transaction(() async {
      final document = await (select(
        documents,
      )..where((d) => d.id.equals(id))).getSingleOrNull();
      if (document == null) return null;

      return DocumentBundle(
        document: document,
        keyInformation: await _keyInformationOf(id),
        dates: await _datesOf(id),
        amounts: await _amountsOf(id),
        actions: await _actionsOf(id),
        warnings: await _warningsOf(id),
        textItems: await _textItemsOf(id),
      );
    });
  }

  /// Watches one document with its children.
  ///
  /// Re-reads the whole bundle whenever any of the tables changes, so the
  /// details screen follows an edit, a note or a deletion without refreshing
  /// itself. Emits `null` once the document is gone.
  Stream<DocumentBundle?> watchDocumentById(String id) {
    // A bundle spans seven tables, which no single drift query covers. This
    // reads nothing and exists only to say which tables the stream depends
    // on; drift re-runs it — and so the bundle — whenever one of them changes.
    final trigger = customSelect(
      'SELECT 1',
      readsFrom: {
        documents,
        documentKeyInformation,
        documentDates,
        documentAmounts,
        documentActions,
        documentWarnings,
        documentTextItems,
      },
    ).watch();

    return trigger.asyncMap((_) => documentById(id));
  }

  /// Updates the fields the user can edit (F08-T10), leaving the analysis as
  /// it was read. Passing neither field only touches [Documents.updatedAt].
  Future<void> updateDocument(
    String id, {
    String? title,
    DocumentCategory? category,
    required DateTime updatedAt,
  }) {
    return (update(documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        title: title == null ? const Value.absent() : Value(title),
        category: category == null ? const Value.absent() : Value(category),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Sets or clears the user's note (F08-T09). A `null` [note] deletes it.
  Future<void> setNote(String id, String? note, {required DateTime updatedAt}) {
    return (update(documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(note: Value(note), updatedAt: Value(updatedAt)),
    );
  }

  /// Records where a document's encrypted picture ended up, or clears it.
  ///
  /// The path only ever points inside the app's private directory, and the
  /// file behind it is encrypted (F08-T04).
  Future<void> setEncryptedImage(
    String id,
    String? path, {
    required DocumentStorageMode storageMode,
    required DateTime updatedAt,
  }) {
    return (update(documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        encryptedImagePath: Value(path),
        storageMode: Value(storageMode),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Deletes a document. Its child rows go with it through the cascade, so
  /// nothing about the paper is left behind.
  ///
  /// Deleting the encrypted image file is the repository's job — the database
  /// does not own the file system.
  Future<void> deleteDocument(String id) {
    return (delete(documents)..where((d) => d.id.equals(id))).go();
  }

  /// Clears a document's children before its rows are written again.
  ///
  /// The cascade covers deletion, but a re-save keeps the parent row, so the
  /// old children would otherwise survive alongside the new ones.
  Future<void> _deleteChildren(String id) {
    return batch((b) {
      b
        ..deleteWhere(documentKeyInformation, (t) => t.documentId.equals(id))
        ..deleteWhere(documentDates, (t) => t.documentId.equals(id))
        ..deleteWhere(documentAmounts, (t) => t.documentId.equals(id))
        ..deleteWhere(documentActions, (t) => t.documentId.equals(id))
        ..deleteWhere(documentWarnings, (t) => t.documentId.equals(id))
        ..deleteWhere(documentTextItems, (t) => t.documentId.equals(id));
    });
  }

  Future<List<DocumentInfoRow>> _keyInformationOf(String id) {
    final query = select(documentKeyInformation)
      ..where((t) => t.documentId.equals(id))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return query.get();
  }

  Future<List<DocumentDateRow>> _datesOf(String id) {
    final query = select(documentDates)
      ..where((t) => t.documentId.equals(id))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return query.get();
  }

  Future<List<DocumentAmountRow>> _amountsOf(String id) {
    final query = select(documentAmounts)
      ..where((t) => t.documentId.equals(id))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return query.get();
  }

  Future<List<DocumentActionRow>> _actionsOf(String id) {
    final query = select(documentActions)
      ..where((t) => t.documentId.equals(id))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return query.get();
  }

  Future<List<DocumentWarningRow>> _warningsOf(String id) {
    final query = select(documentWarnings)
      ..where((t) => t.documentId.equals(id))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return query.get();
  }

  Future<List<DocumentTextItemRow>> _textItemsOf(String id) {
    final query = select(documentTextItems)
      ..where((t) => t.documentId.equals(id))
      ..orderBy([
        (t) => OrderingTerm.asc(t.kind),
        (t) => OrderingTerm.asc(t.position),
      ]);
    return query.get();
  }

  List<DocumentTextItemsCompanion> _textItems(
    String id,
    DocumentTextItemKind kind,
    List<String> values,
  ) {
    return [
      for (var i = 0; i < values.length; i++)
        DocumentTextItemsCompanion.insert(
          documentId: id,
          kind: kind,
          position: i,
          value: values[i],
        ),
    ];
  }
}
