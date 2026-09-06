import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/data/services/image_package_cropper.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';

void main() {
  group('ImagePackageCropper', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cropper_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    ImagePackageCropper cropper() =>
        ImagePackageCropper(temporaryDirectory: () async => tempDir);

    /// Writes a [width]×[height] JPEG into the temp dir and returns its photo.
    Future<CapturedPhoto> writeImage(int width, int height) async {
      final image = img.Image(width: width, height: height);
      final path = '${tempDir.path}/source.jpg';
      await File(path).writeAsBytes(img.encodeJpg(image));
      return CapturedPhoto(path);
    }

    test('crops to the fractional region, rounded to pixels', () async {
      final source = await writeImage(100, 200);

      final result = await cropper().crop(
        source,
        const UnitRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8),
      );

      final photo = (result as Ok<CapturedPhoto, AppFailure>).value;
      expect(photo.path, isNot(source.path));
      final cropped = img.decodeImage(await File(photo.path).readAsBytes())!;
      expect(cropped.width, 80); // (0.9 - 0.1) * 100
      expect(cropped.height, 120); // (0.8 - 0.2) * 200
    });

    test(
      'the whole image (UnitRect.full) returns the original untouched',
      () async {
        final source = await writeImage(100, 200);

        final result = await cropper().crop(source, UnitRect.full);

        expect(result, Ok<CapturedPhoto, AppFailure>(source));
      },
    );

    test('an out-of-bounds region is clamped to the image edges', () async {
      final source = await writeImage(100, 200);

      final result = await cropper().crop(
        source,
        const UnitRect(left: -0.5, top: -0.5, right: 1.5, bottom: 1.5),
      );

      final photo = (result as Ok<CapturedPhoto, AppFailure>).value;
      final cropped = img.decodeImage(await File(photo.path).readAsBytes())!;
      expect(cropped.width, 100);
      expect(cropped.height, 200);
    });

    test('an undecodable file fails with a typed failure', () async {
      final path = '${tempDir.path}/not-an-image.jpg';
      await File(path).writeAsString('this is not an image');

      final result = await cropper().crop(
        CapturedPhoto(path),
        const UnitRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9),
      );

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });

    test('a missing file fails with a typed failure', () async {
      final result = await cropper().crop(
        const CapturedPhoto('/does/not/exist.jpg'),
        const UnitRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9),
      );

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });
  });
}
