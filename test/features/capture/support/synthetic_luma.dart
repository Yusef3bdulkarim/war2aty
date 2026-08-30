import 'dart:math' as math;
import 'dart:typed_data';

import 'package:war2aty/features/capture/domain/entities/camera_frame.dart';

/// Builds synthetic camera frames for the edge detector's tests.
///
/// The detector is tested against generated buffers rather than real photos
/// (F16-T03's acceptance criteria) so the suite is deterministic and carries no
/// image fixtures: a "page" here is a filled, optionally rotated rectangle of
/// one brightness on a background of another, which is exactly the signal the
/// pipeline is meant to find.
CameraFrame syntheticFrame({
  int width = 640,
  int height = 480,
  int backgroundLuma = 40,
  int pageLuma = 200,

  /// The page's rectangle before rotation, as fractions of the frame.
  double pageLeft = 0.2,
  double pageTop = 0.2,
  double pageRight = 0.8,
  double pageBottom = 0.8,

  /// Rotation about the frame's centre, in degrees.
  double rotationDegrees = 0,

  /// Set to `false` for an empty scene — background only.
  bool withPage = true,

  /// Deterministic pseudo-noise amplitude, in luma steps.
  int noise = 0,

  /// Extra bytes per row beyond the pixels, to exercise stride handling.
  int rowPadding = 0,
  CameraFrameFormat format = CameraFrameFormat.luma8,
  int sensorOrientation = 0,
  bool isMirrored = false,
}) {
  final bytesPerPixel = format == CameraFrameFormat.bgra8888 ? 4 : 1;
  final bytesPerRow = width * bytesPerPixel + rowPadding;
  final bytes = Uint8List(bytesPerRow * height);

  final radians = -rotationDegrees * math.pi / 180;
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  final centreX = width / 2;
  final centreY = height / 2;

  final left = pageLeft * width;
  final top = pageTop * height;
  final right = pageRight * width;
  final bottom = pageBottom * height;

  // A cheap, seeded, repeatable hash — good enough for "not flat" and stable
  // across runs, unlike Random without a seed.
  int noiseAt(int x, int y) {
    if (noise == 0) return 0;
    final h = (x * 73856093) ^ (y * 19349663);
    return (h.abs() % (2 * noise + 1)) - noise;
  }

  for (var y = 0; y < height; y++) {
    final row = y * bytesPerRow;
    for (var x = 0; x < width; x++) {
      var luma = backgroundLuma;
      if (withPage) {
        // Rotate the sample point back into the page's own frame, so the page
        // itself comes out rotated on screen.
        final dx = x - centreX;
        final dy = y - centreY;
        final px = centreX + dx * cos - dy * sin;
        final py = centreY + dx * sin + dy * cos;
        if (px >= left && px <= right && py >= top && py <= bottom) {
          luma = pageLuma;
        }
      }
      luma = (luma + noiseAt(x, y)).clamp(0, 255);

      final offset = row + x * bytesPerPixel;
      if (format == CameraFrameFormat.bgra8888) {
        // Grey, so the BGRA→luma conversion lands back on `luma` exactly.
        bytes[offset] = luma;
        bytes[offset + 1] = luma;
        bytes[offset + 2] = luma;
        bytes[offset + 3] = 255;
      } else {
        bytes[offset] = luma;
      }
    }
  }

  return CameraFrame(
    bytes: bytes,
    width: width,
    height: height,
    bytesPerRow: bytesPerRow,
    format: format,
    sensorOrientation: sensorOrientation,
    isMirrored: isMirrored,
  );
}
