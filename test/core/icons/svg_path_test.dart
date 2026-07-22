import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/svg_path.dart';

/// Compares two rects loosely — arcs are flattened to curves, so bounds land
/// within a hair of the mathematical answer rather than exactly on it.
Matcher _closeToRect(Rect expected, {double epsilon = 0.01}) => predicate<Rect>(
  (actual) =>
      (actual.left - expected.left).abs() < epsilon &&
      (actual.top - expected.top).abs() < epsilon &&
      (actual.right - expected.right).abs() < epsilon &&
      (actual.bottom - expected.bottom).abs() < epsilon,
  'within $epsilon of $expected',
);

void main() {
  group('parseSvgPath', () {
    test('absolute move and lines', () {
      final path = parseSvgPath('M0 0 L10 0 L10 6 Z');

      expect(path.getBounds(), _closeToRect(const Rect.fromLTRB(0, 0, 10, 6)));
      expect(path.contains(const Offset(9, 1)), isTrue);
    });

    test('lowercase commands are relative to the current point', () {
      final absolute = parseSvgPath('M5 5 L15 5 L15 15');
      final relative = parseSvgPath('m5 5 l10 0 l0 10');

      expect(relative.getBounds(), _closeToRect(absolute.getBounds()));
    });

    test('h and v draw axis-aligned lines', () {
      final path = parseSvgPath('M2 2 h8 v4 H2 z');

      expect(path.getBounds(), _closeToRect(const Rect.fromLTRB(2, 2, 10, 6)));
    });

    test('repeated parameter sets reuse the last command letter', () {
      final repeated = parseSvgPath('M0 0 L5 0 5 5 0 5');
      final spelled = parseSvgPath('M0 0 L5 0 L5 5 L0 5');

      expect(repeated.getBounds(), _closeToRect(spelled.getBounds()));
    });

    test('extra pairs after M are treated as line-tos, not moves', () {
      // If they were moves the path would have no length between the points.
      final path = parseSvgPath('M0 0 10 0');

      expect(path.computeMetrics().first.length, closeTo(10, 0.01));
    });

    test('S mirrors the previous cubic control point', () {
      // The reflection of (5,5) about (10,0) is (15,-5).
      final smooth = parseSvgPath('M0 0 C0 5 5 5 10 0 S20 5 20 0');
      final spelled = parseSvgPath('M0 0 C0 5 5 5 10 0 C15 -5 20 5 20 0');

      expect(smooth.getBounds(), _closeToRect(spelled.getBounds()));
    });

    test('S with no preceding curve reuses the current point', () {
      final path = parseSvgPath('M0 0 S5 5 10 0');

      expect(path.getBounds().right, closeTo(10, 0.01));
    });

    test('T mirrors the previous quadratic control point', () {
      final smooth = parseSvgPath('M0 0 Q5 10 10 0 T20 0');
      final spelled = parseSvgPath('M0 0 Q5 10 10 0 Q15 -10 20 0');

      expect(smooth.getBounds(), _closeToRect(spelled.getBounds()));
    });

    test('arcs honour SVG radius, large-arc and sweep flags', () {
      // The canonical circle-as-path idiom: centre (12,12), radius 3.
      final circle = parseSvgPath('M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0');

      expect(
        circle.getBounds(),
        _closeToRect(const Rect.fromLTRB(9, 9, 15, 15), epsilon: 0.05),
      );
    });

    test('sweep flag decides which way the arc bulges', () {
      // Flutter's `clockwise` maps straight onto SVG's sweep flag. In SVG's
      // y-down space sweep=1 sweeps clockwise on screen, which from (0,0) to
      // (10,0) means bulging upward into negative y.
      final sweepOne = parseSvgPath('M0 0 A5 5 0 0 1 10 0');
      final sweepZero = parseSvgPath('M0 0 A5 5 0 0 0 10 0');

      expect(
        sweepOne.getBounds(),
        _closeToRect(const Rect.fromLTRB(0, -5, 10, 0)),
      );
      expect(
        sweepZero.getBounds(),
        _closeToRect(const Rect.fromLTRB(0, 0, 10, 5)),
      );
    });

    test('z returns to the start of the current sub-path', () {
      final path = parseSvgPath('M0 0 L10 0 L10 10 Z');
      final metric = path.computeMetrics().first;

      // Two sides of 10 plus the closing diagonal back to the start.
      expect(metric.length, closeTo(20 + 14.142, 0.01));
      expect(metric.isClosed, isTrue);
    });

    test('a second M starts a new sub-path', () {
      final path = parseSvgPath('M0 0 L5 0 M10 0 L15 0');

      expect(path.computeMetrics().length, 2);
    });

    test('handles the numeric shorthands the design uses', () {
      // Leading dot, no separator before a negative number.
      final path = parseSvgPath('M.5 .5l.1.1a2 2 0 1 1-2.8 2.8');

      expect(path.computeMetrics(), isNotEmpty);
    });

    test('rejects an unknown command rather than drawing something wrong', () {
      // Silently skipping it would draw a plausible-looking but wrong shape.
      expect(() => parseSvgPath('M0 0 K5 5'), throwsFormatException);
      expect(() => parseSvgPath('M0 0 L5 5 <path>'), throwsFormatException);
    });
  });
}
