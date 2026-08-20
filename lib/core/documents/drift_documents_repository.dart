import 'dart:async';

import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/documents_dao.dart';
import '../error/app_failure.dart';
import '../identity/installation_id_provider.dart';
import '../reminders/reminder_scheduler.dart';
import '../result/result.dart';
import 'document_analysis.dart';
import 'document_category.dart';
import 'document_image_store.dart';
import 'document_read_mapper.dart';
import 'document_write_mapper.dart';
import 'documents_repository.dart';
import 'recent_document.dart';
import 'recent_documents_repository.dart';
import 'saved_document.dart';

/// [DocumentsRepository] backed by the local Drift database.
///
/// Also the [RecentDocumentsRepository] Home's strip reads: one Drift-backed
/// class for every read of a saved document, bounded or not, so there is one
/// place that maps a [DocumentRow] into a [RecentDocument].
///
/// The error boundary for saved documents: drift throws, this catches, and
/// everything above it sees a [Result] (CLAUDE.md §B5). The caught object is
/// deliberately not inspected or logged — a database exception on a write can
/// carry the row it failed on, which is the paper's contents (§7).
final class DriftDocumentsRepository
    implements DocumentsRepository, RecentDocumentsRepository {
  DriftDocumentsRepository(
    this._dao,
    this._images, {
    IdGenerator? idGenerator,
    DateTime Function()? clock,
    ReminderScheduler? reminderScheduler,
  }) : _generateId = idGenerator ?? (() => const Uuid().v4()),
       _now = clock ?? DateTime.now,
       _reminderScheduler = reminderScheduler;

  final DocumentsDao _dao;
  final DocumentImageStore _images;
  final IdGenerator _generateId;
  final DateTime Function() _now;

  /// Brings the OS in line with the database after a delete cascades onto a
  /// linked reminder (F09-T10) — optional so this repository does not have
  /// to be re-registered wherever it is already constructed without one
  /// (e.g. before F09 landed).
  final ReminderScheduler? _reminderScheduler;

  @override
  Stream<Result<List<RecentDocument>, AppFailure>> watchDocuments({
    String? titleQuery,
    DocumentCategory? category,
  }) => _watchRows(
    _dao.watchDocuments(titleQuery: titleQuery, category: category),
  );

  @override
  Stream<Result<List<RecentDocument>, AppFailure>> watchRecent({
    int limit = 3,
  }) => _watchRows(_dao.watchDocuments(limit: limit));

  /// Maps rows to entities and turns a database error into an [Err] value
  /// instead of tearing the stream down — the same shape
  /// [RemoteUsageRepository.watchUsage] uses for the same reason.
  Stream<Result<List<RecentDocument>, AppFailure>> _watchRows(
    Stream<List<DocumentRow>> rows,
  ) {
    return rows
        .map<Result<List<RecentDocument>, AppFailure>>(
          (rows) => Ok(rows.map(recentDocumentOf).toList()),
        )
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.add(const Err(LocalDatabaseFailure())),
          ),
        );
  }

  @override
  Stream<Result<SavedDocument?, AppFailure>> watchDocument(String id) {
    return _dao
        .watchDocumentById(id)
        .map<Result<SavedDocument?, AppFailure>>(
          (bundle) => Ok(bundle == null ? null : savedDocumentOf(bundle)),
        )
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.add(const Err(LocalDatabaseFailure())),
          ),
        );
  }

  @override
  Future<Result<void, AppFailure>> updateDocument(
    String id, {
    String? title,
    DocumentCategory? category,
  }) async {
    try {
      await _dao.updateDocument(
        id,
        title: title,
        category: category,
        updatedAt: _now(),
      );
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> setNote(String id, String? note) async {
    try {
      await _dao.setNote(id, note, updatedAt: _now());
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<String, AppFailure>> saveResultOnly({
    required DocumentAnalysis analysis,
    required String extractedText,
  }) async {
    final id = _generateId();

    try {
      await _dao.saveDocument(
        documentWriteOf(
          id: id,
          analysis: analysis,
          extractedText: extractedText,
          savedAt: _now(),
        ),
      );
      return Ok(id);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<String, AppFailure>> saveWithImage({
    required DocumentAnalysis analysis,
    required String extractedText,
    required String imagePath,
  }) async {
    final id = _generateId();

    final stored = await _images.encryptAndStore(
      documentId: id,
      sourcePath: imagePath,
    );
    return stored.when(
      ok: (encryptedImagePath) => _writeRow(
        id: id,
        analysis: analysis,
        extractedText: extractedText,
        encryptedImagePath: encryptedImagePath,
      ),
      err: (failure) async => Err(failure),
    );
  }

  @override
  Future<Result<void, AppFailure>> deleteDocument(String id) async {
    try {
      // The encrypted image lives on disk, outside the database cascade — the
      // store no-ops when there is nothing to remove, so calling it
      // unconditionally is safe and avoids a read-then-delete race.
      await _images.delete(id);
      await _dao.deleteDocument(id);
      // The FK cascade just removed any reminder linked to this document; a
      // reconcile brings the OS notification in line with that. Neither
      // repository imports the other's concrete type — see
      // `LocalNotificationsReminderScheduler`'s own doc comment. Best-effort
      // and unawaited: the delete itself already fully succeeded.
      unawaited(_reminderScheduler?.reconcile());
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> deleteAllDocuments() async {
    try {
      // Same ordering and reasoning as [deleteDocument]: the image directory
      // lives outside the database cascade, so it is wiped first and
      // unconditionally, then the rows (children cascade with them).
      await _images.deleteAll();
      await _dao.deleteAllDocuments();
      // The FK cascade just removed every reminder linked to a document; a
      // reconcile brings the OS notifications in line with that, same as
      // [deleteDocument].
      unawaited(_reminderScheduler?.reconcile());
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  Future<Result<String, AppFailure>> _writeRow({
    required String id,
    required DocumentAnalysis analysis,
    required String extractedText,
    required String encryptedImagePath,
  }) async {
    try {
      await _dao.saveDocument(
        documentWriteOf(
          id: id,
          analysis: analysis,
          extractedText: extractedText,
          savedAt: _now(),
          storageMode: DocumentStorageMode.withImage,
          encryptedImagePath: encryptedImagePath,
        ),
      );
      return Ok(id);
    } on Object {
      // The picture was already encrypted and written; without a row to
      // point at it, it would just sit there unreachable.
      await _images.delete(id);
      return const Err(LocalDatabaseFailure());
    }
  }
}
