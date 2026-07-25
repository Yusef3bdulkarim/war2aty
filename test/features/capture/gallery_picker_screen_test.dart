import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/pick_image_from_gallery.dart';
import 'package:war2aty/features/capture/presentation/cubit/gallery_picker_cubit.dart';
import 'package:war2aty/features/capture/presentation/screens/gallery_picker_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _strings = ArStrings();

Future<_Result> _pumpPicker(
  WidgetTester tester,
  FakeImagePickerService picker, {
  TextScaler? textScaler,
}) async {
  final result = _Result();
  final cubit = GalleryPickerCubit(
    pickImageFromGallery: PickImageFromGallery(picker),
  );
  addTearDown(cubit.close);

  await pumpApp(
    tester,
    BlocProvider<GalleryPickerCubit>.value(
      value: cubit,
      child: GalleryPickerScreen(
        onPicked: (photo) => result.picked = photo,
        onCancelled: () => result.cancelled = true,
      ),
    ),
    // The wait state shows a spinner that never settles.
    settle: false,
    textScaler: textScaler,
  );
  // Let pick()'s result resolve.
  await tester.pump();
  await tester.pump();
  return result;
}

void main() {
  group('GalleryPickerScreen', () {
    testWidgets('a chosen photo is handed back', (tester) async {
      const picked = CapturedPhoto('/tmp/bill.jpg');
      final result = await _pumpPicker(
        tester,
        FakeImagePickerService(photo: picked),
      );

      expect(result.picked, picked);
    });

    testWidgets('cancelling leaves the flow', (tester) async {
      final result = await _pumpPicker(
        tester,
        FakeImagePickerService(cancelled: true),
      );

      expect(result.cancelled, isTrue);
    });

    testWidgets('a failed picker shows the error with a retry', (tester) async {
      await _pumpPicker(tester, FakeImagePickerService(fails: true));

      expect(find.text(_strings.galleryErrorTitle), findsOneWidget);
      expect(find.text(_strings.actionRetry), findsOneWidget);
    });

    testWidgets('retry re-opens the picker and hands back the photo', (
      tester,
    ) async {
      const picked = CapturedPhoto('/tmp/bill.jpg');
      final picker = FakeImagePickerService(photo: picked, fails: true);
      final result = await _pumpPicker(tester, picker);

      picker.fails = false;
      await tester.tap(find.text(_strings.actionRetry));
      await tester.pump();
      await tester.pump();

      expect(result.picked, picked);
    });

    testWidgets('leaving the error returns to Home', (tester) async {
      final result = await _pumpPicker(
        tester,
        FakeImagePickerService(fails: true),
      );

      await tester.tap(find.text(_strings.actionBack));
      await tester.pump();

      expect(result.cancelled, isTrue);
    });

    testWidgets('the error lays out right-to-left', (tester) async {
      await _pumpPicker(tester, FakeImagePickerService(fails: true));

      expect(
        Directionality.of(
          tester.element(find.text(_strings.galleryErrorTitle)),
        ),
        TextDirection.rtl,
      );
    });

    testWidgets('the error survives Large Text without overflowing', (
      tester,
    ) async {
      await _pumpPicker(
        tester,
        FakeImagePickerService(fails: true),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

/// What the screen handed back to its host.
final class _Result {
  CapturedPhoto? picked;
  bool cancelled = false;
}
