import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/services/image_downscaler.dart';

const _longestEdge = 2000;
const _jpegQuality = 85;

final class ImagePackageDownscaler implements ImageDownscaler {
  ImagePackageDownscaler({Future<Directory> Function()? temporaryDirectory})
    : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _temporaryDirectory;

  @override
  Future<Result<CapturedPhoto, AppFailure>> downscale(
    CapturedPhoto photo,
  ) async {
    try {
      final bytes = await File(photo.path).readAsBytes();
      final outcome = await Isolate.run(() => _downscaleBytes(bytes));
      if (outcome == null) return const Err(ImageProcessingFailure());
      final encoded = outcome.encoded;
      if (encoded == null) return Ok(photo);

      final dir = await _temporaryDirectory();
      final outPath = p.join(
        dir.path,
        'downscaled_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await File(outPath).writeAsBytes(encoded, flush: true);
      return Ok(CapturedPhoto(outPath));
    } on Object {
      return const Err(ImageProcessingFailure());
    }
  }

  static ({Uint8List? encoded})? _downscaleBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    if (decoded.width <= _longestEdge && decoded.height <= _longestEdge) {
      return (encoded: null);
    }

    final resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: _longestEdge)
        : img.copyResize(decoded, height: _longestEdge);
    return (encoded: img.encodeJpg(resized, quality: _jpegQuality));
  }
}
