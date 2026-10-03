import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/capture/domain/entities/camera_capabilities.dart';
import 'package:war2aty/features/capture/domain/entities/camera_flash_mode.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/focus_point.dart';
import 'package:war2aty/features/capture/domain/usecases/capture_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/dispose_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/focus_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/initialize_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/set_camera_flash.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_capture_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_capture_state.dart';

import '../../support/fakes.dart';

/// What [FakeCameraService] reports by default: a flash, and focus.
const _full = CameraCapabilities(hasFlash: true, canFocus: true);

CameraCaptureCubit cubitFor(
  FakeCameraService camera, {
  FakeCaptureFileCleanup? cleanup,
}) {
  return CameraCaptureCubit(
    preview: const FakeCameraPreview(),
    initializeCamera: InitializeCamera(camera),
    capturePhoto: CapturePhoto(camera),
    setCameraFlash: SetCameraFlash(camera),
    focusCamera: FocusCamera(camera),
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

    test('opening the camera lands on ready, flash off, with what the camera '
        'can do', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state, const CameraReady(capabilities: _full));
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
      await cubit.capture();

      expect(cubit.state, const CameraCaptured(shot));
    });

    test(
      'the shot is handed on whole — no crop, no file deleted (F24)',
      () async {
        const shot = CapturedPhoto('/tmp/paper.jpg');
        final cleanup = FakeCaptureFileCleanup();
        final cubit = cubitFor(
          FakeCameraService(photo: shot),
          cleanup: cleanup,
        );
        addTearDown(cubit.close);

        await cubit.start();
        await cubit.capture();

        // The very file the camera wrote reaches the preview screen, and it is
        // that screen's job to clean it up — nothing here may delete it.
        expect(cubit.state, const CameraCaptured(shot));
        expect(cleanup.deleteCalls, isEmpty);
      },
    );

    test('the shutter is ignored unless the preview is live', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);

      // Still initializing — no ready state reached yet.
      await cubit.capture();

      expect(camera.captureCount, 0);
      expect(cubit.state, const CameraInitializing());
    });

    test('a second tap mid-capture takes no second photo', () async {
      final gate = Completer<void>();
      final camera = FakeCameraService()..captureGate = gate;
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);

      await cubit.start();
      final first = cubit.capture();
      await Future<void>.delayed(Duration.zero);
      await cubit.capture();
      gate.complete();
      await first;

      expect(camera.captureCount, 1);
    });

    test('a failed shot surfaces the error', () async {
      final cubit = cubitFor(FakeCameraService(captureFails: true));
      addTearDown(cubit.close);

      await cubit.start();
      await cubit.capture();

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
      await cubit.capture();

      // Only the close() teardown touched the camera.
      expect(camera.initializeCount, 0);
      expect(camera.captureCount, 0);
    });
  });

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
      final capturing = cubit.capture();
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
        final capturing = cubit.capture();
        await Future<void>.delayed(Duration.zero);

        await cubit.close();

        gate.complete();
        await capturing;

        expect(cleanup.deleteCalls, [
          [shot.path],
        ]);
      },
    );

    test('a stale shutter that failed has nothing to clean up', () async {
      final gate = Completer<void>();
      final camera = FakeCameraService(captureFails: true)..captureGate = gate;
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(camera, cleanup: cleanup);
      addTearDown(cubit.close);

      await cubit.start();
      final capturing = cubit.capture();
      await Future<void>.delayed(Duration.zero);

      await cubit.suspend();
      gate.complete();
      await capturing;

      expect(cubit.state, const CameraInitializing());
      expect(cleanup.deleteCalls, isEmpty);
    });
  });

  group('CameraCaptureCubit · flash (F24)', () {
    test(
      'each tap moves off -> auto -> on -> off, through the camera',
      () async {
        final camera = FakeCameraService();
        final cubit = cubitFor(camera);
        addTearDown(cubit.close);
        await cubit.start();

        final seen = <CameraFlashMode>[];
        for (var i = 0; i < 3; i++) {
          await cubit.cycleFlash();
          seen.add((cubit.state as CameraReady).flashMode);
        }

        expect(seen, [
          CameraFlashMode.auto,
          CameraFlashMode.on,
          CameraFlashMode.off,
        ]);
        expect(camera.flashModes, seen);
      },
    );

    test('a phone without a flash ignores the tap', () async {
      final camera = FakeCameraService(
        capabilities: const CameraCapabilities(hasFlash: false, canFocus: true),
      );
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);
      await cubit.start();

      await cubit.cycleFlash();

      expect(camera.flashModes, isEmpty);
      expect((cubit.state as CameraReady).flashMode, CameraFlashMode.off);
    });

    test('a refused change keeps the old mode, with no error page', () async {
      final camera = FakeCameraService()..flashFails = true;
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);
      await cubit.start();

      await cubit.cycleFlash();

      expect(cubit.state, const CameraReady(capabilities: _full));
    });

    test('a second tap while a change is with the camera is ignored', () async {
      final gate = Completer<void>();
      final camera = FakeCameraService()..flashGate = gate;
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);
      await cubit.start();

      final first = cubit.cycleFlash();
      await Future<void>.delayed(Duration.zero);
      await cubit.cycleFlash();
      gate.complete();
      await first;

      // One step, not two that both started from "off".
      expect(camera.flashModes, [CameraFlashMode.auto]);
      expect((cubit.state as CameraReady).flashMode, CameraFlashMode.auto);
    });

    test(
      'opening the camera again lands on off — a retake starts dark',
      () async {
        final camera = FakeCameraService();
        final cubit = cubitFor(camera);
        addTearDown(cubit.close);
        await cubit.start();
        await cubit.cycleFlash();
        await cubit.cycleFlash();

        await cubit.start();

        expect((cubit.state as CameraReady).flashMode, CameraFlashMode.off);
      },
    );

    test('a change that lands after a suspend emits nothing', () async {
      final gate = Completer<void>();
      final camera = FakeCameraService()..flashGate = gate;
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);
      await cubit.start();

      final changing = cubit.cycleFlash();
      await Future<void>.delayed(Duration.zero);
      await cubit.suspend();
      gate.complete();
      await changing;

      expect(cubit.state, const CameraInitializing());
    });

    test('the shot carries the flash mode while it is taken', () async {
      final gate = Completer<void>();
      final camera = FakeCameraService()..captureGate = gate;
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);
      await cubit.start();
      await cubit.cycleFlash();

      final capturing = cubit.capture();
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state,
        const CameraCapturing(
          flashMode: CameraFlashMode.auto,
          capabilities: _full,
        ),
      );
      gate.complete();
      await capturing;
    });
  });

  group('CameraCaptureCubit · tap to focus (F24)', () {
    test('focuses on the tapped point', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);
      await cubit.start();

      await cubit.focusAt(FocusPoint(0.3, 0.7));

      expect(camera.focusPoints, [FocusPoint(0.3, 0.7)]);
    });

    test('a lens that cannot focus on a point is not asked', () async {
      final camera = FakeCameraService(
        capabilities: const CameraCapabilities(hasFlash: true, canFocus: false),
      );
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);
      await cubit.start();

      await cubit.focusAt(FocusPoint.center);

      expect(camera.focusPoints, isEmpty);
    });

    test('a tap before the camera is ready is ignored', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);

      await cubit.focusAt(FocusPoint.center);

      expect(camera.focusPoints, isEmpty);
    });

    test('a lens that declines changes nothing on screen', () async {
      final camera = FakeCameraService()..focusFails = true;
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);
      await cubit.start();

      await cubit.focusAt(FocusPoint.center);

      expect(cubit.state, const CameraReady(capabilities: _full));
    });
  });
}
