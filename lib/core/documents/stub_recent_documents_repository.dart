import '../error/app_failure.dart';
import '../result/result.dart';
import 'recent_document.dart';
import 'recent_documents_repository.dart';

/// Stands in until F08 builds the `documents` table.
///
/// Reports "nothing saved yet" rather than pretending to fail, so Home renders
/// its real empty state instead of an error. Swapped for the Drift-backed
/// implementation in F08 without touching Home.
final class StubRecentDocumentsRepository implements RecentDocumentsRepository {
  const StubRecentDocumentsRepository();

  @override
  Stream<Result<List<RecentDocument>, AppFailure>> watchRecent({
    int limit = 3,
  }) {
    return Stream.value(const Ok([]));
  }
}
