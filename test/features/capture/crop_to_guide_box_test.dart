import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_image.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_to_guide_box.dart';

import '../../support/fakes.dart';

const _photo = CapturedPhoto('/tmp/raw.jpg');

void main() {
  group('CropToGuideBox', () {
    test(
      'expands the guide box by the safety margin before cropping',
      () async {
        final cropper = FakeImageCropper();
        final useCase = CropToGuideBox(CropImage(cropper));

        await useCase(
          _photo,
          const UnitRect(left: 0.2, top: 0.3, right: 0.6, bottom: 0.7),
        );

        expect(cropper.lastPhoto, _photo);
        final region = cropper.lastRegion!;
        expect(region.left, closeTo(0.12, 1e-9));
        expect(region.top, closeTo(0.22, 1e-9));
        expect(region.right, closeTo(0.68, 1e-9));
        expect(region.bottom, closeTo(0.78, 1e-9));
      },
    );

    test(
      'a guide box already covering the whole image stays a no-op',
      () async {
        final cropper = FakeImageCropper();
        final useCase = CropToGuideBox(CropImage(cropper));

        final result = await useCase(_photo, UnitRect.full);

        expect(result, const Ok<CapturedPhoto, AppFailure>(_photo));
      },
    );
  });
}
