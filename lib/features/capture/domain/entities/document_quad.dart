import 'dart:math' as math;

import 'unit_point.dart';
import 'unit_rect.dart';

/// The four corners of a document as seen in a camera frame, in normalised
/// (0..1) frame coordinates.
///
/// This is *guidance geometry* and nothing else (F16 locked decision #1): it
/// drives what the viewfinder draws, and never what the capture keeps. The
/// T10 device pass settled that — a detection that collapsed to a sliver
/// cropped a real page away — so the capture keeps the whole frame and
/// `doclens` re-detects the real edges on the file afterwards. Nothing
/// downstream has to trust these numbers to be exact.
///
/// [boundingRect] is still used, but only to place the guide's scan line and
/// to reject frame-filling detections in the algorithm.
///
/// Corners are always stored in TL/TR/BR/BL order — [fromPoints] is the only
/// way in from unordered data, so no consumer has to remember a convention.
final class DocumentQuad {
  const DocumentQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// Orders four arbitrary [points] into a quad, or returns `null` when there
  /// are not exactly four.
  ///
  /// The points are sorted by their angle around their own centroid, which
  /// puts them in ring order regardless of how the detector found them, then
  /// the ring is rotated to start at the corner nearest the frame's origin.
  /// A degenerate input (all four points identical) still produces a quad —
  /// [isValid] is what rejects it, so callers have one place to check.
  static DocumentQuad? fromPoints(List<UnitPoint> points) {
    if (points.length != 4) return null;

    var cx = 0.0;
    var cy = 0.0;
    for (final p in points) {
      cx += p.x;
      cy += p.y;
    }
    cx /= 4;
    cy /= 4;

    final ring = [...points]
      ..sort(
        (a, b) => math
            .atan2(a.y - cy, a.x - cx)
            .compareTo(math.atan2(b.y - cy, b.x - cx)),
      );

    // atan2 is measured from the +x axis growing toward +y, and y grows
    // downward in image space, so the ring above runs clockwise starting
    // somewhere on the left. Rotate it to start at the top-left-most corner.
    var start = 0;
    var best = double.infinity;
    for (var i = 0; i < 4; i++) {
      final score = ring[i].x + ring[i].y;
      if (score < best) {
        best = score;
        start = i;
      }
    }

    return DocumentQuad(
      topLeft: ring[start],
      topRight: ring[(start + 1) % 4],
      bottomRight: ring[(start + 2) % 4],
      bottomLeft: ring[(start + 3) % 4],
    );
  }

  final UnitPoint topLeft;
  final UnitPoint topRight;
  final UnitPoint bottomRight;
  final UnitPoint bottomLeft;

  /// The corners in ring order: TL, TR, BR, BL.
  List<UnitPoint> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  /// The area enclosed, as a fraction of the whole frame (shoelace formula).
  /// Always positive — winding direction is not meaningful here.
  double get area {
    final ring = corners;
    var sum = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % 4];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum.abs() / 2;
  }

  /// Whether all four turns go the same way — a quad that folds over itself
  /// (a bow tie) or has three collinear corners is not a document.
  bool get isConvex {
    final ring = corners;
    var sawPositive = false;
    var sawNegative = false;
    for (var i = 0; i < 4; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % 4];
      final c = ring[(i + 2) % 4];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross > _epsilon) sawPositive = true;
      if (cross < -_epsilon) sawNegative = true;
      if (sawPositive && sawNegative) return false;
    }
    // A quad with no turn at all is a line, not a shape.
    return sawPositive || sawNegative;
  }

  /// Whether this is plausibly a document: convex, big enough to be worth
  /// drawing, and with no two corners collapsed onto each other.
  ///
  /// [minArea] is the smallest share of the frame that still counts. It is a
  /// parameter rather than a constant so the detector and the perf guard can
  /// tighten it without this entity being edited.
  bool isValid({double minArea = defaultMinArea}) {
    final ring = corners;
    for (var i = 0; i < 4; i++) {
      for (var j = i + 1; j < 4; j++) {
        if (ring[i].distanceTo(ring[j]) < _minCornerGap) return false;
      }
    }
    return isConvex && area >= minArea;
  }

  /// The axis-aligned box containing all four corners, clamped into the
  /// frame — the bridge to the existing crop path, which speaks [UnitRect].
  UnitRect get boundingRect {
    final ring = corners;
    var left = ring.first.x;
    var right = ring.first.x;
    var top = ring.first.y;
    var bottom = ring.first.y;
    for (final p in ring.skip(1)) {
      if (p.x < left) left = p.x;
      if (p.x > right) right = p.x;
      if (p.y < top) top = p.y;
      if (p.y > bottom) bottom = p.y;
    }
    return UnitRect(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    ).clamped();
  }

  /// This quad moved a fraction [t] of the way toward [other], corner by
  /// corner — how the viewfinder glides between detections instead of
  /// snapping (F16-T06).
  DocumentQuad lerpTo(DocumentQuad other, double t) => DocumentQuad(
    topLeft: topLeft.lerpTo(other.topLeft, t),
    topRight: topRight.lerpTo(other.topRight, t),
    bottomRight: bottomRight.lerpTo(other.bottomRight, t),
    bottomLeft: bottomLeft.lerpTo(other.bottomLeft, t),
  );

  /// The smallest share of the frame a quad must cover to be worth showing.
  static const double defaultMinArea = 0.05;

  /// Corners closer than this are the same corner — the shape has collapsed.
  static const double _minCornerGap = 0.01;

  /// Cross products below this are noise, not a turn.
  static const double _epsilon = 1e-9;

  @override
  bool operator ==(Object other) =>
      other is DocumentQuad &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);

  @override
  String toString() =>
      'DocumentQuad($topLeft, $topRight, $bottomRight, $bottomLeft)';
}
