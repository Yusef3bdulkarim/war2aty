import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/data/services/dart_image_quality_service.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/image_quality_result.dart';

void main() {
  group('DartImageQualityService', () {
    late Directory tempDir;
    late DartImageQualityService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('quality_test');
      service = DartImageQualityService();
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    Future<CapturedPhoto> writeImage(img.Image image) async {
      final path =
          '${tempDir.path}/img_${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(img.encodeJpg(image));
      return CapturedPhoto(path);
    }

    // -- Resolution -----------------------------------------------------------

    test('a high-resolution image scores good on resolution', () async {
      final image = img.Image(width: 2000, height: 1500);
      _fillMidGray(image);
      final photo = await writeImage(image);

      final result = await service.assess(photo);
      final quality = (result as Ok<ImageQualityResult, AppFailure>).value;

      expect(quality.resolution, ImageQuality.good);
    });

    test('a medium-resolution image scores acceptable', () async {
      final image = img.Image(width: 1200, height: 900);
      _fillMidGray(image);
      final photo = await writeImage(image);

      final result = await service.assess(photo);
      final quality = (result as Ok<ImageQualityResult, AppFailure>).value;

      expect(quality.resolution, ImageQuality.acceptable);
    });

    test('a low-resolution image scores poor', () async {
      final image = img.Image(width: 400, height: 300);
      _fillMidGray(image);
      final photo = await writeImage(image);

      final result = await service.assess(photo);
      final quality = (result as Ok<ImageQualityResult, AppFailure>).value;

      expect(quality.resolution, ImageQuality.poor);
    });

    // -- Brightness -----------------------------------------------------------

    test('a very dark image scores poor on brightness', () async {
      final image = img.Image(width: 200, height: 200);
      _fillSolid(image, 15);
      final photo = await writeImage(image);

      final result = await service.assess(photo);
      final quality = (result as Ok<ImageQualityResult, AppFailure>).value;

      expect(quality.brightness, ImageQuality.poor);
    });

    test('a very bright image scores poor on brightness', () async {
      final image = img.Image(width: 200, height: 200);
      _fillSolid(image, 245);
      final photo = await writeImage(image);

      final result = await service.assess(photo);
      final quality = (result as Ok<ImageQualityResult, AppFailure>).value;

      expect(quality.brightness, ImageQuality.poor);
    });

    test('a mid-tone image scores good on brightness', () async {
      final image = img.Image(width: 200, height: 200);
      _fillSolid(image, 128);
      final photo = await writeImage(image);

      final result = await service.assess(photo);
      final quality = (result as Ok<ImageQualityResult, AppFailure>).value;

      expect(quality.brightness, ImageQuality.good);
    });

    // -- Blur -----------------------------------------------------------------

    test(
      'an image with sharp edges scores better blur than a uniform one',
      () async {
        final sharp = img.Image(width: 200, height: 200);
        _fillCheckerboard(sharp, 8);
        final sharpPhoto = await writeImage(sharp);

        final uniform = img.Image(width: 200, height: 200);
        _fillSolid(uniform, 128);
        final uniformPhoto = await writeImage(uniform);

        final sharpResult = await service.assess(sharpPhoto);
        final uniformResult = await service.assess(uniformPhoto);

        final sharpBlur =
            (sharpResult as Ok<ImageQualityResult, AppFailure>).value.blur;
        final uniformBlur =
            (uniformResult as Ok<ImageQualityResult, AppFailure>).value.blur;

        expect(sharpBlur.index, lessThan(uniformBlur.index));
      },
    );

    // -- Overall (worst-wins) -------------------------------------------------

    test('overall is poor when any metric is poor', () async {
      // Tiny image → poor resolution, but good brightness.
      final image = img.Image(width: 100, height: 100);
      _fillSolid(image, 128);
      final photo = await writeImage(image);

      final result = await service.assess(photo);
      final quality = (result as Ok<ImageQualityResult, AppFailure>).value;

      expect(quality.resolution, ImageQuality.poor);
      expect(quality.overall, ImageQuality.poor);
    });

    // -- Error handling -------------------------------------------------------

    test('an undecodable file returns a typed failure', () async {
      final path = '${tempDir.path}/garbage.jpg';
      await File(path).writeAsString('not an image');

      final result = await service.assess(CapturedPhoto(path));

      expect(
        result,
        const Err<ImageQualityResult, AppFailure>(ImageProcessingFailure()),
      );
    });

    test('a missing file returns a typed failure', () async {
      final result = await service.assess(
        const CapturedPhoto('/does/not/exist.jpg'),
      );

      expect(
        result,
        const Err<ImageQualityResult, AppFailure>(ImageProcessingFailure()),
      );
    });
  });
}

/// Fills every pixel with the same gray [level] (0–255).
void _fillSolid(img.Image image, int level) {
  final color = img.ColorRgb8(level, level, level);
  for (final pixel in image) {
    pixel.set(color);
  }
}

/// Fills the image with a mid-gray value that JPEG won't shift much.
void _fillMidGray(img.Image image) => _fillSolid(image, 128);

/// Fills the image with a checkerboard pattern of [cellSize]×[cellSize] cells
/// alternating between black and white — produces strong edges for blur testing.
void _fillCheckerboard(img.Image image, int cellSize) {
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final isWhite = ((x ~/ cellSize) + (y ~/ cellSize)) % 2 == 0;
      final level = isWhite ? 255 : 0;
      image.setPixelRgb(x, y, level, level, level);
    }
  }
}
