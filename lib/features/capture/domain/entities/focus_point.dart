/// A point on the live preview to focus on, as fractions (0..1) of its width
/// and height from the top-left corner (F24).
///
/// Pure Dart, like `UnitRect`: the presentation layer measures a tap against
/// the preview it draws, and the camera service maps the fractions onto the
/// lens. Out-of-range input — a tap on the preview's very edge, rounding — is
/// clamped rather than rejected, and a non-number falls back to the centre, so
/// a focus request can never carry a point the camera would refuse.
final class FocusPoint {
  factory FocusPoint(double x, double y) => FocusPoint._(_unit(x), _unit(y));

  const FocusPoint._(this.x, this.y);

  /// The middle of the frame.
  static const FocusPoint center = FocusPoint._(0.5, 0.5);

  /// 0 at the preview's left edge, 1 at its right edge.
  final double x;

  /// 0 at the preview's top edge, 1 at its bottom edge.
  final double y;

  static double _unit(double v) {
    if (v.isNaN) return 0.5;
    return v < 0 ? 0 : (v > 1 ? 1 : v);
  }

  @override
  bool operator ==(Object other) =>
      other is FocusPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'FocusPoint($x, $y)';
}
