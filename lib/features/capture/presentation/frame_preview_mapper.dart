import '../domain/entities/document_quad.dart';
import '../domain/entities/unit_point.dart';

/// How the live preview fits the camera feed into the rect it was given.
enum PreviewFit {
  /// The whole feed is visible, letterboxed if the aspects differ.
  contain,

  /// The rect is filled and the feed's overflowing edges are cut off.
  cover,
}

/// Moves a detected quad out of sensor space and into the preview widget's
/// own rect (F16-T05).
///
/// The detector works on the raw frame, which is rotated (and possibly
/// mirrored) relative to what the user is looking at. Getting this wrong is
/// silent — the overlay simply sits on the wrong part of the screen — so the
/// whole transform is pure functions over plain numbers, and every orientation
/// is unit-tested.
///
/// The result is in the same coordinate space the camera screen already uses
/// for the guide box: fractions of the live preview's rendered rect.
final class FramePreviewMapper {
  const FramePreviewMapper._();

  /// [sensorQuad] as seen on the preview.
  ///
  /// The order is fixed and matters: **rotate, then mirror, then fit.** Mirror
  /// before rotate and a front-camera overlay lands on the wrong diagonal;
  /// fit before rotate and the aspect correction is applied to the wrong axis.
  ///
  /// [frameAspect] is the sensor frame's width ÷ height *before* rotation;
  /// [previewAspect] is the rendered preview rect's. An unexpected
  /// [sensorOrientation] is treated as 0 rather than throwing — this is a
  /// guidance layer, and degrading is always better than failing (F16 locked
  /// decision #4).
  static DocumentQuad mapToPreview(
    DocumentQuad sensorQuad, {
    required int sensorOrientation,
    required bool isMirrored,
    required double frameAspect,
    required double previewAspect,
    PreviewFit fit = PreviewFit.contain,
  }) {
    final turns = _turnsFor(sensorOrientation);
    final rotated = _rotate(sensorQuad, turns);
    final mirrored = isMirrored ? _mirror(rotated) : rotated;

    // A quarter turn swaps the frame's own width and height.
    final rotatedAspect = turns.isOdd ? 1 / frameAspect : frameAspect;
    return _fit(mirrored, rotatedAspect, previewAspect, fit);
  }

  /// Quarter turns clockwise, or 0 for anything that is not a right angle.
  static int _turnsFor(int degrees) {
    final normalised = degrees % 360;
    return switch (normalised) {
      90 => 1,
      180 => 2,
      270 => 3,
      _ => 0,
    };
  }

  static DocumentQuad _rotate(DocumentQuad quad, int turns) {
    if (turns == 0) return quad;

    UnitPoint turn(UnitPoint p) => switch (turns) {
      1 => UnitPoint(1 - p.y, p.x),
      2 => UnitPoint(1 - p.x, 1 - p.y),
      _ => UnitPoint(p.y, 1 - p.x),
    };

    // Rotating moves which physical corner is top-left, so the corners are
    // re-sorted rather than carried across under their old names. Always four
    // points in, so `fromPoints` cannot decline.
    return DocumentQuad.fromPoints([for (final p in quad.corners) turn(p)])!;
  }

  static DocumentQuad _mirror(DocumentQuad quad) => DocumentQuad.fromPoints([
    for (final p in quad.corners) UnitPoint(1 - p.x, p.y),
  ])!;

  /// Rescales normalised frame coordinates into normalised *preview*
  /// coordinates, accounting for the bars (contain) or the crop (cover) that
  /// an aspect mismatch produces.
  ///
  /// With equal aspects — the usual case, since the camera screen measures the
  /// rendered preview itself — this is the identity.
  static DocumentQuad _fit(
    DocumentQuad quad,
    double frameAspect,
    double previewAspect,
    PreviewFit fit,
  ) {
    if (frameAspect <= 0 || previewAspect <= 0) return quad;
    if ((frameAspect - previewAspect).abs() < 1e-9) return quad;

    final wider = frameAspect > previewAspect;
    // `contain` shrinks the axis that does not bind and centres it; `cover`
    // grows it past the edges. Coordinates outside 0..1 are left as they are —
    // clamping is the caller's decision (`boundingRect` already does it).
    final letterboxed = fit == PreviewFit.contain ? wider : !wider;

    if (letterboxed) {
      // Bars above and below: the frame keeps the full width and occupies
      // less of the height.
      final scale = previewAspect / frameAspect;
      final offset = (1 - scale) / 2;
      return DocumentQuad.fromPoints([
        for (final p in quad.corners) UnitPoint(p.x, p.y * scale + offset),
      ])!;
    }

    // Bars left and right (or a horizontal crop): the height binds.
    final scale = frameAspect / previewAspect;
    final offset = (1 - scale) / 2;
    return DocumentQuad.fromPoints([
      for (final p in quad.corners) UnitPoint(p.x * scale + offset, p.y),
    ])!;
  }
}
