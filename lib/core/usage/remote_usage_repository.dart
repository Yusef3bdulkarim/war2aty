import 'dart:async';

import 'package:dio/dio.dart';

import '../database/app_database.dart';
import '../error/app_failure.dart';
import '../network/api_error_mapper.dart';
import '../network/network_failure_mapper.dart';
import '../result/result.dart';
import '../time/cairo_day.dart';
import 'daily_usage.dart';
import 'daily_usage_dto.dart';
import 'usage_remote_data_source.dart';
import 'usage_repository.dart';

/// The real [UsageRepository]: `get-usage` backed, Drift cached (F01-T10 @M4).
///
/// The backend is the authority on the quota — it is the only party that can
/// count across re-installs and devices, and it enforces the Cairo day (§27).
/// The local cache exists so Home can answer "how many do I have left?"
/// instantly and offline, not so the app can decide.
///
/// ## Why a failed sync keeps the cached row
///
/// [syncUsage] returns the cached value when the network fails rather than an
/// error, if there is one for today. A user on the metro should see "2 left"
/// from this morning instead of a broken counter — and the number is still
/// enforced server-side, so a stale reading cannot buy an extra analysis. Only
/// a failure with nothing cached surfaces as [Err].
final class RemoteUsageRepository implements UsageRepository {
  RemoteUsageRepository(this._remote, this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final UsageRemoteDataSource _remote;
  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<Result<DailyUsage, AppFailure>> syncUsage() async {
    final now = _now();

    final fetched = await _fetch(now);
    if (fetched case Ok(:final value)) {
      // A cache write failure is not worth failing the sync over: the caller
      // has the fresh numbers either way, and the row repairs itself on the
      // next successful sync.
      await _cache(value);
      return Ok(value);
    }

    // Offline, or the server refused. Fall back to today's cached row.
    final fallback = await cachedUsage();
    return switch (fallback) {
      Ok(value: final usage?) => Ok(usage),
      // Nothing cached for today: there is genuinely nothing to show, so the
      // original network failure is the honest answer.
      _ => Err((fetched as Err<DailyUsage, AppFailure>).failure),
    };
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
  /// left open across midnight keeps watching the previous day until something
  /// re-subscribes — acceptable while the count only changes as a result of the
  /// user running an analysis, which re-syncs anyway.
  @override
  Stream<Result<DailyUsage?, AppFailure>> watchUsage() {
    return _db
        .watchUsageForDate(cairoDateOf(_now()))
        .map<Result<DailyUsage?, AppFailure>>(
          (row) => Ok(row == null ? null : _toEntity(row)),
        )
        // The stream feeds a screen, so a database error becomes a value the UI
        // can render rather than an exception that tears the stream down.
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.add(const Err(LocalDatabaseFailure())),
          ),
        );
  }

  Future<Result<DailyUsage, AppFailure>> _fetch(DateTime now) async {
    final UsageApiResponse response;
    try {
      response = await _remote.fetchUsage();
    } on DioException catch (exception) {
      return Err(failureFromDioException(exception));
    } on Object {
      return const Err(AnalysisServiceFailure());
    }

    if (!response.isSuccess) {
      return Err(
        failureFromErrorBody(
          response.body,
          now: now,
          statusCode: response.statusCode,
        ),
      );
    }

    final body = response.body;
    if (body is! Map<String, dynamic>) {
      return const Err(InvalidAnalysisResponseFailure());
    }

    try {
      return Ok(DailyUsageDto.fromJson(body).toEntity(syncedAt: now));
    } on Object {
      // A missing key, a wrong type, a malformed date. Dropped rather than
      // logged — and a body we cannot read is not a quota we can trust.
      return const Err(InvalidAnalysisResponseFailure());
    }
  }

  Future<Result<void, AppFailure>> _cache(DailyUsage usage) async {
    try {
      await _db.upsertUsage(
        UsageCacheData(
          usageDate: usage.usageDate,
          dailyLimit: usage.dailyLimit,
          usedCount: usage.usedCount,
          remainingCount: usage.remainingCount,
          resetsAt: usage.resetsAt,
          lastSyncedAt: usage.lastSyncedAt,
        ),
      );
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
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
