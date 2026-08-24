import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';
import 'package:war2aty/features/capture/domain/usecases/capture_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_image.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_to_guide_box.dart';
import 'package:war2aty/features/capture/domain/usecases/dispose_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/initialize_camera.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_capture_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_capture_state.dart';

import '../../support/fakes.dart';

CameraCaptureCubit cubitFor(
  FakeCameraService camera, {
  FakeImageCropper? cropper,
  FakeCaptureFileCleanup? cleanup,
}) {
  return CameraCaptureCubit(
    preview: const FakeCameraPreview(),
    initializeCamera: InitializeCamera(camera),
    capturePhoto: CapturePhoto(camera),
    cropToGuideBox: CropToGuideBox(CropImage(cropper ?? FakeImageCropper())),
    disposeCamera: DisposeCamera(camera),
    cleanupFiles: CleanupCaptureFiles(cleanup ?? FakeCaptureFileCleanup()),
  );
}

void main() {
  group('CameraCaptureCubit', () {
    test('starts out initializing', () {
      final cubit = cubitFor(FakeCameraService());
      addTearDown(cubit.close);

      expect(cubit.state, const CameraInitializing());
    });

    test('opening the camera lands on ready', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state, const CameraReady());
      expect(camera.initializeCount, 1);
    });

    test('a camera that will not open shows the error', () async {
      final cubit = cubitFor(FakeCameraService(initFails: true));
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state, const CameraCaptureError(ImageProcessingFailure()));
    });

    test('the shutter produces a captured photo', () async {
      const shot = CapturedPhoto('/tmp/paper.jpg');
      final cubit = cubitFor(FakeCameraService(photo: shot));
      addTearDown(cubit.close);

      await cubit.start();
      await cubit.capture(guideBox: UnitRect.full);

      expect(cubit.state, const CameraCaptured(shot));
    });

    test('the shutter is ignored unless the preview is live', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);

      // Still initializing — no ready state reached yet.
      await cubit.capture(guideBox: UnitRect.full);

      expect(camera.captureCount, 0);
      expect(cubit.state, const CameraInitializing());
    });

    test('a failed shot surfaces the error', () async {
      final cubit = cubitFor(FakeCameraService(captureFails: true));
      addTearDown(cubit.close);

      await cubit.start();
      await cubit.capture(guideBox: UnitRect.full);

      expect(cubit.state, const CameraCaptureError(ImageProcessingFailure()));
    });

    test('suspend releases the camera and returns to initializing', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);

      await cubit.start();
      await cubit.suspend();

      expect(camera.disposeCount, 1);
      expect(cubit.state, const CameraInitializing());
    });

    test(
      'suspending mid-open is not overwritten when the open finishes',
      () async {
        final gate = Completer<void>();
        final camera = FakeCameraService()..initializeGate = gate;
        final cubit = cubitFor(camera);
        addTearDown(cubit.close);

        // Kick off an open and let it reach the awaiting-camera point.
        final opening = cubit.start();
        await Future<void>.delayed(Duration.zero);

        // App backgrounds while still opening.
        await cubit.suspend();
        expect(cubit.state, const CameraInitializing());

        // The original open now completes — it must not flip back to ready.
        gate.complete();
        await opening;

        expect(cubit.state, const CameraInitializing());
        expect(camera.disposeCount, 1);
      },
    );

    test('closing releases the camera', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);

      await cubit.start();
      await cubit.close();

      expect(camera.disposeCount, 1);
    });

    test('does nothing once closed', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);
      await cubit.close();

      await cubit.start();
      await cubit.capture(guideBox: UnitRect.full);

      // Only the close() teardown touched the camera.
      expect(camera.initializeCount, 0);
      expect(camera.captureCount, 0);
    });
  });

  group('CameraCaptureCubit guide-box crop (F15)', () {
    test('captures then crops to the given guide box', () async {
      const shot = CapturedPhoto('/tmp/paper.jpg');
      const cropped = CapturedPhoto('/tmp/cropped.jpg');
      const guideBox = UnitRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8);
      final cropper = FakeImageCropper(output: cropped);
      final cubit = cubitFor(FakeCameraService(photo: shot), cropper: cropper);
      addTearDown(cubit.close);

      await cubit.start();
      await cubit.capture(guideBox: guideBox);

      expect(cropper.lastPhoto, shot);
      // CropToGuideBox expands the box by its margin before cropping — the
      // margin math itself is covered by crop_to_guide_box_test.dart, so
      // here it's enough to confirm the crop actually ran, on the right
      // photo, and its output reached the terminal state.
      expect(cropper.cropCount, 1);
      expect(cubit.state, const CameraCaptured(cropped));
    });

    test('a full guide box (measurement fallback) skips the crop', () async {
      const shot = CapturedPhoto('/tmp/paper.jpg');
      final cropper = FakeImageCropper();
      final cubit = cubitFor(FakeCameraService(photo: shot), cropper: cropper);
      addTearDown(cubit.close);

      await cubit.start();
      await cubit.capture(guideBox: UnitRect.full);

      expect(cubit.state, const CameraCaptured(shot));
    });

    test('a failed crop surfaces the error, not the raw photo', () async {
      final cubit = cubitFor(
        FakeCameraService(),
        cropper: FakeImageCropper(fails: true),
      );
      addTearDown(cubit.close);

      await cubit.start();
      await cubit.capture(
        guideBox: const UnitRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9),
      );

      expect(cubit.state, const CameraCaptureError(ImageProcessingFailure()));
    });
  });

  group(
    'CameraCaptureCubit raw-photo cleanup after crop (F15, privacy §7)',
    () {
      test(
        'a crop that produces a new file deletes the superseded raw one',
        () async {
          const shot = CapturedPhoto('/tmp/paper.jpg');
          const cropped = CapturedPhoto('/tmp/cropped.jpg');
          final cleanup = FakeCaptureFileCleanup();
          final cubit = cubitFor(
            FakeCameraService(photo: shot),
            cropper: FakeImageCropper(output: cropped),
            cleanup: cleanup,
          );
          addTearDown(cubit.close);

          await cubit.start();
          // A guide box tight enough that even after the 20% safety margin
          // it still doesn't reach the image's full bounds — otherwise the
          // margin expansion alone would make this a no-op crop instead of
          // exercising the "produced a new file" path this test is about.
          await cubit.capture(
            guideBox: const UnitRect(
              left: 0.1,
              top: 0.2,
              right: 0.9,
              bottom: 0.8,
            ),
          );

          expect(cleanup.deleteCalls, [
            [shot.path],
          ]);
        },
      );

      test(
        'a no-op crop (full guide box) leaves the one file untouched',
        () async {
          const shot = CapturedPhoto('/tmp/paper.jpg');
          final cleanup = FakeCaptureFileCleanup();
          final cubit = cubitFor(
            FakeCameraService(photo: shot),
            cleanup: cleanup,
          );
          addTearDown(cubit.close);

          await cubit.start();
          await cubit.capture(guideBox: UnitRect.full);

          expect(cleanup.deleteCalls, isEmpty);
        },
      );

      test(
        'a failed crop also deletes the now-unreachable raw photo',
        () async {
          const shot = CapturedPhoto('/tmp/paper.jpg');
          final cleanup = FakeCaptureFileCleanup();
          final cubit = cubitFor(
            FakeCameraService(photo: shot),
            cropper: FakeImageCropper(fails: true),
            cleanup: cleanup,
          );
          addTearDown(cubit.close);

          await cubit.start();
          await cubit.capture(
            guideBox: const UnitRect(
              left: 0.1,
              top: 0.1,
              right: 0.9,
              bottom: 0.9,
            ),
          );

          expect(cleanup.deleteCalls, [
            [shot.path],
          ]);
        },
      );
    },
  );

  group('CameraCaptureCubit orphaned temp-file cleanup on suspend/close race '
      '(F15-T09)', () {
    test('suspend racing an in-flight shutter cleans up the orphaned raw '
        'photo', () async {
      const shot = CapturedPhoto('/tmp/paper.jpg');
      final gate = Completer<void>();
      final camera = FakeCameraService(photo: shot)..captureGate = gate;
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(camera, cleanup: cleanup);
      addTearDown(cubit.close);

      await cubit.start();
      final capturing = cubit.capture(guideBox: UnitRect.full);
      // Let capture() reach the awaiting-shutter point.
      await Future<void>.delayed(Duration.zero);

      // App backgrounds mid-shutter.
      await cubit.suspend();
      expect(cubit.state, const CameraInitializing());

      // The stale shutter now resolves — its photo must never reach a
      // terminal state, and must not be left as an orphaned temp file.
      gate.complete();
      await capturing;

      expect(cubit.state, const CameraInitializing());
      expect(cleanup.deleteCalls, [
        [shot.path],
      ]);
    });

    test(
      'close racing an in-flight shutter cleans up the orphaned raw photo',
      () async {
        const shot = CapturedPhoto('/tmp/paper.jpg');
        final gate = Completer<void>();
        final camera = FakeCameraService(photo: shot)..captureGate = gate;
        final cleanup = FakeCaptureFileCleanup();
        final cubit = cubitFor(camera, cleanup: cleanup);

        await cubit.start();
        final capturing = cubit.capture(guideBox: UnitRect.full);
        await Future<void>.delayed(Duration.zero);

        await cubit.close();

        gate.complete();
        await capturing;

        expect(cleanup.deleteCalls, [
          [shot.path],
        ]);
      },
    );

    test('suspend racing an in-flight crop cleans up both the raw and '
        'cropped orphans', () async {
      const shot = CapturedPhoto('/tmp/paper.jpg');
      const cropped = CapturedPhoto('/tmp/cropped.jpg');
      final gate = Completer<void>();
      final cropper = FakeImageCropper(output: cropped)..gate = gate;
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(
        FakeCameraService(photo: shot),
        cropper: cropper,
        cleanup: cleanup,
      );
      addTearDown(cubit.close);

      await cubit.start();
      final capturing = cubit.capture(
        guideBox: const UnitRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8),
      );
      // Let capture() clear the shutter and reach the awaiting-crop point.
      await Future<void>.delayed(Duration.zero);

      await cubit.suspend();
      expect(cubit.state, const CameraInitializing());

      gate.complete();
      await capturing;

      expect(cubit.state, const CameraInitializing());
      expect(cleanup.deleteCalls, hasLength(1));
      expect(
        cleanup.deleteCalls.first,
        unorderedEquals([shot.path, cropped.path]),
      );
    });

    test('close racing an in-flight crop cleans up both the raw and cropped '
        'orphans', () async {
      const shot = CapturedPhoto('/tmp/paper.jpg');
      const cropped = CapturedPhoto('/tmp/cropped.jpg');
      final gate = Completer<void>();
      final cropper = FakeImageCropper(output: cropped)..gate = gate;
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(
        FakeCameraService(photo: shot),
        cropper: cropper,
        cleanup: cleanup,
      );

      await cubit.start();
      final capturing = cubit.capture(
        guideBox: const UnitRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8),
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.close();

      gate.complete();
      await capturing;

      expect(cleanup.deleteCalls, hasLength(1));
      expect(
        cleanup.deleteCalls.first,
        unorderedEquals([shot.path, cropped.path]),
      );
    });
  });
}
