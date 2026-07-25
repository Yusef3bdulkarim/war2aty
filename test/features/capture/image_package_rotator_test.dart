import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/data/services/image_package_rotator.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';

void main() {
  group('ImagePackageRotator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rotator_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    ImagePackageRotator rotator() =>
        ImagePackageRotator(temporaryDirectory: () async => tempDir);

    /// Writes a [width]×[height] JPEG into the temp dir and returns its photo.
    Future<CapturedPhoto> writeImage(int width, int height) async {
      final image = img.Image(width: width, height: height);
      final path = '${tempDir.path}/source.jpg';
      await File(path).writeAsBytes(img.encodeJpg(image));
      return CapturedPhoto(path);
    }

    test('a quarter turn swaps the image dimensions', () async {
      final source = await writeImage(4, 8);

      final result = await rotator().rotate(source, 1);

      final photo = (result as Ok<CapturedPhoto, AppFailure>).value;
      expect(photo.path, isNot(source.path));
      final rotated = img.decodeImage(await File(photo.path).readAsBytes())!;
      expect(rotated.width, 8);
      expect(rotated.height, 4);
    });

    test('a half turn keeps the dimensions', () async {
      final source = await writeImage(4, 8);

      final result = await rotator().rotate(source, 2);

      final photo = (result as Ok<CapturedPhoto, AppFailure>).value;
      final rotated = img.decodeImage(await File(photo.path).readAsBytes())!;
      expect(rotated.width, 4);
      expect(rotated.height, 8);
    });

    test('zero turns returns the original file untouched', () async {
      final source = await writeImage(4, 8);

      final result = await rotator().rotate(source, 0);

      expect(result, Ok<CapturedPhoto, AppFailure>(source));
    });

    test('turns are taken modulo 4', () async {
      final source = await writeImage(4, 8);

      // Four quarter-turns is a full turn — back to the original, no new file.
      final result = await rotator().rotate(source, 4);

      expect(result, Ok<CapturedPhoto, AppFailure>(source));
    });

    test('an undecodable file fails with a typed failure', () async {
      final path = '${tempDir.path}/not-an-image.jpg';
      await File(path).writeAsString('this is not an image');

      final result = await rotator().rotate(CapturedPhoto(path), 1);

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });

    test('a missing file fails with a typed failure', () async {
      final result = await rotator().rotate(
        const CapturedPhoto('/does/not/exist.jpg'),
        1,
      );

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });
  });
}
