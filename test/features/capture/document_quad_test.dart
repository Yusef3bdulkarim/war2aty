import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/domain/entities/document_quad.dart';
import 'package:war2aty/features/capture/domain/entities/unit_point.dart';

/// [points] rotated by [degrees] about the frame's centre — how a page looks
/// when the phone is not perfectly square to it.
List<UnitPoint> _rotated(List<UnitPoint> points, double degrees) {
  final radians = degrees * math.pi / 180;
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  return [
    for (final p in points)
      UnitPoint(
        0.5 + (p.x - 0.5) * cos - (p.y - 0.5) * sin,
        0.5 + (p.x - 0.5) * sin + (p.y - 0.5) * cos,
      ),
  ];
}

const _square = [
  UnitPoint(0.2, 0.2),
  UnitPoint(0.8, 0.2),
  UnitPoint(0.8, 0.8),
  UnitPoint(0.2, 0.8),
];

void main() {
  group('DocumentQuad.fromPoints', () {
    test('orders a shuffled square into TL/TR/BR/BL', () {
      final quad = DocumentQuad.fromPoints(const [
        UnitPoint(0.8, 0.8),
        UnitPoint(0.2, 0.8),
        UnitPoint(0.8, 0.2),
        UnitPoint(0.2, 0.2),
      ])!;

      expect(quad.topLeft, const UnitPoint(0.2, 0.2));
      expect(quad.topRight, const UnitPoint(0.8, 0.2));
      expect(quad.bottomRight, const UnitPoint(0.8, 0.8));
      expect(quad.bottomLeft, const UnitPoint(0.2, 0.8));
    });

    test('orders a rotated page so the corners still go round the ring', () {
      final rotated = _rotated(_square, 20);

      final quad = DocumentQuad.fromPoints([...rotated.reversed])!;

      // Whatever the rotation, consecutive corners must be adjacent on the
      // paper (a side), never diagonal — a diagonal pairing is the bow-tie
      // ordering bug, and it shows up as a non-convex quad.
      expect(quad.isConvex, isTrue);
      expect(quad.area, closeTo(0.36, 1e-9));
    });

    test('rejects anything that is not exactly four points', () {
      expect(DocumentQuad.fromPoints(_square.take(3).toList()), isNull);
      expect(
        DocumentQuad.fromPoints([..._square, const UnitPoint(0.5, 0.5)]),
        isNull,
      );
      expect(DocumentQuad.fromPoints(const []), isNull);
    });
  });

  group('DocumentQuad.area', () {
    test('the whole frame is 1.0', () {
      const quad = DocumentQuad(
        topLeft: UnitPoint(0, 0),
        topRight: UnitPoint(1, 0),
        bottomRight: UnitPoint(1, 1),
        bottomLeft: UnitPoint(0, 1),
      );

      expect(quad.area, closeTo(1, 1e-9));
    });

    test('half the frame is 0.5', () {
      const quad = DocumentQuad(
        topLeft: UnitPoint(0, 0),
        topRight: UnitPoint(1, 0),
        bottomRight: UnitPoint(1, 0.5),
        bottomLeft: UnitPoint(0, 0.5),
      );

      expect(quad.area, closeTo(0.5, 1e-9));
    });

    test('is unchanged by rotating the same page', () {
      final quad = DocumentQuad.fromPoints(_rotated(_square, 35))!;

      expect(quad.area, closeTo(0.36, 1e-9));
    });
  });

  group('DocumentQuad.boundingRect', () {
    test('is the min/max box of the corners', () {
      const quad = DocumentQuad(
        topLeft: UnitPoint(0.2, 0.3),
        topRight: UnitPoint(0.7, 0.15),
        bottomRight: UnitPoint(0.8, 0.6),
        bottomLeft: UnitPoint(0.25, 0.75),
      );

      final rect = quad.boundingRect;

      expect(rect.left, closeTo(0.2, 1e-9));
      expect(rect.top, closeTo(0.15, 1e-9));
      expect(rect.right, closeTo(0.8, 1e-9));
      expect(rect.bottom, closeTo(0.75, 1e-9));
    });

    test('clamps corners that fall outside the frame', () {
      const quad = DocumentQuad(
        topLeft: UnitPoint(-0.2, -0.1),
        topRight: UnitPoint(1.3, -0.1),
        bottomRight: UnitPoint(1.3, 1.4),
        bottomLeft: UnitPoint(-0.2, 1.4),
      );

      final rect = quad.boundingRect;

      expect(rect.left, 0);
      expect(rect.top, 0);
      expect(rect.right, 1);
      expect(rect.bottom, 1);
    });
  });

  group('DocumentQuad.isValid', () {
    test('accepts a clean page', () {
      expect(DocumentQuad.fromPoints(_square)!.isValid(), isTrue);
    });

    test('accepts a perspective-skewed page', () {
      const quad = DocumentQuad(
        topLeft: UnitPoint(0.3, 0.2),
        topRight: UnitPoint(0.75, 0.25),
        bottomRight: UnitPoint(0.85, 0.8),
        bottomLeft: UnitPoint(0.15, 0.7),
      );

      expect(quad.isValid(), isTrue);
    });

    test('rejects collinear corners', () {
      const quad = DocumentQuad(
        topLeft: UnitPoint(0.1, 0.5),
        topRight: UnitPoint(0.4, 0.5),
        bottomRight: UnitPoint(0.7, 0.5),
        bottomLeft: UnitPoint(0.9, 0.5),
      );

      expect(quad.isValid(), isFalse);
    });

    test('rejects a bow tie', () {
      // The same four corners as a square, but paired diagonally.
      const quad = DocumentQuad(
        topLeft: UnitPoint(0.2, 0.2),
        topRight: UnitPoint(0.8, 0.2),
        bottomRight: UnitPoint(0.2, 0.8),
        bottomLeft: UnitPoint(0.8, 0.8),
      );

      expect(quad.isConvex, isFalse);
      expect(quad.isValid(), isFalse);
    });

    test('rejects a quad smaller than the minimum area', () {
      final quad = DocumentQuad.fromPoints(const [
        UnitPoint(0.45, 0.45),
        UnitPoint(0.58, 0.45),
        UnitPoint(0.58, 0.58),
        UnitPoint(0.45, 0.58),
      ])!;

      expect(quad.area, lessThan(DocumentQuad.defaultMinArea));
      expect(quad.isValid(), isFalse);
    });

    test('honours a caller-supplied minimum area', () {
      final quad = DocumentQuad.fromPoints(_square)!;

      expect(quad.isValid(minArea: 0.3), isTrue);
      expect(quad.isValid(minArea: 0.5), isFalse);
    });

    test('rejects collapsed corners', () {
      const quad = DocumentQuad(
        topLeft: UnitPoint(0.2, 0.2),
        topRight: UnitPoint(0.2, 0.2),
        bottomRight: UnitPoint(0.8, 0.8),
        bottomLeft: UnitPoint(0.2, 0.8),
      );

      expect(quad.isValid(), isFalse);
    });
  });

  group('DocumentQuad.lerpTo', () {
    final from = DocumentQuad.fromPoints(_square)!;
    final to = DocumentQuad.fromPoints(const [
      UnitPoint(0.1, 0.1),
      UnitPoint(0.9, 0.1),
      UnitPoint(0.9, 0.9),
      UnitPoint(0.1, 0.9),
    ])!;

    test('t = 0 is the starting quad', () {
      expect(from.lerpTo(to, 0), from);
    });

    test('t = 1 is the target quad', () {
      expect(from.lerpTo(to, 1), to);
    });

    test('t = 0.5 is halfway on every corner', () {
      final mid = from.lerpTo(to, 0.5);

      expect(mid.topLeft.x, closeTo(0.15, 1e-9));
      expect(mid.topLeft.y, closeTo(0.15, 1e-9));
      expect(mid.bottomRight.x, closeTo(0.85, 1e-9));
      expect(mid.bottomRight.y, closeTo(0.85, 1e-9));
    });
  });

  group('DocumentQuad equality', () {
    test('two identical quads are equal and share a hash code', () {
      final a = DocumentQuad.fromPoints(_square)!;
      final b = DocumentQuad.fromPoints(_square)!;

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a moved corner breaks equality', () {
      final a = DocumentQuad.fromPoints(_square)!;
      final b = DocumentQuad.fromPoints(const [
        UnitPoint(0.2, 0.2),
        UnitPoint(0.81, 0.2),
        UnitPoint(0.8, 0.8),
        UnitPoint(0.2, 0.8),
      ])!;

      expect(a, isNot(b));
    });
  });
}
