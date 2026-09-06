import '../../domain/entities/document_quad.dart';

/// A document the live detector found, together with everything the screen
/// needs to draw it in the right place.
///
/// The [quad] is still in **sensor space** — the cubit has no way to see
/// layout, so `FramePreviewMapper` does the rotation/mirroring/fit in the
/// screen, where the preview's real rect is measurable. The three fields
/// beside the quad are what that mapping needs, carried on the frame the
/// detection came from rather than re-read from the camera later, so a
/// detection can never be drawn against a different lens's geometry.
final class DetectedDocument {
  const DetectedDocument({
    required this.quad,
    required this.sensorOrientation,
    required this.isMirrored,
    required this.frameAspect,
  });

  final DocumentQuad quad;

  /// The sensor's rotation relative to the device, in degrees.
  final int sensorOrientation;

  /// Whether the feed is mirrored (a front lens).
  final bool isMirrored;

  /// The frame's width ÷ height, before that rotation is applied.
  final double frameAspect;

  @override
  bool operator ==(Object other) =>
      other is DetectedDocument &&
      other.quad == quad &&
      other.sensorOrientation == sensorOrientation &&
      other.isMirrored == isMirrored &&
      other.frameAspect == frameAspect;

  @override
  int get hashCode =>
      Object.hash(quad, sensorOrientation, isMirrored, frameAspect);

  @override
  String toString() =>
      'DetectedDocument($quad, sensor: $sensorOrientation°, '
      'mirrored: $isMirrored, aspect: $frameAspect)';
}
