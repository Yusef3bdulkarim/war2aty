/// A crop region expressed as fractions (0..1) of an image's width and
/// height, independent of the image's actual pixel size.
///
/// Pure Dart — no `dart:ui`/Flutter `Rect`, so the domain layer stays free of
/// Flutter imports (CLAUDE.md §B.1). The presentation layer computes this from
/// real widget geometry (the preview screen's drag handles); this layer only
/// carries and manipulates the fractions.
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
