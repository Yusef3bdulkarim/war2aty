import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../daily_usage.dart';
import '../usage_repository.dart';

/// Streams today's analysis quota so a screen can follow it live.
final class WatchDailyUsage {
  const WatchDailyUsage(this._repository);

  final UsageRepository _repository;

  Stream<Result<DailyUsage?, AppFailure>> call() => _repository.watchUsage();
}
