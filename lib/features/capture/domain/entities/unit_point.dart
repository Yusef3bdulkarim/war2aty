import 'dart:math' as math;

/// A point expressed as fractions (0..1) of an image's width and height,
/// independent of the image's actual pixel size.
///
/// Pure Dart — no `dart:ui`/`Offset`, so the domain layer stays free of Flutter
/// imports (CLAUDE.md §B.1), for the same reason
/// [UnitRect](unit_rect.dart) avoids `Rect`. The presentation layer scales
/// these fractions into real widget geometry; this layer only carries and
/// transforms them.
final class UnitPoint {
  const UnitPoint(this.x, this.y);

  final double x;
  final double y;

  /// Straight-line distance to [other], in the same fractional units.
  double distanceTo(UnitPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// This point moved a fraction [t] of the way toward [other]. `t == 0` is
  /// this point, `t == 1` is [other]; values outside that range extrapolate.
  UnitPoint lerpTo(UnitPoint other, double t) =>
      UnitPoint(x + (other.x - x) * t, y + (other.y - y) * t);

  @override
  bool operator ==(Object other) =>
      other is UnitPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'UnitPoint($x, $y)';
}
