import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/usage/daily_usage.dart';
import 'package:war2aty/core/usage/stub_usage_repository.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;

  final day1 = DateTime.utc(2026, 7, 21, 10); // 12:00 Cairo
  final day2 = DateTime.utc(2026, 7, 22, 10);

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  StubUsageRepository repoAt(DateTime now, {int limit = 3}) =>
      StubUsageRepository(db, dailyLimit: () => limit, clock: () => now);

  group('syncUsage', () {
    test('creates a fresh full quota on first sync of the day', () async {
      final result = await repoAt(day1).syncUsage();
      final usage = result.valueOrNull!;

      expect(usage.usageDate, DateTime.utc(2026, 7, 21));
      expect(usage.dailyLimit, 3);
      expect(usage.usedCount, 0);
      expect(usage.remainingCount, 3);
      expect(usage.resetsAt, DateTime.utc(2026, 7, 21, 22));
      expect(usage.lastSyncedAt, day1);
      expect(usage.hasQuotaLeft, isTrue);
    });

    test('preserves what was already used today', () async {
      await repoAt(day1).syncUsage();
      // Simulate two analyses having been consumed.
      await db.upsertUsage(
        UsageCacheData(
          usageDate: DateTime.utc(2026, 7, 21),
          dailyLimit: 3,
          usedCount: 2,
          remainingCount: 1,
          resetsAt: DateTime.utc(2026, 7, 21, 22),
          lastSyncedAt: day1,
        ),
      );

      final usage = (await repoAt(day1).syncUsage()).valueOrNull!;

      expect(usage.usedCount, 2, reason: 'a re-sync must not wipe the count');
      expect(usage.remainingCount, 1);
    });

    test('starts a new Cairo day at zero', () async {
      await db.upsertUsage(
        UsageCacheData(
          usageDate: DateTime.utc(2026, 7, 21),
          dailyLimit: 3,
          usedCount: 3,
          remainingCount: 0,
          resetsAt: DateTime.utc(2026, 7, 21, 22),
          lastSyncedAt: day1,
        ),
      );

      final usage = (await repoAt(day2).syncUsage()).valueOrNull!;

      expect(usage.usageDate, DateTime.utc(2026, 7, 22));
      expect(usage.usedCount, 0);
      expect(usage.remainingCount, 3);
    });

    test('never reports negative remaining when over the limit', () async {
      await db.upsertUsage(
        UsageCacheData(
          usageDate: DateTime.utc(2026, 7, 21),
          dailyLimit: 3,
          usedCount: 5,
          remainingCount: 0,
          resetsAt: DateTime.utc(2026, 7, 21, 22),
          lastSyncedAt: day1,
        ),
      );

      final usage = (await repoAt(day1).syncUsage()).valueOrNull!;

      expect(usage.remainingCount, 0);
      expect(usage.hasQuotaLeft, isFalse);
    });
  });

  group('cachedUsage', () {
    test('returns null before anything is cached', () async {
      expect(
        await repoAt(day1).cachedUsage(),
        const Ok<DailyUsage?, AppFailure>(null),
      );
    });

    test('returns today\'s row after a sync', () async {
      final synced = (await repoAt(day1).syncUsage()).valueOrNull;

      expect((await repoAt(day1).cachedUsage()).valueOrNull, synced);
    });

    test('returns null once the Cairo day has rolled over', () async {
      await repoAt(day1).syncUsage();

      expect((await repoAt(day2).cachedUsage()).valueOrNull, isNull);
    });
  });

  test('round-trips dates through the database without drift', () async {
    // Guards the UTC normalisation: Dart's DateTime equality is UTC-sensitive,
    // and Drift returns local DateTimes.
    final synced = (await repoAt(day1).syncUsage()).valueOrNull!;
    final cached = (await repoAt(day1).cachedUsage()).valueOrNull!;

    expect(cached.usageDate.isUtc, isTrue);
    expect(cached.resetsAt, synced.resetsAt);
    expect(cached.lastSyncedAt, synced.lastSyncedAt);
  });
}
