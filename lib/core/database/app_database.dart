import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Imported for the generated part file: it names these enums in the document
// row and companion classes, and a part cannot import them itself.
import '../documents/document_category.dart';
import '../documents/recent_document.dart';
import 'daos/documents_dao.dart';
import 'tables/document_tables.dart';

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

/// The local SQLite database (schema v2).
///
/// v1 held the foundation tables; v2 adds the saved-document tables (F08).
/// Reminder tables follow in F09.
@DriftDatabase(
  tables: [
    AppSettings,
    UsageCache,
    Documents,
    DocumentKeyInformation,
    DocumentDates,
    DocumentAmounts,
    DocumentActions,
    DocumentWarnings,
    DocumentTextItems,
  ],
  daos: [DocumentsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database. Pass an [executor] (e.g. an in-memory one)
  /// in tests.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'war2aty'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Fresh tables only — no v1 data is touched, so an upgrade cannot
        // lose a user's settings or their usage count.
        for (final entity in _documentSchema) {
          await m.create(entity);
        }
      }
    },
    beforeOpen: (details) async {
      // Off by default in SQLite, and the document children rely on it: only
      // with it on does deleting a paper take its dates and amounts with it.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The entities v2 introduced, in dependency order (parent before children,
  /// tables before their indexes).
  List<DatabaseSchemaEntity> get _documentSchema => [
    documents,
    documentKeyInformation,
    documentDates,
    documentAmounts,
    documentActions,
    documentWarnings,
    documentTextItems,
    documentsSavedAt,
    documentsCategory,
  ];

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

  /// Watches the cached usage row for a Cairo [date].
  ///
  /// Drift re-runs the query whenever `usage_cache` changes, so Home updates
  /// itself after an analysis without any manual refresh.
  Stream<UsageCacheData?> watchUsageForDate(DateTime date) {
    return (select(
      usageCache,
    )..where((t) => t.usageDate.equals(date))).watchSingleOrNull();
  }

  /// Inserts or replaces the usage row for its date.
  Future<void> upsertUsage(UsageCacheData usage) {
    return into(usageCache).insertOnConflictUpdate(usage);
  }
}
