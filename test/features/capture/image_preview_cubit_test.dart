import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/core/voice/voice_line.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_image.dart';
import 'package:war2aty/features/capture/domain/usecases/rotate_image.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_state.dart';

import '../../support/fakes.dart';

const _source = CapturedPhoto('/tmp/original.jpg');

ImagePreviewCubit cubitFor(
  FakeImageRotator rotator, {
  FakeImageCropper? cropper,
  FakeCaptureFileCleanup? cleanup,
  FakeFixedLinePlayer? linePlayer,
}) {
  final c = cleanup ?? FakeCaptureFileCleanup();
  return ImagePreviewCubit(
    source: _source,
    rotate: RotateImage(rotator),
    cropImage: CropImage(cropper ?? FakeImageCropper()),
    cleanupFiles: CleanupCaptureFiles(c),
    speakFixedLine: SpeakFixedLine(linePlayer ?? FakeFixedLinePlayer()),
  );
}

void main() {
  group('ImagePreviewCubit', () {
    test('starts ready with no rotation', () {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      expect(cubit.state, const ImagePreviewReady(0));
    });

    test('each rotate turns the image another quarter, wrapping at 4', () {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      cubit.rotateClockwise();
      expect(cubit.state, const ImagePreviewReady(1));
      cubit.rotateClockwise();
      cubit.rotateClockwise();
      expect(cubit.state, const ImagePreviewReady(3));
      cubit.rotateClockwise();
      expect(cubit.state, const ImagePreviewReady(0));
    });

    test('confirm with no rotation hands back the original image', () async {
      final rotator = FakeImageRotator();
      final cubit = cubitFor(rotator);
      addTearDown(cubit.close);

      await cubit.confirm();

      expect(cubit.state, const ImagePreviewConfirmed(_source));
      expect(rotator.lastQuarterTurns, 0);
    });

    test(
      'confirm after rotating bakes and hands back the rotated image',
      () async {
        const rotated = CapturedPhoto('/tmp/spun.jpg');
        final rotator = FakeImageRotator(output: rotated);
        final cubit = cubitFor(rotator);
        addTearDown(cubit.close);

        cubit.rotateClockwise();
        await cubit.confirm();

        expect(cubit.state, const ImagePreviewConfirmed(rotated));
        expect(rotator.lastQuarterTurns, 1);
      },
    );

    test(
      'a failed rotation surfaces the error, keeping the rotation',
      () async {
        final cubit = cubitFor(FakeImageRotator(fails: true));
        addTearDown(cubit.close);

        cubit.rotateClockwise();
        await cubit.confirm();

        expect(cubit.state, const ImagePreviewFailed(1));
      },
    );

    test('rotate is ignored while a confirm is in flight', () async {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      final pending = cubit.confirm();
      expect(cubit.state, const ImagePreviewProcessing(0));
      cubit.rotateClockwise();
      expect(cubit.state, const ImagePreviewProcessing(0));

      await pending;
    });

    test('confirming twice keeps the first result', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      final rotator = FakeImageRotator(output: rotated);
      final cubit = cubitFor(rotator);
      addTearDown(cubit.close);

      cubit.rotateClockwise();
      await cubit.confirm();
      await cubit.confirm();

      expect(cubit.state, const ImagePreviewConfirmed(rotated));
      expect(rotator.rotateCount, 1);
    });

    test('does nothing once closed', () async {
      final rotator = FakeImageRotator();
      final cubit = cubitFor(rotator);
      await cubit.close();

      await cubit.confirm();

      expect(rotator.rotateCount, 0);
    });
  });

  group('ImagePreviewCubit manual crop (F15)', () {
    const cropRect = UnitRect(left: 0.1, top: 0.15, right: 0.9, bottom: 0.85);

    test('updateCrop stores the rect in the state', () {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      cubit.updateCrop(cropRect);

      expect(cubit.state, const ImagePreviewReady(0, cropRect: cropRect));
    });

    test(
      'rotateClockwise resets cropRect to full (F15 locked decision #7)',
      () {
        final cubit = cubitFor(FakeImageRotator());
        addTearDown(cubit.close);

        cubit.updateCrop(cropRect);
        cubit.rotateClockwise();

        expect(cubit.state, const ImagePreviewReady(1));
        expect((cubit.state as ImagePreviewReady).cropRect, UnitRect.full);
      },
    );

    test('confirm crops after rotating — the confirmed photo is the '
        'cropped one', () async {
      const cropped = CapturedPhoto('/tmp/cropped.jpg');
      final fakeCropper = FakeImageCropper(output: cropped);
      final cubit = cubitFor(FakeImageRotator(), cropper: fakeCropper);
      addTearDown(cubit.close);

      cubit.updateCrop(cropRect);
      await cubit.confirm();

      expect(fakeCropper.cropCount, 1);
      expect(fakeCropper.lastRegion, cropRect);
      // The crop is the last step, so its output is what gets handed on.
      expect(cubit.state, const ImagePreviewConfirmed(cropped));
    });

    test('confirm with full cropRect skips the crop entirely', () async {
      final fakeCropper = FakeImageCropper();
      final cubit = cubitFor(FakeImageRotator(), cropper: fakeCropper);
      addTearDown(cubit.close);

      // No updateCrop — rect stays at UnitRect.full.
      await cubit.confirm();

      // The cropper's no-op path runs (region.isFull returns input unchanged)
      // but no new file is produced.
      expect(cubit.state, const ImagePreviewConfirmed(_source));
    });

    test('a failed crop surfaces the error, keeping the rect', () async {
      final cubit = cubitFor(
        FakeImageRotator(),
        cropper: FakeImageCropper(fails: true),
      );
      addTearDown(cubit.close);

      cubit.updateCrop(cropRect);
      await cubit.confirm();

      expect(cubit.state, const ImagePreviewFailed(0, cropRect: cropRect));
    });

    // ── The crop rect survives leaving ImagePreviewReady (F15-T13) ──
    //
    // It used to live only on that state, so the screen — which paints the
    // overlay from whatever state is current — showed the selection spring
    // back open the moment confirm() started, and a retry after a failure
    // silently exported the whole image.

    test('confirm carries the crop rect into the processing state', () async {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      cubit.updateCrop(cropRect);
      final states = <ImagePreviewState>[];
      final sub = cubit.stream.listen(states.add);
      addTearDown(sub.cancel);

      await cubit.confirm();

      final processing = states.whereType<ImagePreviewProcessing>().single;
      expect(
        processing.cropRect,
        cropRect,
        reason: 'the overlay must not snap open behind the processing veil',
      );
    });

    test('retrying after a failure still crops to the chosen rect', () async {
      // Fails the first crop, succeeds the second — the user taps «استخدم
      // الصورة» again without touching the handles.
      final cropper = FakeImageCropper(fails: true);
      final cubit = cubitFor(FakeImageRotator(), cropper: cropper);
      addTearDown(cubit.close);

      cubit.updateCrop(cropRect);
      await cubit.confirm();
      expect(cubit.state, isA<ImagePreviewFailed>());

      cropper.fails = false;
      await cubit.confirm();

      expect(
        cropper.lastRegion,
        cropRect,
        reason: 'the retry must not fall back to the full image',
      );
    });

    test('the crop can still be adjusted after a failure', () async {
      const second = UnitRect(left: 0.2, top: 0.2, right: 0.7, bottom: 0.7);
      final cubit = cubitFor(
        FakeImageRotator(),
        cropper: FakeImageCropper(fails: true),
      );
      addTearDown(cubit.close);

      cubit.updateCrop(cropRect);
      await cubit.confirm();
      expect(cubit.state, isA<ImagePreviewFailed>());

      // The handles are live again in the failed state, so a drag must land.
      cubit.updateCrop(second);

      expect(cubit.state, const ImagePreviewReady(0, cropRect: second));
    });

    test(
      'the confirmed state keeps the framing the preview is showing',
      () async {
        // The screen never swaps to the exported file — it keeps rendering
        // the source with the rotation and crop applied. Losing either here
        // flips the preview back to the raw photo for the frame between
        // confirming and the hand-off to the explain pipeline.
        final cubit = cubitFor(FakeImageRotator());
        addTearDown(cubit.close);

        cubit.rotateClockwise();
        cubit.updateCrop(cropRect);
        await cubit.confirm();

        final confirmed = cubit.state as ImagePreviewConfirmed;
        expect(confirmed.quarterTurns, 1);
        expect(confirmed.cropRect, cropRect);
      },
    );

    test('close after crop deletes source + rotated + cropped files', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      const cropped = CapturedPhoto('/tmp/cropped.jpg');
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(
        FakeImageRotator(output: rotated),
        cropper: FakeImageCropper(output: cropped),
        cleanup: cleanup,
      );

      cubit.rotateClockwise();
      cubit.updateCrop(cropRect);
      await cubit.confirm();
      await cubit.close();

      expect(cleanup.deleteCalls, hasLength(1));
      expect(
        cleanup.deleteCalls.first,
        unorderedEquals([_source.path, rotated.path, cropped.path]),
      );
    });
  });

  group('ImagePreviewCubit.confirm — tempPaths', () {
    test('no rotation or crop: tempPaths has only the source', () async {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      await cubit.confirm();

      final confirmed = cubit.state as ImagePreviewConfirmed;
      expect(confirmed.tempPaths, [_source.path]);
    });

    test('rotation: tempPaths has source and rotated', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      final cubit = cubitFor(FakeImageRotator(output: rotated));
      addTearDown(cubit.close);

      cubit.rotateClockwise();
      await cubit.confirm();

      final confirmed = cubit.state as ImagePreviewConfirmed;
      expect(confirmed.tempPaths, [_source.path, rotated.path]);
    });

    test('crop only: tempPaths has source and cropped', () async {
      const cropped = CapturedPhoto('/tmp/cropped.jpg');
      final cubit = cubitFor(
        FakeImageRotator(),
        cropper: FakeImageCropper(output: cropped),
      );
      addTearDown(cubit.close);

      cubit.updateCrop(
        const UnitRect(left: 0.1, top: 0.15, right: 0.9, bottom: 0.85),
      );
      await cubit.confirm();

      final confirmed = cubit.state as ImagePreviewConfirmed;
      expect(confirmed.tempPaths, [_source.path, cropped.path]);
    });

    test('rotation and crop: tempPaths has all three', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      const cropped = CapturedPhoto('/tmp/cropped.jpg');
      final cubit = cubitFor(
        FakeImageRotator(output: rotated),
        cropper: FakeImageCropper(output: cropped),
      );
      addTearDown(cubit.close);

      cubit.rotateClockwise();
      cubit.updateCrop(
        const UnitRect(left: 0.1, top: 0.15, right: 0.9, bottom: 0.85),
      );
      await cubit.confirm();

      final confirmed = cubit.state as ImagePreviewConfirmed;
      expect(confirmed.tempPaths, [_source.path, rotated.path, cropped.path]);
    });
  });

  group('ImagePreviewCubit.handOffToExplain (F39/F40-T21)', () {
    test(
      'no rotation or crop: cleans up nothing (the pipeline owns the source)',
      () async {
        final cleanup = FakeCaptureFileCleanup();
        final cubit = cubitFor(FakeImageRotator(), cleanup: cleanup);

        await cubit.confirm();
        cubit.handOffToExplain();

        expect(cleanup.deleteCalls, isEmpty);
      },
    );

    test(
      'rotation and crop: cleans up only the source and the intermediate '
      'rotated file, leaving the final cropped file to the pipeline',
      () async {
        const rotated = CapturedPhoto('/tmp/spun.jpg');
        const cropped = CapturedPhoto('/tmp/cropped.jpg');
        final cleanup = FakeCaptureFileCleanup();
        final cubit = cubitFor(
          FakeImageRotator(output: rotated),
          cropper: FakeImageCropper(output: cropped),
          cleanup: cleanup,
        );

        cubit.rotateClockwise();
        cubit.updateCrop(
          const UnitRect(left: 0.1, top: 0.15, right: 0.9, bottom: 0.85),
        );
        await cubit.confirm();
        cubit.handOffToExplain();

        expect(cleanup.deleteCalls, [
          [_source.path, rotated.path],
        ]);
      },
    );

    test('is a no-op before confirm', () async {
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(FakeImageRotator(), cleanup: cleanup);
      addTearDown(cubit.close);

      cubit.handOffToExplain();

      expect(cleanup.deleteCalls, isEmpty);
    });

    test('close after hand-off does not clean up anything again', () async {
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(FakeImageRotator(), cleanup: cleanup);

      await cubit.confirm();
      cubit.handOffToExplain();
      cleanup.deleteCalls.clear();
      await cubit.close();

      expect(cleanup.deleteCalls, isEmpty);
    });

    test('close without a hand-off still cleans up the source', () async {
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(FakeImageRotator(), cleanup: cleanup);

      await cubit.confirm();
      await cubit.close();

      expect(cleanup.deleteCalls, [
        [_source.path],
      ]);
    });

    test('calling it twice cleans up only once', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(
        FakeImageRotator(output: rotated),
        cleanup: cleanup,
      );

      cubit.rotateClockwise();
      await cubit.confirm();
      cubit.handOffToExplain();
      cubit.handOffToExplain();

      expect(cleanup.deleteCalls, hasLength(1));
    });
  });

  group(
    'ImagePreviewCubit orphaned temp-file cleanup on close race (F15-T09)',
    () {
      test('close racing an in-flight rotate cleans up the orphaned rotated '
          'file', () async {
        const rotated = CapturedPhoto('/tmp/spun.jpg');
        final gate = Completer<void>();
        final rotator = FakeImageRotator(output: rotated)..gate = gate;
        final cleanup = FakeCaptureFileCleanup();
        final cubit = cubitFor(rotator, cleanup: cleanup);

        cubit.rotateClockwise();
        final confirming = cubit.confirm();
        // Let confirm() reach the awaiting-rotate point.
        await Future<void>.delayed(Duration.zero);

        await cubit.close();

        // The stale rotate now resolves — its file must never reach a
        // terminal state, and must not be left as an orphaned temp file.
        gate.complete();
        await confirming;

        // close()'s own sweep already deleted the source; the orphaned
        // rotated file is a second, separate cleanup call made once the
        // stale await notices isClosed.
        expect(cleanup.deleteCalls, hasLength(2));
        expect(cleanup.deleteCalls[0], [_source.path]);
        expect(cleanup.deleteCalls[1], [rotated.path]);
      });

      test(
        'close racing an in-flight crop cleans up the orphaned cropped file',
        () async {
          const cropped = CapturedPhoto('/tmp/cropped.jpg');
          final gate = Completer<void>();
          final cropper = FakeImageCropper(output: cropped)..gate = gate;
          final cleanup = FakeCaptureFileCleanup();
          final cubit = cubitFor(
            FakeImageRotator(),
            cropper: cropper,
            cleanup: cleanup,
          );

          cubit.updateCrop(
            const UnitRect(left: 0.1, top: 0.15, right: 0.9, bottom: 0.85),
          );
          final confirming = cubit.confirm();
          // Let confirm() clear the (gate-less) rotate and reach the
          // awaiting-crop point.
          await Future<void>.delayed(Duration.zero);

          await cubit.close();

          gate.complete();
          await confirming;

          expect(cleanup.deleteCalls, hasLength(2));
          expect(cleanup.deleteCalls[0], [_source.path]);
          expect(cleanup.deleteCalls[1], [cropped.path]);
        },
      );
    },
  );

  group('ImagePreviewCubit crop_continue (F39-T18)', () {
    test('speaks crop_continue on open', () async {
      final player = FakeFixedLinePlayer();
      final cubit = cubitFor(FakeImageRotator(), linePlayer: player);
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(player.played, [VoiceLine.cropContinue.assetPath]);
    });

    test('stops the line when the user taps «كمّل»', () async {
      final player = FakeFixedLinePlayer();
      final cubit = cubitFor(FakeImageRotator(), linePlayer: player);
      addTearDown(cubit.close);
      await pumpEventQueue();

      await cubit.confirm();

      expect(player.stopCount, 1);
    });

    test('confirming again does not stop the line a second time', () async {
      final player = FakeFixedLinePlayer();
      final cubit = cubitFor(FakeImageRotator(), linePlayer: player);
      addTearDown(cubit.close);
      await pumpEventQueue();

      await cubit.confirm();
      await cubit.confirm();

      expect(player.stopCount, 1);
    });

    test('stops the line on close', () async {
      final player = FakeFixedLinePlayer();
      final cubit = cubitFor(FakeImageRotator(), linePlayer: player);
      await pumpEventQueue();

      await cubit.close();

      expect(player.stopCount, 1);
    });

    test('close stops even when the line never finished starting', () async {
      final player = FakeFixedLinePlayer();
      final cubit = cubitFor(FakeImageRotator(), linePlayer: player);

      await cubit.close();

      expect(player.stopCount, 1);
    });
  });
}
