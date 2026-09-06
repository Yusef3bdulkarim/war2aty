import 'dart:typed_data';

/// How the bytes of a [CameraFrame] are laid out.
enum CameraFrameFormat {
  /// One byte of brightness per pixel — Android's yuv420 plane 0, handed over
  /// as-is.
  luma8,

  /// Four bytes per pixel, blue/green/red/alpha — what iOS streams. Converted
  /// to brightness inside the detector's isolate rather than on the UI thread.
  bgra8888,
}

/// One frame off the live camera stream, as the edge detector needs it.
///
/// **Nothing here is ever written to disk** (F16 locked decision #3): frames are
/// read from the stream, handed to the detector, and dropped. No temp file, no
/// JPEG encoding, nothing to clean up — the privacy contract gains no new
/// surface. The bytes are also never logged (privacy §7).
///
/// Pure Dart: `dart:typed_data` only, no plugin types. The `camera` plugin's
/// `CameraImage` is mapped to this at the data-layer boundary and never travels
/// further up.
final class CameraFrame {
  const CameraFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.format,
    this.sensorOrientation = 0,
    this.isMirrored = false,
  });

  /// The raw plane, exactly as the camera delivered it.
  final Uint8List bytes;

  final int width;
  final int height;

  /// Bytes from the start of one row to the start of the next. This is **not**
  /// necessarily `width` (or `width * 4`) — hardware pads rows, and reading as
  /// if it did not is what produces a sheared image.
  final int bytesPerRow;

  final CameraFrameFormat format;

  /// How far the sensor is rotated relative to the device's natural
  /// orientation, in degrees. The detector works in sensor space; this is what
  /// lets the presentation layer rotate its result into preview space
  /// (F16-T05).
  final int sensorOrientation;

  /// Whether the feed is mirrored (a front-facing lens). The app uses the back
  /// camera, so this is normally `false`.
  final bool isMirrored;

  /// Whether [bytes] is long enough for the geometry it claims.
  bool get isConsistent =>
      width > 0 &&
      height > 0 &&
      bytesPerRow >= width * _bytesPerPixel &&
      bytes.length >= bytesPerRow * (height - 1) + width * _bytesPerPixel;

  int get _bytesPerPixel => format == CameraFrameFormat.bgra8888 ? 4 : 1;

  /// Deliberately does not include [bytes] — a frame's contents must never
  /// reach a log line (privacy §7).
  @override
  String toString() =>
      'CameraFrame(${width}x$height, stride: $bytesPerRow, '
      'format: ${format.name}, sensor: $sensorOrientation°, '
      'mirrored: $isMirrored)';
}
