import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/services/image_rotator.dart';

/// [ImageRotator] backed by the pure-Dart `image` package.
///
/// The decode/rotate/encode is CPU-heavy on a full-resolution photo, so it runs
/// in a background isolate to keep the UI thread free. File I/O stays on the
/// main isolate; only the pixel work is offloaded. The temp directory is
/// injectable so the rotation can be unit-tested without a device.
final class ImagePackageRotator implements ImageRotator {
  ImagePackageRotator({Future<Directory> Function()? temporaryDirectory})
    : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _temporaryDirectory;

  @override
  Future<Result<CapturedPhoto, AppFailure>> rotate(
    CapturedPhoto photo,
    int quarterTurns,
  ) async {
    final turns = quarterTurns % 4;
    // Nothing to do — hand the original straight back rather than re-encoding
    // an unchanged image (which would also strip quality for no reason).
    if (turns == 0) return Ok(photo);

    try {
      final bytes = await File(photo.path).readAsBytes();
      final rotated = await Isolate.run(() => _rotateBytes(bytes, turns));
      if (rotated == null) return const Err(ImageProcessingFailure());

      final dir = await _temporaryDirectory();
      final outPath = p.join(
        dir.path,
        'rotated_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(outPath).writeAsBytes(rotated, flush: true);
      return Ok(CapturedPhoto(outPath));
    } on Object {
      return const Err(ImageProcessingFailure());
    }
  }

  /// Runs inside the isolate: decode, rotate clockwise, re-encode as JPEG.
  /// Returns `null` when the bytes are not a decodable image.
  static Uint8List? _rotateBytes(Uint8List bytes, int turns) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final rotated = img.copyRotate(decoded, angle: turns * 90);
    return img.encodeJpg(rotated, quality: 92);
  }
}
