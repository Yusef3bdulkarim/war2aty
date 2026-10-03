import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/domain/entities/camera_capabilities.dart';
import 'package:war2aty/features/capture/domain/entities/focus_point.dart';

void main() {
  group('FocusPoint', () {
    test('keeps an in-range point as given', () {
      final point = FocusPoint(0.25, 0.75);

      expect(point.x, 0.25);
      expect(point.y, 0.75);
    });

    test('clamps a point past the edges into the preview', () {
      final point = FocusPoint(-0.2, 1.3);

      expect(point, FocusPoint(0, 1));
    });

    test('a non-number falls back to the centre on that axis', () {
      final point = FocusPoint(double.nan, 0.4);

      expect(point, FocusPoint(0.5, 0.4));
    });

    test('equal fractions are equal points', () {
      expect(FocusPoint(0.3, 0.6), FocusPoint(0.3, 0.6));
      expect(FocusPoint(0.3, 0.6).hashCode, FocusPoint(0.3, 0.6).hashCode);
    });
  });

  group('CameraCapabilities', () {
    test('none offers neither a flash nor focus', () {
      expect(CameraCapabilities.none.hasFlash, isFalse);
      expect(CameraCapabilities.none.canFocus, isFalse);
    });

    test('equal flags are equal capabilities', () {
      const a = CameraCapabilities(hasFlash: true, canFocus: false);
      const b = CameraCapabilities(hasFlash: true, canFocus: false);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(CameraCapabilities.none));
    });
  });
}
