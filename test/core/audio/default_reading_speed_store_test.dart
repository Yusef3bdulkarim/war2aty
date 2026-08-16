import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/default_reading_speed_store.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/database/app_database.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late DriftDefaultReadingSpeedStore store;

  setUp(() {
    db = memoryDatabase();
    store = DriftDefaultReadingSpeedStore(db);
  });

  tearDown(() => db.close());

  test('readSpeed() returns null when nothing has been written', () async {
    expect(await store.readSpeed(), isNull);
  });

  test('writeSpeed() then readSpeed() round-trips the choice', () async {
    await store.writeSpeed(ReadingSpeed.faster);
    expect(await store.readSpeed(), ReadingSpeed.faster);

    await store.writeSpeed(ReadingSpeed.slower);
    expect(await store.readSpeed(), ReadingSpeed.slower);
  });
}
