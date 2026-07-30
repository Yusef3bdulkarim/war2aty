import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/image_quality_result.dart';
import '../../domain/services/image_quality_service.dart';

/// [ImageQualityService] backed by the pure-Dart `image` package.
///
/// Decoding + pixel analysis runs in a background isolate via [Isolate.run]
/// so the UI thread stays jank-free even on budget hardware. The image is
/// downscaled to [_maxAnalysisDim] before blur/brightness analysis — original
/// dimensions are read first for the resolution metric.
final class DartImageQualityService implements ImageQualityService {
  @override
  Future<Result<ImageQualityResult, AppFailure>> assess(
    CapturedPhoto photo,
  ) async {
    try {
      final bytes = await File(photo.path).readAsBytes();
      final result = await Isolate.run(() => _assess(bytes));
      if (result == null) return const Err(ImageProcessingFailure());
      return Ok(result);
    } on Object {
      return const Err(ImageProcessingFailure());
    }
  }

  // ---------------------------------------------------------------------------
  // Thresholds — educated guesses, tuned later against real Egyptian documents.
  // ---------------------------------------------------------------------------

  static const _maxAnalysisDim = 800;

  // Resolution (total pixel count).
  static const _resGood = 2000000; // 2 MP
  static const _resAcceptable = 1000000; // 1 MP

  // Blur (Laplacian variance — higher = sharper).
  static const _blurGood = 100.0;
  static const _blurAcceptable = 50.0;

  // Brightness (mean luminance 0–255).
  static const _brightLow = 40.0;
  static const _brightAcceptableLow = 60.0;
  static const _brightAcceptableHigh = 200.0;
  static const _brightHigh = 230.0;

  // ---------------------------------------------------------------------------
  // Isolate entry-point — everything below is pure computation, no I/O.
  // ---------------------------------------------------------------------------

  static ImageQualityResult? _assess(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final resolution = _scoreResolution(decoded.width, decoded.height);

    final img.Image sample;
    if (decoded.width > _maxAnalysisDim || decoded.height > _maxAnalysisDim) {
      sample = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: _maxAnalysisDim)
          : img.copyResize(decoded, height: _maxAnalysisDim);
    } else {
      sample = decoded;
    }

    final gray = _grayscale(sample);
    final blur = _scoreBlur(gray, sample.width, sample.height);
    final brightness = _scoreBrightness(gray);

    return ImageQualityResult(
      overall: _worst([blur, resolution, brightness]),
      blur: blur,
      resolution: resolution,
      brightness: brightness,
    );
  }

  /// Converts every pixel to a luminance value (BT.601 weights).
  static Float64List _grayscale(img.Image image) {
    final w = image.width;
    final h = image.height;
    final out = Float64List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        out[y * w + x] =
            0.299 * p.r.toDouble() +
            0.587 * p.g.toDouble() +
            0.114 * p.b.toDouble();
      }
    }
    return out;
  }

  static ImageQuality _scoreResolution(int width, int height) {
    final pixels = width * height;
    if (pixels >= _resGood) return ImageQuality.good;
    if (pixels >= _resAcceptable) return ImageQuality.acceptable;
    return ImageQuality.poor;
  }

  /// Laplacian-variance sharpness: convolve interior pixels with the kernel
  /// `[0 1 0; 1 -4 1; 0 1 0]` and return the variance.
  static ImageQuality _scoreBlur(Float64List gray, int w, int h) {
    if (w < 3 || h < 3) return ImageQuality.poor;

    var sum = 0.0;
    var sumSq = 0.0;
    var count = 0;

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final idx = y * w + x;
        final lap =
            gray[idx - w] +
            gray[idx + w] +
            gray[idx - 1] +
            gray[idx + 1] -
            4 * gray[idx];
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    if (variance >= _blurGood) return ImageQuality.good;
    if (variance >= _blurAcceptable) return ImageQuality.acceptable;
    return ImageQuality.poor;
  }

  /// Mean luminance of the pre-computed grayscale array.
  static ImageQuality _scoreBrightness(Float64List gray) {
    var sum = 0.0;
    for (var i = 0; i < gray.length; i++) {
      sum += gray[i];
    }
    final mean = sum / gray.length;

    if (mean < _brightLow || mean > _brightHigh) return ImageQuality.poor;
    if (mean < _brightAcceptableLow || mean > _brightAcceptableHigh) {
      return ImageQuality.acceptable;
    }
    return ImageQuality.good;
  }

  static ImageQuality _worst(List<ImageQuality> scores) {
    if (scores.contains(ImageQuality.poor)) return ImageQuality.poor;
    if (scores.contains(ImageQuality.acceptable)) {
      return ImageQuality.acceptable;
    }
    return ImageQuality.good;
  }
}
