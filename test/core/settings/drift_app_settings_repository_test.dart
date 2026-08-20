import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/database/setting_keys.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/settings/drift_app_settings_repository.dart';

import '../../support/fakes.dart';

// F11-T11: settings' «حذف كل بيانات التطبيق».
void main() {
  late AppDatabase db;
  late DriftAppSettingsRepository repository;

  setUp(() {
    db = memoryDatabase();
    repository = DriftAppSettingsRepository(db);
  });
  tearDown(() => db.close());

  test('clears every app_settings row', () async {
    await db.setSetting('text_size', 'large');
    await db.setSetting('high_contrast', 'true');

    final result = await repository.clearAllSettingsAndUsageCache();

    expect(result, const Ok<void, AppFailure>(null));
    expect(await db.getSetting('text_size'), isNull);
    expect(await db.getSetting('high_contrast'), isNull);
  });

  test('clears the usage cache', () async {
    await db.upsertUsage(
      UsageCacheData(
        usageDate: DateTime.utc(2026, 8, 18),
        dailyLimit: 3,
        usedCount: 2,
        remainingCount: 1,
        resetsAt: DateTime.utc(2026, 8, 18, 22),
        lastSyncedAt: DateTime.utc(2026, 8, 18, 10),
      ),
    );

    await repository.clearAllSettingsAndUsageCache();

    expect(await db.usageForDate(DateTime.utc(2026, 8, 18)), isNull);
  });

  test('preserves onboarding-seen when it was true', () async {
    await db.setSetting(AppSettingKeys.onboardingSeen, 'true');
    await db.setSetting('text_size', 'large');

    await repository.clearAllSettingsAndUsageCache();

    expect(await db.getSetting(AppSettingKeys.onboardingSeen), 'true');
    expect(await db.getSetting('text_size'), isNull);
  });

  test('stays absent when onboarding was never marked seen', () async {
    await repository.clearAllSettingsAndUsageCache();

    expect(await db.getSetting(AppSettingKeys.onboardingSeen), isNull);
  });
}
