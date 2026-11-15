import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Imported for the generated part file: it names these enums in the document
// row and companion classes, and a part cannot import them itself.
import '../documents/document_category.dart';
import '../documents/recent_document.dart';
import '../papers/paper_status.dart';
import '../reminders/reminder_alert_status.dart';
import '../reminders/reminder_status.dart';
import 'daos/documents_dao.dart';
import 'daos/reminders_dao.dart';
import 'tables/document_tables.dart';
import 'tables/paper_tables.dart';
import 'tables/reminder_tables.dart';

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

/// The local SQLite database (schema v4).
///
/// v1 held the foundation tables; v2 added the saved-document tables (F08);
/// v3 added the reminder tables (F09); v4 adds the paper tables (F38) and
/// wipes every legacy saved document along with the reminders that were
/// still linked to one.
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
    Reminders,
    ReminderAlerts,
    Papers,
    PaperParagraphs,
    PaperSpans,
  ],
  daos: [DocumentsDao, RemindersDao],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database. Pass an [executor] (e.g. an in-memory one)
  /// in tests.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'war2aty'));

  @override
  int get schemaVersion => 4;

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
      if (from < 3) {
        for (final entity in _reminderSchema) {
          await m.create(entity);
        }
      }
      if (from < 4) {
        for (final entity in _paperSchema) {
          await m.create(entity);
        }
        await _wipeLegacyDocuments();
        // A device already past v3 has a physical `reminders` row that may
        // carry a now-dangling `document_id` — the column [_reminderSchema]
        // stopped creating for everyone else, because a v1/v2 device gets
        // today's (already-linkless) shape straight away and has nothing to
        // drop here.
        if (from >= 3) {
          await _dropDocumentLinkedReminders();
          await customStatement('DROP INDEX IF EXISTS reminders_document');
          await m.alterTable(TableMigration(reminders));
        }
      }
    },
    beforeOpen: (details) async {
      // Off by default in SQLite, and the document/reminder children rely on
      // it: only with it on does deleting a paper (or a reminder) take its
      // children with it.
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

  /// The entities v3 introduced (F09), same ordering rule as
  /// [_documentSchema].
  List<DatabaseSchemaEntity> get _reminderSchema => [
    reminders,
    reminderAlerts,
    remindersEventDate,
    remindersStatus,
    reminderAlertsReminder,
  ];

  /// The entities v4 introduced (F38), same ordering rule as
  /// [_documentSchema].
  List<DatabaseSchemaEntity> get _paperSchema => [
    papers,
    paperParagraphs,
    paperSpans,
    papersEventDay,
  ];

  /// Deletes every row the legacy saved-document feature ever wrote, child
  /// tables first — F38-D3. `PRAGMA foreign_keys` is off for the whole of
  /// [onUpgrade] (it only turns on in [beforeOpen], which drift runs after),
  /// so a `documents` row's cascade never fires here: every child table is
  /// cleared by hand.
  Future<void> _wipeLegacyDocuments() async {
    await delete(documentKeyInformation).go();
    await delete(documentDates).go();
    await delete(documentAmounts).go();
    await delete(documentActions).go();
    await delete(documentWarnings).go();
    await delete(documentTextItems).go();
    await delete(documents).go();
  }

  /// Deletes every reminder still linked to one of the documents
  /// [_wipeLegacyDocuments] just removed, and its own alerts — explicitly,
  /// because the same foreign-keys-off trap means `reminders.document_id`
  /// pointing at a now-missing row would otherwise survive the delete above
  /// and then lose the evidence it was ever linked once the column is
  /// dropped below (F38-D3/D4).
  Future<void> _dropDocumentLinkedReminders() async {
    await customStatement(
      'DELETE FROM reminder_alerts WHERE reminder_id IN '
      '(SELECT id FROM reminders WHERE document_id IS NOT NULL)',
    );
    await customStatement(
      'DELETE FROM reminders WHERE document_id IS NOT NULL',
    );
  }

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

  /// Removes a setting, so a later [getSetting] answers `null` again — how a
  /// store models "back to automatic" for a value that has no default string
  /// of its own to overwrite with (F11-T07's default voice, unset).
  Future<void> deleteSetting(String key) =>
      (delete(appSettings)..where((t) => t.key.equals(key))).go();

  /// Deletes every row of `app_settings` — settings' «حذف كل بيانات التطبيق»
  /// (F11-T11). Every `Get*` use case already falls back to its documented
  /// default once a key is unset, so nothing needs to be written back here.
  Future<void> clearAppSettings() => delete(appSettings).go();

  /// Deletes every row of `usage_cache` (F11-T11) — the next sync from the
  /// backend, the source of truth, repopulates it.
  Future<void> clearUsageCache() => delete(usageCache).go();

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
