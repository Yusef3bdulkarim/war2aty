// `isNull` is a drift SQL expression too; the matcher wins here.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/reminders/reminder_status.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('schema is at version 4', () {
    expect(db.schemaVersion, 4);
  });

  test('foreign keys are enforced once the database is open', () async {
    final row = await db
        .customSelect('PRAGMA foreign_keys')
        .map((r) => r.read<int>('foreign_keys'))
        .getSingle();

    expect(row, 1);
  });

  group('migration from v1', () {
    late AppDatabase upgraded;

    setUp(() => upgraded = AppDatabase(_versionOneDatabase()));
    tearDown(() => upgraded.close());

    test('keeps the settings a v1 database already held', () async {
      expect(await upgraded.getSetting('locale'), 'ar');
    });

    test('adds the document tables (v2)', () async {
      expect(await upgraded.select(upgraded.documents).get(), isEmpty);
      expect(await upgraded.select(upgraded.documentDates).get(), isEmpty);
    });

    // A v1 database has never been released (F00 shipped straight to v2), so
    // this exercises every `onUpgrade` branch in one open — the same path a
    // v1-schema device would actually take.
    test('adds the reminder tables (v3)', () async {
      expect(await upgraded.select(upgraded.reminders).get(), isEmpty);
      expect(await upgraded.select(upgraded.reminderAlerts).get(), isEmpty);
    });

    test('adds the paper tables (v4), with no document_id to drop', () async {
      expect(await upgraded.select(upgraded.papers).get(), isEmpty);
      expect(await upgraded.select(upgraded.paperParagraphs).get(), isEmpty);
      expect(await upgraded.select(upgraded.paperSpans).get(), isEmpty);
      expect(await _remindersColumns(upgraded), isNot(contains('document_id')));
    });
  });

  group('migration from v2', () {
    late AppDatabase upgraded;

    setUp(() => upgraded = AppDatabase(_versionTwoDatabase()));
    tearDown(() => upgraded.close());

    test('keeps the settings a v2 database already held', () async {
      expect(await upgraded.getSetting('locale'), 'ar');
    });

    test(
      'adds the reminder and paper tables without touching documents',
      () async {
        expect(await upgraded.select(upgraded.reminders).get(), isEmpty);
        expect(await upgraded.select(upgraded.reminderAlerts).get(), isEmpty);
        expect(await upgraded.select(upgraded.documents).get(), isEmpty);
        expect(await upgraded.select(upgraded.papers).get(), isEmpty);
      },
    );
  });

  group('migration from v3', () {
    late AppDatabase upgraded;

    setUp(() => upgraded = AppDatabase(_versionThreeDatabase()));
    tearDown(() => upgraded.close());

    test('keeps the settings a v3 database already held', () async {
      expect(await upgraded.getSetting('locale'), 'ar');
    });

    test('wipes every legacy document and its child rows', () async {
      expect(await upgraded.select(upgraded.documents).get(), isEmpty);
      expect(
        await upgraded.select(upgraded.documentKeyInformation).get(),
        isEmpty,
      );
      expect(await upgraded.select(upgraded.documentDates).get(), isEmpty);
      expect(await upgraded.select(upgraded.documentAmounts).get(), isEmpty);
      expect(await upgraded.select(upgraded.documentActions).get(), isEmpty);
      expect(await upgraded.select(upgraded.documentWarnings).get(), isEmpty);
      expect(await upgraded.select(upgraded.documentTextItems).get(), isEmpty);
    });

    // The FK-off trap: `PRAGMA foreign_keys` only turns on in `beforeOpen`,
    // which drift runs *after* `onUpgrade` — so a migration that trusted the
    // cascade to remove the linked reminder (and its alert) when `documents`
    // was wiped would leave both of them behind. This fails if that happens.
    test('drops the reminder that was linked to a wiped document', () async {
      final reminders = await upgraded.select(upgraded.reminders).get();
      expect(reminders.map((r) => r.id), ['rem-manual']);

      final alerts = await upgraded.select(upgraded.reminderAlerts).get();
      expect(alerts.map((a) => a.id), ['alert-manual']);
    });

    test('keeps the manual reminder intact, minus document_id', () async {
      final reminder = await (upgraded.select(
        upgraded.reminders,
      )..where((t) => t.id.equals('rem-manual'))).getSingle();

      expect(reminder.title, 'تذكير يدوي');
      expect(reminder.isManual, isTrue);
      expect(reminder.status, ReminderStatus.pending);
    });

    test('drops reminders.document_id at the physical schema level', () async {
      expect(await _remindersColumns(upgraded), isNot(contains('document_id')));
    });

    test('keeps the surviving reminder tables indexed', () async {
      final indexes = await upgraded
          .customSelect(
            'SELECT name FROM sqlite_master '
            "WHERE type = 'index' AND tbl_name = 'reminders'",
          )
          .map((r) => r.read<String>('name'))
          .get();

      expect(
        indexes,
        containsAll(['reminders_event_date', 'reminders_status']),
      );
      expect(indexes, isNot(contains('reminders_document')));
    });

    test('adds the empty paper tables', () async {
      expect(await upgraded.select(upgraded.papers).get(), isEmpty);
      expect(await upgraded.select(upgraded.paperParagraphs).get(), isEmpty);
      expect(await upgraded.select(upgraded.paperSpans).get(), isEmpty);
    });
  });

  group('app_settings', () {
    test('getSetting returns null for an unknown key', () async {
      expect(await db.getSetting('locale'), isNull);
    });

    test('setSetting then getSetting round-trips', () async {
      await db.setSetting('locale', 'ar');
      expect(await db.getSetting('locale'), 'ar');
    });

    test('setSetting upserts an existing key', () async {
      await db.setSetting('locale', 'ar');
      await db.setSetting('locale', 'en');
      expect(await db.getSetting('locale'), 'en');
    });
  });
}

/// A database carrying the v1 schema and one row of v1 data, so opening
/// [AppDatabase] over it runs the real 1 → 3 upgrade.
QueryExecutor _versionOneDatabase() {
  return NativeDatabase.memory(
    setup: (raw) {
      raw
        ..execute(
          'CREATE TABLE app_settings ('
          'key TEXT NOT NULL, value TEXT NOT NULL, '
          'updated_at INTEGER NOT NULL, PRIMARY KEY (key))',
        )
        ..execute(
          'CREATE TABLE usage_cache ('
          'usage_date INTEGER NOT NULL, daily_limit INTEGER NOT NULL, '
          'used_count INTEGER NOT NULL, remaining_count INTEGER NOT NULL, '
          'resets_at INTEGER NOT NULL, last_synced_at INTEGER, '
          'PRIMARY KEY (usage_date))',
        )
        ..execute("INSERT INTO app_settings VALUES ('locale', 'ar', 0)")
        ..execute('PRAGMA user_version = 1');
    },
  );
}

/// A database carrying the v2 schema (F08's document tables already applied)
/// and one row of settings, so opening [AppDatabase] over it runs only the
/// 2 → 3 upgrade branch (F09) — the path a device that already has F08
/// actually takes, as opposed to [_versionOneDatabase]'s "never shipped v1"
/// case, which happens to exercise both branches at once.
///
/// Every child table is created empty (F38's v4 wipe deletes from all seven
/// unconditionally, so a real v2 database — which always has them — needs
/// them here too; `Reminders.documentId`'s foreign key only needed
/// `documents` to exist, but the wipe needs the rest).
QueryExecutor _versionTwoDatabase() {
  return NativeDatabase.memory(
    setup: (raw) {
      raw
        ..execute(
          'CREATE TABLE app_settings ('
          'key TEXT NOT NULL, value TEXT NOT NULL, '
          'updated_at INTEGER NOT NULL, PRIMARY KEY (key))',
        )
        ..execute(
          'CREATE TABLE usage_cache ('
          'usage_date INTEGER NOT NULL, daily_limit INTEGER NOT NULL, '
          'used_count INTEGER NOT NULL, remaining_count INTEGER NOT NULL, '
          'resets_at INTEGER NOT NULL, last_synced_at INTEGER, '
          'PRIMARY KEY (usage_date))',
        )
        ..execute(
          'CREATE TABLE documents ('
          'id TEXT NOT NULL, title TEXT NOT NULL, category TEXT NOT NULL, '
          'kind TEXT NOT NULL, status TEXT NOT NULL, '
          'kind_confidence TEXT NOT NULL, summary_short TEXT NOT NULL, '
          'summary_detailed TEXT NOT NULL, extracted_text TEXT NOT NULL, '
          'storage_mode TEXT NOT NULL, encrypted_image_path TEXT, '
          'note TEXT, session_id TEXT NOT NULL, saved_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL, PRIMARY KEY (id))',
        )
        ..execute(
          'CREATE TABLE document_key_information ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'label TEXT NOT NULL, value TEXT NOT NULL, '
          'confidence TEXT NOT NULL, source TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_dates ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'label TEXT NOT NULL, date INTEGER NOT NULL, '
          'minute_of_day INTEGER, role TEXT NOT NULL, '
          'is_reminder_worthy INTEGER NOT NULL, confidence TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_amounts ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'label TEXT NOT NULL, value REAL NOT NULL, '
          'currency TEXT NOT NULL, confidence TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_actions ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'description TEXT NOT NULL, basis TEXT NOT NULL, '
          'priority TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_warnings ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'message TEXT NOT NULL, kind TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_text_items ('
          'document_id TEXT NOT NULL, kind TEXT NOT NULL, '
          'position INTEGER NOT NULL, value TEXT NOT NULL, '
          'PRIMARY KEY (document_id, kind, position))',
        )
        ..execute("INSERT INTO app_settings VALUES ('locale', 'ar', 0)")
        ..execute('PRAGMA user_version = 2');
    },
  );
}

/// A database carrying the v3 schema (F09's reminder tables already
/// applied), with a saved document, every one of its six child rows, a
/// reminder linked to that document with its own alert, and an unrelated
/// manual reminder with its own alert — so opening [AppDatabase] over it
/// runs the real 3 → 4 upgrade (F38) and proves both halves of it: the
/// legacy wipe, and that only the reminder with nothing left to point at is
/// the one that goes with it.
QueryExecutor _versionThreeDatabase() {
  return NativeDatabase.memory(
    setup: (raw) {
      raw
        ..execute(
          'CREATE TABLE app_settings ('
          'key TEXT NOT NULL, value TEXT NOT NULL, '
          'updated_at INTEGER NOT NULL, PRIMARY KEY (key))',
        )
        ..execute(
          'CREATE TABLE usage_cache ('
          'usage_date INTEGER NOT NULL, daily_limit INTEGER NOT NULL, '
          'used_count INTEGER NOT NULL, remaining_count INTEGER NOT NULL, '
          'resets_at INTEGER NOT NULL, last_synced_at INTEGER, '
          'PRIMARY KEY (usage_date))',
        )
        ..execute(
          'CREATE TABLE documents ('
          'id TEXT NOT NULL, title TEXT NOT NULL, category TEXT NOT NULL, '
          'kind TEXT NOT NULL, status TEXT NOT NULL, '
          'kind_confidence TEXT NOT NULL, summary_short TEXT NOT NULL, '
          'summary_detailed TEXT NOT NULL, extracted_text TEXT NOT NULL, '
          'storage_mode TEXT NOT NULL, encrypted_image_path TEXT, '
          'note TEXT, session_id TEXT NOT NULL, saved_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL, PRIMARY KEY (id))',
        )
        ..execute(
          'CREATE TABLE document_key_information ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'label TEXT NOT NULL, value TEXT NOT NULL, '
          'confidence TEXT NOT NULL, source TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_dates ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'label TEXT NOT NULL, date INTEGER NOT NULL, '
          'minute_of_day INTEGER, role TEXT NOT NULL, '
          'is_reminder_worthy INTEGER NOT NULL, confidence TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_amounts ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'label TEXT NOT NULL, value REAL NOT NULL, '
          'currency TEXT NOT NULL, confidence TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_actions ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'description TEXT NOT NULL, basis TEXT NOT NULL, '
          'priority TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_warnings ('
          'document_id TEXT NOT NULL, position INTEGER NOT NULL, '
          'message TEXT NOT NULL, kind TEXT NOT NULL, '
          'PRIMARY KEY (document_id, position))',
        )
        ..execute(
          'CREATE TABLE document_text_items ('
          'document_id TEXT NOT NULL, kind TEXT NOT NULL, '
          'position INTEGER NOT NULL, value TEXT NOT NULL, '
          'PRIMARY KEY (document_id, kind, position))',
        )
        ..execute(
          'CREATE TABLE reminders ('
          'id TEXT NOT NULL, document_id TEXT, title TEXT NOT NULL, '
          'description TEXT, event_date INTEGER NOT NULL, '
          'event_minute_of_day INTEGER, status TEXT NOT NULL, '
          'is_manual INTEGER NOT NULL, created_at INTEGER NOT NULL, '
          'updated_at INTEGER NOT NULL, completed_at INTEGER, '
          'PRIMARY KEY (id))',
        )
        ..execute('CREATE INDEX reminders_event_date ON reminders (event_date)')
        ..execute('CREATE INDEX reminders_status ON reminders (status)')
        ..execute('CREATE INDEX reminders_document ON reminders (document_id)')
        ..execute(
          'CREATE TABLE reminder_alerts ('
          'id TEXT NOT NULL, reminder_id TEXT NOT NULL, '
          'scheduled_at INTEGER NOT NULL, notification_id INTEGER NOT NULL, '
          'status TEXT NOT NULL, created_at INTEGER NOT NULL, '
          'PRIMARY KEY (id))',
        )
        ..execute(
          'INSERT INTO documents VALUES '
          "('doc-1', 'فاتورة كهرباء', "
          "'invoice', 'invoice', 'complete', 'high', 'ملخص', 'شرح', 'نص', "
          "'resultOnly', NULL, NULL, 's1', 0, 0)",
        )
        ..execute(
          'INSERT INTO document_key_information VALUES '
          "('doc-1', 0, 'رقم العداد', '12345', 'high', 'readFromPaper')",
        )
        ..execute(
          'INSERT INTO document_dates VALUES '
          "('doc-1', 0, 'تاريخ الاستحقاق', 0, NULL, 'deadline', 1, 'high')",
        )
        ..execute(
          'INSERT INTO document_amounts VALUES '
          "('doc-1', 0, 'المطلوب', 150.0, 'EGP', 'high')",
        )
        ..execute(
          'INSERT INTO document_actions VALUES '
          "('doc-1', 0, 'ادفع الفاتورة', 'writtenOnPaper', 'high')",
        )
        ..execute(
          'INSERT INTO document_warnings VALUES '
          "('doc-1', 0, 'تحذير', 'overdue')",
        )
        ..execute(
          'INSERT INTO document_text_items VALUES '
          "('doc-1', 'instruction', 0, 'روح الفرع')",
        )
        ..execute(
          "INSERT INTO reminders VALUES ('rem-linked', 'doc-1', "
          "'دفع فاتورة الكهرباء', NULL, 0, 600, 'pending', 0, 0, 0, NULL)",
        )
        ..execute(
          "INSERT INTO reminders VALUES ('rem-manual', NULL, "
          "'تذكير يدوي', NULL, 0, 600, 'pending', 1, 0, 0, NULL)",
        )
        ..execute(
          'INSERT INTO reminder_alerts VALUES '
          "('alert-linked', 'rem-linked', 0, 1, 'scheduled', 0)",
        )
        ..execute(
          'INSERT INTO reminder_alerts VALUES '
          "('alert-manual', 'rem-manual', 0, 2, 'scheduled', 0)",
        )
        ..execute("INSERT INTO app_settings VALUES ('locale', 'ar', 0)")
        ..execute('PRAGMA user_version = 3');
    },
  );
}

/// The column names SQLite actually has for `reminders`, read straight off
/// `PRAGMA table_info` — the one way to prove `document_id` is physically
/// gone rather than just absent from the Dart table class (F38-T05's own
/// done-when: "not by compiling").
Future<List<String>> _remindersColumns(AppDatabase db) {
  return db
      .customSelect('PRAGMA table_info(reminders)')
      .map((r) => r.read<String>('name'))
      .get();
}
