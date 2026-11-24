import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/reading_speed.dart';

void main() {
  group('ReadingSpeed.multiplier', () {
    test('slower is 0.75', () {
      expect(ReadingSpeed.slower.multiplier, 0.75);
    });

    test('normal is 1.0', () {
      expect(ReadingSpeed.normal.multiplier, 1.0);
    });

    test('faster is 1.25', () {
      expect(ReadingSpeed.faster.multiplier, 1.25);
    });

    test('fastest is 1.5', () {
      expect(ReadingSpeed.fastest.multiplier, 1.5);
    });

    test('label is unchanged for all values', () {
      expect(ReadingSpeed.slower.label, '0.75x');
      expect(ReadingSpeed.normal.label, '1x');
      expect(ReadingSpeed.faster.label, '1.25x');
      expect(ReadingSpeed.fastest.label, '1.5x');
    });
  });
}
