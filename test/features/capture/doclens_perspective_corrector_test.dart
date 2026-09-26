import 'dart:ui';

// See the matching comment in doclens_perspective_corrector.dart — the
// barrel export doesn't compile against this Flutter SDK.
import 'package:doclens/src/models.dart';
import 'package:doclens/src/ocr.dart';
import 'package:doclens/src/platform_interface.dart';
import 'package:doclens/src/quad.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/data/services/doclens_perspective_corrector.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';

void main() {
  group('DoclensPerspectiveCorrector', () {
    const source = CapturedPhoto('/tmp/source.jpg');
    const quad = Quad(
      topLeft: Offset(0.1, 0.1),
      topRight: Offset(0.9, 0.1),
      bottomRight: Offset(0.9, 0.9),
      bottomLeft: Offset(0.1, 0.9),
    );
    const imageSize = Size(1000, 2000);

    test('a detected quad is warped and the cropped path returned', () async {
      final platform = _FakeDoclensPlatform(
        detectResult: const ImageDetection(quad: quad, imageSize: imageSize),
        warpedPath: '/tmp/warped.jpg',
      );
      final corrector = DoclensPerspectiveCorrector(platform: platform);

      final result = await corrector.correct(source);

      expect(
        result,
        const Ok<CapturedPhoto, AppFailure>(CapturedPhoto('/tmp/warped.jpg')),
      );
      expect(platform.capturedRawPath, source.path);
      expect(platform.capturedQuad, quad.scaleToSize(imageSize));
    });

    test('the warp is pinned at the maximum JPEG quality (F17-T07)', () async {
      final platform = _FakeDoclensPlatform(
        detectResult: const ImageDetection(quad: quad, imageSize: imageSize),
        warpedPath: '/tmp/warped.jpg',
      );
      final corrector = DoclensPerspectiveCorrector(platform: platform);

      await corrector.correct(source);

      // The warp is the only re-encode on the OCR path, so it must not be the
      // place capture resolution is quietly traded away. Pinned rather than
      // defaulted: a `doclens` version bump could change the default.
      expect(platform.capturedJpegQuality, 100);
    });

    test('the warp asks for no image enhancement', () async {
      final platform = _FakeDoclensPlatform(
        detectResult: const ImageDetection(quad: quad, imageSize: imageSize),
        warpedPath: '/tmp/warped.jpg',
      );
      final corrector = DoclensPerspectiveCorrector(platform: platform);

      await corrector.correct(source);

      // F17 locked decision #1: the bytes the OCR path produces are geometry
      // corrected only. Binarisation and "magic colour" destroy the stroke
      // gradient Azure's handwriting model reads.
      expect(platform.capturedEnhancement, ImageEnhancement.none);
    });

    test('no detected quad returns the original photo untouched', () async {
      final platform = _FakeDoclensPlatform(
        detectResult: const ImageDetection(quad: null, imageSize: imageSize),
      );
      final corrector = DoclensPerspectiveCorrector(platform: platform);

      final result = await corrector.correct(source);

      expect(result, const Ok<CapturedPhoto, AppFailure>(source));
      expect(platform.capturedQuad, isNull);
    });

    test('an unreadable image fails with a typed failure', () async {
      final platform = _FakeDoclensPlatform();
      final corrector = DoclensPerspectiveCorrector(platform: platform);

      final result = await corrector.correct(source);

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });

    test('a detection error fails with a typed failure', () async {
      final platform = _FakeDoclensPlatform(
        detectError: const ScannerCaptureException('boom'),
      );
      final corrector = DoclensPerspectiveCorrector(platform: platform);

      final result = await corrector.correct(source);

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });

    test('a warp error fails with a typed failure', () async {
      final platform = _FakeDoclensPlatform(
        detectResult: const ImageDetection(quad: quad, imageSize: imageSize),
        warpError: const ScannerCaptureException('boom'),
      );
      final corrector = DoclensPerspectiveCorrector(platform: platform);

      final result = await corrector.correct(source);

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });
  });
}

/// Fake [DoclensPlatform] exercising only the two pure file operations
/// [DoclensPerspectiveCorrector] calls — every other member is unreachable
/// from that code path and throws if hit.
final class _FakeDoclensPlatform extends DoclensPlatform {
  _FakeDoclensPlatform({
    this.detectResult,
    this.detectError,
    this.warpedPath,
    this.warpError,
  });

  final ImageDetection? detectResult;
  final Object? detectError;
  final String? warpedPath;
  final Object? warpError;

  String? capturedRawPath;
  Quad? capturedQuad;
  int? capturedJpegQuality;
  ImageEnhancement? capturedEnhancement;

  @override
  Future<ImageDetection?> detectInImage({required String imagePath}) async {
    if (detectError != null) throw detectError!;
    return detectResult;
  }

  @override
  Future<String> warpImage({
    required String rawImagePath,
    required Quad quad,
    int jpegQuality = 100,
    ImageEnhancement enhancement = ImageEnhancement.none,
    AutoOrientation autoOrientation = AutoOrientation.none,
  }) async {
    if (warpError != null) throw warpError!;
    capturedRawPath = rawImagePath;
    capturedQuad = quad;
    capturedJpegQuality = jpegQuality;
    capturedEnhancement = enhancement;
    return warpedPath!;
  }

  @override
  Future<int> initialize(ScannerConfig config) => throw UnimplementedError();

  @override
  Future<void> dispose() => throw UnimplementedError();

  @override
  Future<ScanResult> capture() => throw UnimplementedError();

  @override
  Future<String> rotateImage({
    required String imagePath,
    required int quarterTurns,
  }) => throw UnimplementedError();

  @override
  Future<void> setFlashMode(FlashMode mode) => throw UnimplementedError();

  @override
  Future<void> focusAt(Offset point) => throw UnimplementedError();

  @override
  Future<void> switchCamera() => throw UnimplementedError();

  @override
  Future<void> pause() => throw UnimplementedError();

  @override
  Future<void> resume() => throw UnimplementedError();

  @override
  Stream<DetectionEvent> detectionEvents() => throw UnimplementedError();

  @override
  Future<OcrResult> recognizeText({required String imagePath}) =>
      throw UnimplementedError();

  @override
  Future<List<String>?> scanWithNativeUI({
    int pageLimit = 100,
    bool allowGalleryImport = false,
    int jpegQuality = 100,
  }) => throw UnimplementedError();
}
