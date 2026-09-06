import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  group('Arabic counts the noun by number', () {
    test('dual and plural are distinct forms, not "2 تحليلات"', () {
      expect(ar.homeUsageRemaining(1), contains('تحليل واحد'));
      expect(ar.homeUsageRemaining(2), contains('تحليلان'));
      expect(ar.homeUsageRemaining(3), contains('3 تحليلات'));
    });

    test('above ten the noun returns to the singular', () {
      // Reachable if the backend raises the daily limit.
      expect(ar.homeUsageRemaining(10), contains('10 تحليلات'));
      expect(ar.homeUsageRemaining(11), contains('11 تحليلًا'));
    });

    test('a spent quota reads as spent, never as "0 left"', () {
      expect(ar.homeUsageRemaining(0), 'استخدمت تحليلات النهارده.');
      expect(en.homeUsageRemaining(0), isNot(contains('0')));
    });

    test('English keeps singular and plural straight', () {
      expect(en.homeUsageRemaining(1), contains('1 analysis'));
      expect(en.homeUsageRemaining(2), contains('2 analyses'));
    });
  });
}
