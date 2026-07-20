import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('schema is at version 1', () {
    expect(db.schemaVersion, 1);
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
