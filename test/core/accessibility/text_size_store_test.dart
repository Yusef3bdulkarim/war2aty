import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/accessibility/text_size.dart';
import 'package:war2aty/core/accessibility/text_size_store.dart';
import 'package:war2aty/core/database/app_database.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late DriftTextSizeStore store;

  setUp(() {
    db = memoryDatabase();
    store = DriftTextSizeStore(db);
  });

  tearDown(() => db.close());

  test('readSize() returns null when nothing has been written', () async {
    expect(await store.readSize(), isNull);
  });

  test('writeSize() then readSize() round-trips every value', () async {
    for (final size in TextSize.values) {
      await store.writeSize(size);
      expect(await store.readSize(), size);
    }
  });

  test('readSize() returns null for an unrecognised stored value', () async {
    // Write a raw value that does not match any enum name.
    await db.setSetting('text_size', 'unknown_future_value');
    expect(await store.readSize(), isNull);
  });
}
