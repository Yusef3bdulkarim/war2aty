import '../error/app_failure.dart';
import '../result/result.dart';
import 'runtime_config.dart';

/// Supplies the active [RuntimeConfig].
abstract interface class RuntimeConfigRepository {
  /// Loads the config, falling back to [RuntimeConfig.defaults] when nothing
  /// usable is cached. Never leaves the app without a config.
  Future<Result<RuntimeConfig, AppFailure>> load();

  /// Stores a config for the next launch (used once the backend supplies one).
  Future<Result<void, AppFailure>> cache(RuntimeConfig config);
}
