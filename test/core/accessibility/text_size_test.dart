import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/accessibility/text_size.dart';

// F27-T15: the app used to replace `MediaQuery.textScaler` with the in-app
// choice outright, so a phone set to 200 % in Android's accessibility settings
// rendered this app at 100 %. `resolveTextScaler` takes the larger of the two
// instead, capped at the scale the layout sweep underwrites.
void main() {
  /// The effective multiplier, read the way the app reads it.
  double factorOf(TextScaler scaler) => scaler.scale(14) / 14;

  group('TextSize.factor', () {
    test('matches the percentages the settings screen offers', () {
      expect(TextSize.normal.factor, 1);
      expect(TextSize.large.factor, 1.25);
      expect(TextSize.veryLarge.factor, 1.5);
    });

    test('agrees with the standalone scaler it has always exposed', () {
      for (final size in TextSize.values) {
        expect(factorOf(size.scaler), closeTo(size.factor, 0.0001));
      }
    });
  });

  group('resolveTextScaler', () {
    test('a phone with no scaling of its own leaves the choice alone', () {
      for (final size in TextSize.values) {
        expect(
          factorOf(resolveTextScaler(TextScaler.noScaling, size)),
          closeTo(size.factor, 0.0001),
          reason: size.name,
        );
      }
    });

    test('the OS wins when it asks for more than the in-app choice', () {
      // The case that was broken: nothing chosen in-app, 200 % on the phone.
      expect(
        factorOf(
          resolveTextScaler(const TextScaler.linear(2), TextSize.normal),
        ),
        closeTo(2, 0.0001),
      );
      expect(
        factorOf(
          resolveTextScaler(const TextScaler.linear(1.8), TextSize.large),
        ),
        closeTo(1.8, 0.0001),
      );
    });

    test('the in-app choice wins when the OS asks for less', () {
      // And so the control still does something on a phone set to default.
      expect(
        factorOf(
          resolveTextScaler(const TextScaler.linear(1.1), TextSize.veryLarge),
        ),
        closeTo(1.5, 0.0001),
      );
    });

    test('never shrinks text below what the phone asked for', () {
      // The reason for "larger of the two" rather than "the OS, full stop":
      // picking a size in-app must not undo the system setting.
      for (final os in [1.0, 1.3, 1.6, 2.0]) {
        for (final size in TextSize.values) {
          final resolved = factorOf(
            resolveTextScaler(TextScaler.linear(os), size),
          );
          expect(
            resolved,
            greaterThanOrEqualTo(os - 0.0001),
            reason: 'os $os with ${size.name}',
          );
        }
      }
    });

    test('caps at the scale the layout sweep covers', () {
      expect(kMaxTextScale, 2);
      expect(
        factorOf(
          resolveTextScaler(const TextScaler.linear(4), TextSize.veryLarge),
        ),
        closeTo(kMaxTextScale, 0.0001),
      );
    });

    test('never scales below 1, whatever the phone says', () {
      // Some platforms can report a factor under 1. The design has no smaller
      // size, and shrinking it was never on offer.
      expect(
        factorOf(
          resolveTextScaler(const TextScaler.linear(0.8), TextSize.normal),
        ),
        closeTo(1, 0.0001),
      );
    });

    test('reads a non-linear platform scaler at a body size', () {
      // Android 14 onward the system curve is non-linear: small text grows
      // more than large text. Reading it at 1 logical pixel would be
      // meaningless, so the resolver samples it at 14.
      final resolved = resolveTextScaler(
        const _NonLinearScaler(),
        TextSize.normal,
      );

      expect(factorOf(resolved), closeTo(1.4, 0.0001));
    });
  });
}

/// A scaler whose factor depends on the font size, the way a platform curve
/// does: 1.4x at a body size, far more at 1 logical pixel.
final class _NonLinearScaler extends TextScaler {
  const _NonLinearScaler();

  @override
  double scale(double fontSize) => fontSize == 1 ? 3 : fontSize * 1.4;

  @override
  double get textScaleFactor => 1.4;
}
