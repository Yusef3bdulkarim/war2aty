import '../database/app_database.dart';
import '../database/setting_keys.dart';
import '../error/app_failure.dart';
import '../result/result.dart';
import 'app_settings_repository.dart';

/// [AppSettingsRepository] backed by the local Drift database.
///
/// Same error boundary as every other Drift-backed repository here: drift
/// throws, this catches, everything above sees a [Result] (CLAUDE.md §B5).
final class DriftAppSettingsRepository implements AppSettingsRepository {
  const DriftAppSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<void, AppFailure>> clearAllSettingsAndUsageCache() async {
    try {
      final onboardingSeen = await _db.getSetting(
        AppSettingKeys.onboardingSeen,
      );
      await _db.clearAppSettings();
      await _db.clearUsageCache();
      if (onboardingSeen == 'true') {
        await _db.setSetting(AppSettingKeys.onboardingSeen, 'true');
      }
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }
}
