import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../documents_repository.dart';
import '../recent_document.dart';

/// Streams saved documents for the «مستنداتي» screen (F08-T05).
final class WatchDocuments {
  const WatchDocuments(this._repository);

  final DocumentsRepository _repository;

  Stream<Result<List<RecentDocument>, AppFailure>> call() =>
      _repository.watchDocuments();
}
