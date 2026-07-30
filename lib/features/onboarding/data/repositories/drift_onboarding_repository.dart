import '../../../../core/database/app_database.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/repositories/onboarding_repository.dart';

/// [OnboardingRepository] backed by the Drift `app_settings` table.
///
/// A single key/value row — no dedicated table is warranted for one boolean.
/// Storage exceptions are caught here, at the data boundary, and surfaced as a
/// typed [LocalDatabaseFailure].
final class DriftOnboardingRepository implements OnboardingRepository {
  const DriftOnboardingRepository(this._db);

  /// Key in `app_settings`. Present with `'true'` once onboarding finished;
  /// absent on a fresh install.
  static const String settingKey = 'onboarding_seen';

  final AppDatabase _db;

  @override
  Future<Result<bool, AppFailure>> hasSeenOnboarding() async {
    try {
      return Ok(await _db.getSetting(settingKey) == 'true');
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> markOnboardingSeen() async {
    try {
      await _db.setSetting(settingKey, 'true');
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }
}
