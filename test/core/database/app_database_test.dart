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

  test('schema is at version 2', () {
    expect(db.schemaVersion, 2);
  });

  test('foreign keys are enforced once the database is open', () async {
    final row = await db
        .customSelect('PRAGMA foreign_keys')
        .map((r) => r.read<int>('foreign_keys'))
        .getSingle();

    expect(row, 1);
  });

  group('migration to v2', () {
    late AppDatabase upgraded;

    setUp(() => upgraded = AppDatabase(_versionOneDatabase()));
    tearDown(() => upgraded.close());

    test('keeps the settings a v1 database already held', () async {
      expect(await upgraded.getSetting('locale'), 'ar');
    });

    test('adds the document tables', () async {
      expect(await upgraded.select(upgraded.documents).get(), isEmpty);
      expect(await upgraded.select(upgraded.documentDates).get(), isEmpty);
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
/// [AppDatabase] over it runs the real 1 → 2 upgrade.
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
