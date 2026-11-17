import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/downscale_photo.dart';

import '../../support/fakes.dart';

void main() {
  group('DownscalePhoto', () {
    test('returns the downscaler\'s result for the given photo', () async {
      const source = CapturedPhoto('/tmp/source.jpg');
      const shrunk = CapturedPhoto('/tmp/shrunk.jpg');
      final downscaler = FakeImageDownscaler(output: shrunk);
      final downscale = DownscalePhoto(downscaler);

      final result = await downscale(source);

      expect(result, const Ok<CapturedPhoto, AppFailure>(shrunk));
      expect(downscaler.lastPhoto, source);
      expect(downscaler.downscaleCount, 1);
    });

    test('passes a failure through untouched', () async {
      final downscaler = FakeImageDownscaler(fails: true);
      final downscale = DownscalePhoto(downscaler);

      final result = await downscale(const CapturedPhoto('/tmp/source.jpg'));

      expect(
        result,
        const Err<CapturedPhoto, AppFailure>(ImageProcessingFailure()),
      );
    });
  });
}
