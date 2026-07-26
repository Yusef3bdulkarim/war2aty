import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/capture_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/dispose_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/initialize_camera.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_capture_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_capture_state.dart';

import '../../support/fakes.dart';

CameraCaptureCubit cubitFor(FakeCameraService camera) {
  return CameraCaptureCubit(
    preview: const FakeCameraPreview(),
    initializeCamera: InitializeCamera(camera),
    capturePhoto: CapturePhoto(camera),
    disposeCamera: DisposeCamera(camera),
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
      await cubit.capture();

      expect(cubit.state, const CameraCaptured(shot));
    });

    test('the shutter is ignored unless the preview is live', () async {
      final camera = FakeCameraService();
      final cubit = cubitFor(camera);
      addTearDown(cubit.close);

      // Still initializing — no ready state reached yet.
      await cubit.capture();

      expect(camera.captureCount, 0);
      expect(cubit.state, const CameraInitializing());
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
}
