/// A crop region expressed as fractions (0..1) of an image's width and
/// height, independent of the image's actual pixel size.
///
/// Pure Dart — no `dart:ui`/Flutter `Rect`, so the domain layer stays free of
/// Flutter imports (CLAUDE.md §B.1). The presentation layer computes this from
/// real widget geometry (the camera's guide box, or the preview screen's drag
/// handles); this layer only carries and manipulates the fractions.
final class UnitRect {
  const UnitRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  /// The whole image, uncropped.
  static const UnitRect full = UnitRect(left: 0, top: 0, right: 1, bottom: 1);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  /// Whether this covers the whole image — nothing to crop.
  bool get isFull => left <= 0 && top <= 0 && right >= 1 && bottom >= 1;

  /// This region expanded by [fraction] of its own width/height on every
  /// side, then clamped back into the image's bounds (F15 locked decision #2
  /// — the guide-box crop's safety margin, so imperfect alignment doesn't
  /// clip the document before `doclens` gets a chance to find its real
  /// edges).
  UnitRect expanded(double fraction) {
    final dx = width * fraction;
    final dy = height * fraction;
    return UnitRect(
      left: left - dx,
      top: top - dy,
      right: right + dx,
      bottom: bottom + dy,
    ).clamped();
  }

  /// Clamped into the image's [0, 1] bounds. Each edge is clamped
  /// independently; since clamping is monotonic, a region that started valid
  /// (`left <= right`, `top <= bottom`) cannot come out inverted.
  UnitRect clamped() => UnitRect(
    left: _clamp01(left),
    top: _clamp01(top),
    right: _clamp01(right),
    bottom: _clamp01(bottom),
  );

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  @override
  bool operator ==(Object other) =>
      other is UnitRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() =>
      'UnitRect(left: $left, top: $top, right: $right, bottom: $bottom)';
}
