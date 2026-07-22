import '../error/app_failure.dart';
import '../result/result.dart';
import 'daily_usage.dart';

/// Keeps the local view of the daily analysis quota up to date.
///
/// Contract lives in `core/` because several features consume it: bootstrap
/// syncs it at launch, Home displays it, and analysis checks it before running.
abstract interface class UsageRepository {
  /// Fetches usage from the backend (`get-usage`) and caches it locally.
  /// Stubbed until the real Supabase function exists (M4).
  Future<Result<DailyUsage, AppFailure>> syncUsage();

  /// Reads today's cached usage without touching the network,
  /// or `Ok(null)` when nothing is cached for today.
  Future<Result<DailyUsage?, AppFailure>> cachedUsage();

  /// Emits today's cached usage and every later change to it.
  ///
  /// `Ok(null)` means "nothing cached for today yet" — a real answer, not an
  /// error. Failures arrive as `Err` values in the stream rather than as
  /// stream errors, so callers handle them the same way they handle the
  /// one-shot reads above.
  Stream<Result<DailyUsage?, AppFailure>> watchUsage();
}
