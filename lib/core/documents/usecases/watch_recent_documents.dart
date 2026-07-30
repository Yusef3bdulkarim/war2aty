import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../recent_document.dart';
import '../recent_documents_repository.dart';

/// Streams the newest saved documents for Home's recent strip.
final class WatchRecentDocuments {
  const WatchRecentDocuments(this._repository);

  /// How many rows Home shows. Small on purpose — Home is a hub, and the full
  /// list lives behind "see all".
  static const int homeLimit = 3;

  final RecentDocumentsRepository _repository;

  Stream<Result<List<RecentDocument>, AppFailure>> call({
    int limit = homeLimit,
  }) => _repository.watchRecent(limit: limit);
}
