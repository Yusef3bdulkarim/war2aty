import 'dart:async';

import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/daos/documents_dao.dart';
import '../error/app_failure.dart';
import '../identity/installation_id_provider.dart';
import '../result/result.dart';
import 'document_analysis.dart';
import 'document_image_store.dart';
import 'document_read_mapper.dart';
import 'document_write_mapper.dart';
import 'documents_repository.dart';
import 'recent_document.dart';
import 'recent_documents_repository.dart';

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
  }) : _generateId = idGenerator ?? (() => const Uuid().v4()),
       _now = clock ?? DateTime.now;

  final DocumentsDao _dao;
  final DocumentImageStore _images;
  final IdGenerator _generateId;
  final DateTime Function() _now;

  @override
  Stream<Result<List<RecentDocument>, AppFailure>> watchDocuments() =>
      _watchRows(_dao.watchDocuments());

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
