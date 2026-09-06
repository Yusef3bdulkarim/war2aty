import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';

import '../../../support/fakes.dart';

// F11-T07: the default reading speed setting's own read side.
void main() {
  test('defaults to normal when the user has never set it', () async {
    final useCase = GetDefaultReadingSpeed(FakeDefaultReadingSpeedStore());

    expect(await useCase(), ReadingSpeed.normal);
  });

  test('reflects an explicit choice', () async {
    final useCase = GetDefaultReadingSpeed(
      FakeDefaultReadingSpeedStore(ReadingSpeed.fastest),
    );

    expect(await useCase(), ReadingSpeed.fastest);
  });
}
