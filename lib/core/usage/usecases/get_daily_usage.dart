import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../daily_usage.dart';
import '../usage_repository.dart';

/// Reads today's cached analysis quota once.
///
/// Settings' «حدود الاستخدام» row (F11-T12) only needs a snapshot at the
/// moment the screen loads — unlike Home, it has no reason to follow later
/// changes live, so this wraps [UsageRepository.cachedUsage] rather than
/// [WatchDailyUsage]'s stream.
final class GetDailyUsage {
  const GetDailyUsage(this._repository);

  final UsageRepository _repository;

  Future<Result<DailyUsage?, AppFailure>> call() => _repository.cachedUsage();
}
