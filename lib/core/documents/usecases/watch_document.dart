import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../documents_repository.dart';
import '../saved_document.dart';

/// Streams one saved document, in full, for the details screen (F08-T08).
final class WatchDocument {
  const WatchDocument(this._repository);

  final DocumentsRepository _repository;

  Stream<Result<SavedDocument?, AppFailure>> call(String id) =>
      _repository.watchDocument(id);
}
