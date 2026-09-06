import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../document_category.dart';
import '../documents_repository.dart';

/// Updates a saved document's title and/or category (F08-T10).
///
/// Either field may be omitted; passing neither only bumps `updatedAt`.
final class UpdateDocument {
  const UpdateDocument(this._repository);

  final DocumentsRepository _repository;

  Future<Result<void, AppFailure>> call(
    String documentId, {
    String? title,
    DocumentCategory? category,
  }) =>
      _repository.updateDocument(documentId, title: title, category: category);
}
