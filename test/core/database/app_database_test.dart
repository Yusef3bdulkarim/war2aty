// `isNull` is a drift SQL expression too; the matcher wins here.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('schema is at version 3', () {
    expect(db.schemaVersion, 3);
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
    // this exercises both `onUpgrade` branches in one open — the same path a
    // v1-schema device would actually take.
    test('adds the reminder tables (v3)', () async {
      expect(await upgraded.select(upgraded.reminders).get(), isEmpty);
      expect(await upgraded.select(upgraded.reminderAlerts).get(), isEmpty);
    });
  });

  group('migration from v2', () {
    late AppDatabase upgraded;

    setUp(() => upgraded = AppDatabase(_versionTwoDatabase()));
    tearDown(() => upgraded.close());

    test('keeps the settings a v2 database already held', () async {
      expect(await upgraded.getSetting('locale'), 'ar');
    });

    test('adds the reminder tables without touching document data', () async {
      expect(await upgraded.select(upgraded.reminders).get(), isEmpty);
      expect(await upgraded.select(upgraded.reminderAlerts).get(), isEmpty);
      expect(await upgraded.select(upgraded.documents).get(), isEmpty);
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
/// Only `documents` itself is created, not its child tables — nothing here
/// touches them, and `Reminders.documentId`'s foreign key only needs the
/// table it references to exist.
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
        ..execute("INSERT INTO app_settings VALUES ('locale', 'ar', 0)")
        ..execute('PRAGMA user_version = 2');
    },
  );
}
