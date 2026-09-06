import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/set_default_reading_speed.dart';

import '../../../support/fakes.dart';

// F11-T07: the default reading speed setting's own write side.
void main() {
  test('persists the choice so a later read reflects it', () async {
    final store = FakeDefaultReadingSpeedStore();
    final setSpeed = SetDefaultReadingSpeed(store);
    final getSpeed = GetDefaultReadingSpeed(store);

    await setSpeed(ReadingSpeed.slower);

    expect(await getSpeed(), ReadingSpeed.slower);
  });

  test('picking a new speed overwrites the previous one', () async {
    final store = FakeDefaultReadingSpeedStore(ReadingSpeed.slower);
    final setSpeed = SetDefaultReadingSpeed(store);
    final getSpeed = GetDefaultReadingSpeed(store);

    await setSpeed(ReadingSpeed.fastest);

    expect(await getSpeed(), ReadingSpeed.fastest);
  });
}
