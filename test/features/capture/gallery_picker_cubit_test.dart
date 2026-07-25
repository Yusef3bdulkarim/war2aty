import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/pick_image_from_gallery.dart';
import 'package:war2aty/features/capture/presentation/cubit/gallery_picker_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/gallery_picker_state.dart';

import '../../support/fakes.dart';

GalleryPickerCubit cubitFor(FakeImagePickerService picker) {
  return GalleryPickerCubit(pickImageFromGallery: PickImageFromGallery(picker));
}

void main() {
  group('GalleryPickerCubit', () {
    test('starts out picking', () {
      final cubit = cubitFor(FakeImagePickerService());
      addTearDown(cubit.close);

      expect(cubit.state, const GalleryPickerPicking());
    });

    test('a chosen photo is selected', () async {
      const picked = CapturedPhoto('/tmp/bill.jpg');
      final cubit = cubitFor(FakeImagePickerService(photo: picked));
      addTearDown(cubit.close);

      await cubit.pick();

      expect(cubit.state, const GalleryPickerSelected(picked));
    });

    test('backing out of the picker is a cancellation, not an error', () async {
      final cubit = cubitFor(FakeImagePickerService(cancelled: true));
      addTearDown(cubit.close);

      await cubit.pick();

      expect(cubit.state, const GalleryPickerCancelled());
    });

    test('a picker that will not open surfaces the error', () async {
      final cubit = cubitFor(FakeImagePickerService(fails: true));
      addTearDown(cubit.close);

      await cubit.pick();

      expect(cubit.state, const GalleryPickerError(GalleryAccessFailure()));
    });

    test('retry re-opens the picker', () async {
      final picker = FakeImagePickerService(fails: true);
      final cubit = cubitFor(picker);
      addTearDown(cubit.close);

      await cubit.pick();
      picker.fails = false;
      await cubit.pick();

      expect(cubit.state, isA<GalleryPickerSelected>());
      expect(picker.pickCount, 2);
    });

    test('does nothing once closed', () async {
      final picker = FakeImagePickerService();
      final cubit = cubitFor(picker);
      await cubit.close();

      await cubit.pick();

      expect(picker.pickCount, 0);
    });
  });
}
