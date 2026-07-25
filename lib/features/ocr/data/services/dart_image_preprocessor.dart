import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/services/image_preprocessor.dart';

/// Maximum pixel dimension (width or height) before the image is resized.
///
/// ML Kit recommends images no larger than 4096px on any side. Oversized
/// images waste memory and slow recognition without improving accuracy.
const int kMaxOcrDimension = 4096;

/// [ImagePreprocessor] backed by the pure-Dart `image` package.
///
/// Decode + resize runs in a background isolate (same pattern as
/// [ImagePackageRotator] in the capture feature) to keep the UI thread free.
/// When no resize is needed the original path is returned unchanged.
final class DartImagePreprocessor implements ImagePreprocessor {
  const DartImagePreprocessor();

  @override
  Future<Result<String, AppFailure>> preprocess(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();

      final resized = await Isolate.run(
        () => resizeIfNeeded(bytes, kMaxOcrDimension),
      );

      if (resized == null) return Ok(imagePath);

      final outPath = p.join(
        p.dirname(imagePath),
        'ocr_resized_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(outPath).writeAsBytes(resized, flush: true);
      return Ok(outPath);
    } on Object {
      return const Err(ImageProcessingFailure());
    }
  }

  /// Runs inside the isolate. Returns resized JPEG bytes when the image
  /// exceeds [maxDim], or `null` when no resize is needed.
  static Uint8List? resizeIfNeeded(Uint8List bytes, int maxDim) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on Object {
      return null;
    }
    if (decoded == null) return null;

    if (decoded.width <= maxDim && decoded.height <= maxDim) return null;

    final scaled = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? maxDim : null,
      height: decoded.height >= decoded.width ? maxDim : null,
      interpolation: img.Interpolation.linear,
    );

    return img.encodeJpg(scaled, quality: 92);
  }
}
