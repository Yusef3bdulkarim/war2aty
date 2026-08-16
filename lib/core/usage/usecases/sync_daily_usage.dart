import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../daily_usage.dart';
import '../usage_repository.dart';

/// Refreshes today's analysis quota from the backend and caches it locally.
///
/// `HomeCubit`'s `watchUsage()` stream picks up the cached row the instant it
/// changes, so calling this after an analysis is enough to bring Home's
/// remaining-count display back in sync — no polling, no client-side math.
final class SyncDailyUsage {
  const SyncDailyUsage(this._repository);

  final UsageRepository _repository;

  Future<Result<DailyUsage, AppFailure>> call() => _repository.syncUsage();
}
