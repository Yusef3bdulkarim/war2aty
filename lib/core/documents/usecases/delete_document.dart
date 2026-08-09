import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../documents_repository.dart';

/// Deletes a saved document and everything that belongs to it (F08-T11).
///
/// The repository handles the cascade: child rows, encrypted image, and —
/// once F09 lands — a linked reminder.
final class DeleteDocument {
  const DeleteDocument(this._repository);

  final DocumentsRepository _repository;

  Future<Result<void, AppFailure>> call(String documentId) =>
      _repository.deleteDocument(documentId);
}
