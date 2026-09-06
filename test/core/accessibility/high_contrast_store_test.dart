import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/accessibility/high_contrast_store.dart';
import 'package:war2aty/core/database/app_database.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late DriftHighContrastStore store;

  setUp(() {
    db = memoryDatabase();
    store = DriftHighContrastStore(db);
  });

  tearDown(() => db.close());

  test('readEnabled() returns null when nothing has been written', () async {
    expect(await store.readEnabled(), isNull);
  });

  test(
    'writeEnabled() then readEnabled() round-trips true and false',
    () async {
      await store.writeEnabled(true);
      expect(await store.readEnabled(), isTrue);

      await store.writeEnabled(false);
      expect(await store.readEnabled(), isFalse);
    },
  );
}
