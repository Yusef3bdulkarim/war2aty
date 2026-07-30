import 'package:uuid/uuid.dart';

import '../database/daos/documents_dao.dart';
import '../error/app_failure.dart';
import '../identity/installation_id_provider.dart';
import '../result/result.dart';
import 'document_analysis.dart';
import 'document_write_mapper.dart';
import 'documents_repository.dart';

/// [DocumentsRepository] backed by the local Drift database.
///
/// The error boundary for saved documents: drift throws, this catches, and
/// everything above it sees a [Result] (CLAUDE.md §B5). The caught object is
/// deliberately not inspected or logged — a database exception on a write can
/// carry the row it failed on, which is the paper's contents (§7).
final class DriftDocumentsRepository implements DocumentsRepository {
  DriftDocumentsRepository(
    this._dao, {
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : _generateId = idGenerator ?? (() => const Uuid().v4()),
       _now = clock ?? DateTime.now;

  final DocumentsDao _dao;
  final IdGenerator _generateId;
  final DateTime Function() _now;

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
}
