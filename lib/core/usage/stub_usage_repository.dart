import 'dart:async';

import '../database/app_database.dart';
import '../error/app_failure.dart';
import '../result/result.dart';
import '../time/cairo_day.dart';
import 'daily_usage.dart';
import 'usage_repository.dart';

/// Local stand-in for the backend `get-usage` call (real one lands at M4).
///
/// Because there is no server yet, the locally cached count *is* the truth: a
/// sync rolls the row over to today's Cairo day and preserves whatever has
/// already been used today, rather than wiping the user's count on every
/// launch.
final class StubUsageRepository implements UsageRepository {
  StubUsageRepository(
    this._db, {
    required int Function() dailyLimit,
    DateTime Function()? clock,
  }) : _dailyLimit = dailyLimit,
       _now = clock ?? DateTime.now;

  final AppDatabase _db;

  /// Read lazily so a config loaded during launch takes effect immediately.
  final int Function() _dailyLimit;

  final DateTime Function() _now;

  @override
  Future<Result<DailyUsage, AppFailure>> syncUsage() async {
    try {
      final now = _now();
      final today = cairoDateOf(now);

      // Carry over today's count if we already have a row; a new Cairo day
      // starts fresh at zero.
      final existing = await _db.usageForDate(today);
      final used = existing?.usedCount ?? 0;
      final limit = _dailyLimit();

      final row = UsageCacheData(
        usageDate: today,
        dailyLimit: limit,
        usedCount: used,
        remainingCount: (limit - used).clamp(0, limit),
        resetsAt: nextCairoResetAfter(now),
        lastSyncedAt: now,
      );
      await _db.upsertUsage(row);

      return Ok(_toEntity(row));
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<DailyUsage?, AppFailure>> cachedUsage() async {
    try {
      final row = await _db.usageForDate(cairoDateOf(_now()));
      return Ok(row == null ? null : _toEntity(row));
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  /// Watches today's row.
  ///
  /// The Cairo day is resolved once, when the stream is subscribed to. An app
  /// left open across midnight therefore keeps watching the previous day until
  /// something re-subscribes — acceptable while the count only changes as a
  /// result of the user running an analysis, which re-syncs anyway.
  @override
  Stream<Result<DailyUsage?, AppFailure>> watchUsage() {
    return _db
        .watchUsageForDate(cairoDateOf(_now()))
        .map<Result<DailyUsage?, AppFailure>>(
          (row) => Ok(row == null ? null : _toEntity(row)),
        )
        // The stream feeds a screen, so a database error becomes a value the
        // UI can render rather than an exception that tears the stream down.
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.add(const Err(LocalDatabaseFailure())),
          ),
        );
  }

  // Drift hands back local DateTimes; Dart's `==` treats a local and a UTC
  // DateTime as different even at the same instant, so normalise to UTC here.
  DailyUsage _toEntity(UsageCacheData row) => DailyUsage(
    usageDate: row.usageDate.toUtc(),
    dailyLimit: row.dailyLimit,
    usedCount: row.usedCount,
    remainingCount: row.remainingCount,
    resetsAt: row.resetsAt.toUtc(),
    lastSyncedAt: row.lastSyncedAt?.toUtc(),
  );
}
