import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';

void main() {
  group('UnitRect.isFull', () {
    test('the whole-image sentinel is full', () {
      expect(UnitRect.full.isFull, isTrue);
    });

    test('a region tighter than the whole image is not full', () {
      const region = UnitRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9);
      expect(region.isFull, isFalse);
    });

    test('a region that overshoots the bounds still reads as full', () {
      const region = UnitRect(left: -0.1, top: -0.1, right: 1.1, bottom: 1.1);
      expect(region.isFull, isTrue);
    });
  });

  group('UnitRect.expanded', () {
    test('grows every side by the given fraction of its own size', () {
      const region = UnitRect(left: 0.2, top: 0.3, right: 0.6, bottom: 0.7);

      final expanded = region.expanded(0.2);

      // width 0.4 * 0.2 = 0.08 each side; height 0.4 * 0.2 = 0.08 each side.
      expect(expanded.left, closeTo(0.12, 1e-9));
      expect(expanded.top, closeTo(0.22, 1e-9));
      expect(expanded.right, closeTo(0.68, 1e-9));
      expect(expanded.bottom, closeTo(0.78, 1e-9));
    });

    test('clamps into the image bounds when the margin overshoots', () {
      const region = UnitRect(left: 0.05, top: 0.05, right: 0.95, bottom: 0.95);

      final expanded = region.expanded(0.5);

      expect(expanded.left, 0);
      expect(expanded.top, 0);
      expect(expanded.right, 1);
      expect(expanded.bottom, 1);
    });

    test('expanding the full image stays full', () {
      final expanded = UnitRect.full.expanded(0.2);

      expect(expanded, UnitRect.full);
    });
  });

  group('UnitRect.clamped', () {
    test('leaves an in-bounds region untouched', () {
      const region = UnitRect(left: 0.1, top: 0.2, right: 0.8, bottom: 0.9);

      expect(region.clamped(), region);
    });

    test('pulls out-of-range edges back into [0, 1]', () {
      const region = UnitRect(left: -0.5, top: -0.5, right: 1.5, bottom: 1.5);

      final clamped = region.clamped();

      expect(clamped, UnitRect.full);
    });
  });

  group('UnitRect equality', () {
    test('two rects with the same edges are equal', () {
      const a = UnitRect(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);
      const b = UnitRect(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different edge breaks equality', () {
      const a = UnitRect(left: 0.1, top: 0.2, right: 0.3, bottom: 0.4);
      const b = UnitRect(left: 0.15, top: 0.2, right: 0.3, bottom: 0.4);

      expect(a, isNot(b));
    });
  });
}
