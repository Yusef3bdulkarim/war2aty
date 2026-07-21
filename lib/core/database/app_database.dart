import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Key/value application settings (locale, flags, …).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Cached daily usage counter (Africa/Cairo day). Source of truth is the
/// backend; this mirrors it locally for fast, offline-tolerant reads.
class UsageCache extends Table {
  DateTimeColumn get usageDate => dateTime()();
  IntColumn get dailyLimit => integer()();
  IntColumn get usedCount => integer()();
  IntColumn get remainingCount => integer()();
  DateTimeColumn get resetsAt => dateTime()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {usageDate};
}

/// The local SQLite database (schema v1).
///
/// Only foundation tables exist so far; document/reminder tables are added in
/// later migrations as those features land.
@DriftDatabase(tables: [AppSettings, UsageCache])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database. Pass an [executor] (e.g. an in-memory one)
  /// in tests.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'war2aty'));

  @override
  int get schemaVersion => 1;

  /// Reads a single setting value, or `null` if unset.
  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Upserts a setting value with the current timestamp.
  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(
        key: key,
        value: value,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Reads the cached usage row for a Cairo [date], or `null`.
  Future<UsageCacheData?> usageForDate(DateTime date) {
    return (select(
      usageCache,
    )..where((t) => t.usageDate.equals(date))).getSingleOrNull();
  }

  /// Inserts or replaces the usage row for its date.
  Future<void> upsertUsage(UsageCacheData usage) {
    return into(usageCache).insertOnConflictUpdate(usage);
  }
}
