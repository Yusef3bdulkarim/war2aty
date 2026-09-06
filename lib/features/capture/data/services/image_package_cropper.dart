import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/unit_rect.dart';
import '../../domain/services/image_cropper.dart';

/// [ImageCropper] backed by the pure-Dart `image` package.
///
/// Same shape as `ImagePackageRotator`: the decode/crop/encode is CPU-heavy
/// on a full-resolution photo, so it runs in a background isolate to keep the
/// UI thread free. File I/O stays on the main isolate; only the pixel work is
/// offloaded. The temp directory is injectable so cropping can be
/// unit-tested without a device.
final class ImagePackageCropper implements ImageCropper {
  ImagePackageCropper({Future<Directory> Function()? temporaryDirectory})
    : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _temporaryDirectory;

  @override
  Future<Result<CapturedPhoto, AppFailure>> crop(
    CapturedPhoto photo,
    UnitRect region,
  ) async {
    // Nothing to do — hand the original straight back rather than re-encoding
    // an unchanged image (which would also strip quality for no reason).
    if (region.isFull) return Ok(photo);

    try {
      final bytes = await File(photo.path).readAsBytes();
      final cropped = await Isolate.run(() => _cropBytes(bytes, region));
      if (cropped == null) return const Err(ImageProcessingFailure());

      final dir = await _temporaryDirectory();
      final outPath = p.join(
        dir.path,
        'cropped_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(outPath).writeAsBytes(cropped, flush: true);
      return Ok(CapturedPhoto(outPath));
    } on Object {
      return const Err(ImageProcessingFailure());
    }
  }

  /// Runs inside the isolate: decode, crop to [region]'s fractional bounds,
  /// re-encode as JPEG. Returns `null` when the bytes are not a decodable
  /// image.
  static Uint8List? _cropBytes(Uint8List bytes, UnitRect region) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final w = decoded.width;
    final h = decoded.height;
    final left = (region.left * w).round().clamp(0, w - 1);
    final top = (region.top * h).round().clamp(0, h - 1);
    final right = (region.right * w).round().clamp(left + 1, w);
    final bottom = (region.bottom * h).round().clamp(top + 1, h);

    final cropped = img.copyCrop(
      decoded,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
    return img.encodeJpg(cropped, quality: 92);
  }
}
