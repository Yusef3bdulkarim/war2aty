import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/data/services/image_package_downscaler.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';

void main() {
  group('ImagePackageDownscaler', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('downscaler_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    ImagePackageDownscaler downscaler() =>
        ImagePackageDownscaler(temporaryDirectory: () async => tempDir);

    Future<CapturedPhoto> writeImage(int width, int height) async {
      final image = img.Image(width: width, height: height);
      final path = '${tempDir.path}/source.jpg';
      await File(path).writeAsBytes(img.encodeJpg(image));
      return CapturedPhoto(path);
    }

    test('a photo already within bounds is returned untouched', () async {
      final source = await writeImage(1200, 800);

      final result = await downscaler().downscale(source);

      expect(result, Ok<CapturedPhoto, AppFailure>(source));
      expect(tempDir.listSync(), hasLength(1));
    });

    test('a photo exactly at the bound is returned untouched', () async {
      final source = await writeImage(2000, 1000);

      final result = await downscaler().downscale(source);

      expect(result, Ok<CapturedPhoto, AppFailure>(source));
      expect(tempDir.listSync(), hasLength(1));
    });

    test('a landscape photo over the bound is shrunk to the width', () async {
      final source = await writeImage(4000, 2000);

      final result = await downscaler().downscale(source);

      final photo = (result as Ok<CapturedPhoto, AppFailure>).value;
      expect(photo.path, isNot(source.path));
      final shrunk = img.decodeImage(await File(photo.path).readAsBytes())!;
      expect(shrunk.width, 2000);
      expect(shrunk.height, 1000);
    });

    test('a portrait photo over the bound is shrunk to the height', () async {
      final source = await writeImage(2000, 4000);

      final result = await downscaler().downscale(source);

      final photo = (result as Ok<CapturedPhoto, AppFailure>).value;
      expect(photo.path, isNot(source.path));
      final shrunk = img.decodeImage(await File(photo.path).readAsBytes())!;
      expect(shrunk.width, 1000);
      expect(shrunk.height, 2000);
    });

    test('an undecodable file fails with a typed failure', () async {
      final path = '${tempDir.path}/not-an-image.jpg';
      await File(path).writeAsString('this is not an image');

      final result = await downscaler().downscale(CapturedPhoto(path));

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });

    test('a missing file fails with a typed failure', () async {
      final result = await downscaler().downscale(
        const CapturedPhoto('/does/not/exist.jpg'),
      );

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });
  });
}
