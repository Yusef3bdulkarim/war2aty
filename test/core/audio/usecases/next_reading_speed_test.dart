import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/usecases/next_reading_speed.dart';

void main() {
  late NextReadingSpeed useCase;

  setUp(() {
    useCase = const NextReadingSpeed();
  });

  group('NextReadingSpeed — cycle 1x → 1.25x → 1.5x → 0.75x → 1x', () {
    test('normal advances to faster', () {
      expect(useCase(ReadingSpeed.normal), ReadingSpeed.faster);
    });

    test('faster advances to fastest', () {
      expect(useCase(ReadingSpeed.faster), ReadingSpeed.fastest);
    });

    test('fastest wraps to slower', () {
      expect(useCase(ReadingSpeed.fastest), ReadingSpeed.slower);
    });

    test('slower wraps back to normal', () {
      expect(useCase(ReadingSpeed.slower), ReadingSpeed.normal);
    });

    test('a full cycle from normal returns to normal', () {
      ReadingSpeed speed = ReadingSpeed.normal;
      for (var i = 0; i < 4; i++) {
        speed = useCase(speed);
      }
      expect(speed, ReadingSpeed.normal);
    });
  });
}
