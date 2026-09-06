import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../documents_repository.dart';

/// Deletes every saved document and everything that belongs to it —
/// settings' «حذف كل المستندات» and «حذف كل بيانات التطبيق» (F11-T11).
///
/// The repository handles the cascade: child rows, every encrypted image,
/// and any reminder linked to a deleted document.
final class DeleteAllDocuments {
  const DeleteAllDocuments(this._repository);

  final DocumentsRepository _repository;

  Future<Result<void, AppFailure>> call() => _repository.deleteAllDocuments();
}
