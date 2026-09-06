import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/domain/entities/document_quad.dart';
import 'package:war2aty/features/capture/domain/entities/unit_point.dart';
import 'package:war2aty/features/capture/presentation/frame_preview_mapper.dart';

/// Deliberately asymmetric on every axis, so a wrong rotation or a missing
/// mirror cannot pass by symmetry.
const _quad = DocumentQuad(
  topLeft: UnitPoint(0.1, 0.2),
  topRight: UnitPoint(0.6, 0.1),
  bottomRight: UnitPoint(0.7, 0.8),
  bottomLeft: UnitPoint(0.2, 0.7),
);

DocumentQuad map(
  DocumentQuad quad, {
  int sensorOrientation = 0,
  bool isMirrored = false,
  double frameAspect = 1,
  double previewAspect = 1,
  PreviewFit fit = PreviewFit.contain,
}) => FramePreviewMapper.mapToPreview(
  quad,
  sensorOrientation: sensorOrientation,
  isMirrored: isMirrored,
  frameAspect: frameAspect,
  previewAspect: previewAspect,
  fit: fit,
);

void expectQuad(
  DocumentQuad actual,
  List<UnitPoint> expected, {
  double tolerance = 1e-9,
}) {
  final corners = actual.corners;
  for (var i = 0; i < 4; i++) {
    expect(corners[i].x, closeTo(expected[i].x, tolerance), reason: 'x[$i]');
    expect(corners[i].y, closeTo(expected[i].y, tolerance), reason: 'y[$i]');
  }
}

void main() {
  group('FramePreviewMapper · rotation', () {
    test('an upright sensor changes nothing', () {
      expect(map(_quad), _quad);
    });

    test('90° maps (x, y) to (1 - y, x)', () {
      final mapped = map(_quad, sensorOrientation: 90);

      // TL(0.1,0.2)→(0.8,0.1)  TR(0.6,0.1)→(0.9,0.6)
      // BR(0.7,0.8)→(0.2,0.7)  BL(0.2,0.7)→(0.3,0.2)
      // Re-sorted, the top-left is now (0.3,0.2).
      expectQuad(mapped, const [
        UnitPoint(0.3, 0.2),
        UnitPoint(0.8, 0.1),
        UnitPoint(0.9, 0.6),
        UnitPoint(0.2, 0.7),
      ]);
    });

    test('180° maps (x, y) to (1 - x, 1 - y)', () {
      final mapped = map(_quad, sensorOrientation: 180);

      expectQuad(mapped, const [
        UnitPoint(0.3, 0.2),
        UnitPoint(0.8, 0.3),
        UnitPoint(0.9, 0.8),
        UnitPoint(0.4, 0.9),
      ]);
    });

    test('270° maps (x, y) to (y, 1 - x)', () {
      final mapped = map(_quad, sensorOrientation: 270);

      // TL(0.1,0.2)→(0.2,0.9)  TR(0.6,0.1)→(0.1,0.4)
      // BR(0.7,0.8)→(0.8,0.3)  BL(0.2,0.7)→(0.7,0.8)
      expectQuad(mapped, const [
        UnitPoint(0.1, 0.4),
        UnitPoint(0.8, 0.3),
        UnitPoint(0.7, 0.8),
        UnitPoint(0.2, 0.9),
      ]);
    });

    test('four quarter turns come back to where they started', () {
      var quad = _quad;
      for (var i = 0; i < 4; i++) {
        quad = map(quad, sensorOrientation: 90);
      }

      expectQuad(quad, _quad.corners);
    });

    test('an orientation that is not a right angle is treated as upright', () {
      expect(map(_quad, sensorOrientation: 45), _quad);
    });

    test('orientations beyond a full turn wrap', () {
      expect(
        map(_quad, sensorOrientation: 450),
        map(_quad, sensorOrientation: 90),
      );
    });
  });

  group('FramePreviewMapper · mirroring', () {
    test('a front lens flips horizontally', () {
      final mapped = map(_quad, isMirrored: true);

      expectQuad(mapped, const [
        UnitPoint(0.4, 0.1),
        UnitPoint(0.9, 0.2),
        UnitPoint(0.8, 0.7),
        UnitPoint(0.3, 0.8),
      ]);
    });

    test('the mirror is applied after the rotation, not before', () {
      final rotateThenMirror = map(
        _quad,
        sensorOrientation: 90,
        isMirrored: true,
      );

      // Mirroring first and then rotating would land on a different quad;
      // this is the assertion that pins the order.
      final mirrorFirst = map(
        map(_quad, isMirrored: true),
        sensorOrientation: 90,
      );

      expect(rotateThenMirror, isNot(mirrorFirst));
      // Rotate: TL→(0.8,0.1) TR→(0.9,0.6) BR→(0.2,0.7) BL→(0.3,0.2);
      // then mirror x, then re-sort into ring order.
      expectQuad(rotateThenMirror, const [
        UnitPoint(0.2, 0.1),
        UnitPoint(0.7, 0.2),
        UnitPoint(0.8, 0.7),
        UnitPoint(0.1, 0.6),
      ]);
    });
  });

  group('FramePreviewMapper · aspect fit', () {
    test('equal aspects are the identity', () {
      expect(map(_quad, frameAspect: 4 / 3, previewAspect: 4 / 3), _quad);
    });

    test('contain letterboxes a wide frame into a tall preview', () {
      final mapped = map(_quad, frameAspect: 4 / 3, previewAspect: 3 / 4);

      // The width binds; the frame occupies (3/4)/(4/3) = 0.5625 of the
      // height, centred — so y is squeezed and x untouched.
      final rect = mapped.boundingRect;
      expect(rect.left, closeTo(0.1, 1e-9));
      expect(rect.right, closeTo(0.7, 1e-9));
      expect(rect.top, closeTo(0.1 * 0.5625 + 0.21875, 1e-9));
      expect(rect.bottom, closeTo(0.8 * 0.5625 + 0.21875, 1e-9));
    });

    test('contain pillarboxes a tall frame into a wide preview', () {
      final mapped = map(_quad, frameAspect: 3 / 4, previewAspect: 4 / 3);

      final rect = mapped.boundingRect;
      expect(rect.top, closeTo(0.1, 1e-9));
      expect(rect.bottom, closeTo(0.8, 1e-9));
      expect(rect.left, closeTo(0.1 * 0.5625 + 0.21875, 1e-9));
    });

    test(
      'cover pushes the overflowing axis outside 0..1 rather than clamping',
      () {
        final mapped = map(
          _quad,
          frameAspect: 4 / 3,
          previewAspect: 3 / 4,
          fit: PreviewFit.cover,
        );

        // (4/3)/(3/4) = 1.777…, offset = -0.388…; the left edge lands below 0
        // and is left there — clamping belongs to boundingRect, not here.
        expect(
          mapped.corners.map((p) => p.x).reduce((a, b) => a < b ? a : b),
          lessThan(0),
        );
        expect(mapped.boundingRect.left, 0);
      },
    );

    test('a quarter turn swaps which frame axis the fit applies to', () {
      final upright = map(_quad, frameAspect: 4 / 3, previewAspect: 4 / 3);
      final turned = map(
        _quad,
        sensorOrientation: 90,
        frameAspect: 4 / 3,
        previewAspect: 4 / 3,
      );

      // Same aspects, but the rotated frame is 3:4 against a 4:3 preview, so
      // the turned quad must have been fitted while the upright one was not.
      expect(upright, _quad);
      expect(turned, isNot(map(_quad, sensorOrientation: 90)));
    });

    test('a degenerate aspect is left alone rather than dividing by zero', () {
      expect(map(_quad, frameAspect: 0), _quad);
      expect(map(_quad, previewAspect: 0), _quad);
    });
  });
}
