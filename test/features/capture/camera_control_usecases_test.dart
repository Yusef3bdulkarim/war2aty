import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/capture/domain/entities/camera_capabilities.dart';
import 'package:war2aty/features/capture/domain/entities/camera_flash_mode.dart';
import 'package:war2aty/features/capture/domain/entities/focus_point.dart';
import 'package:war2aty/features/capture/domain/usecases/focus_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/initialize_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/set_camera_flash.dart';

import '../../support/fakes.dart';

void main() {
  group('InitializeCamera', () {
    test('passes on what the camera can do', () async {
      const capabilities = CameraCapabilities(hasFlash: false, canFocus: true);
      final camera = FakeCameraService(capabilities: capabilities);

      final result = await InitializeCamera(camera)();

      expect(result.valueOrNull, capabilities);
    });
  });

  group('SetCameraFlash', () {
    test('asks the camera for the given mode', () async {
      final camera = FakeCameraService();

      final result = await SetCameraFlash(camera)(CameraFlashMode.auto);

      expect(result.isOk, isTrue);
      expect(camera.flashModes, [CameraFlashMode.auto]);
    });

    test('passes a refusal on as a failure', () async {
      final camera = FakeCameraService()..flashFails = true;

      final result = await SetCameraFlash(camera)(CameraFlashMode.on);

      expect(result.failureOrNull, const ImageProcessingFailure());
    });
  });

  group('FocusCamera', () {
    test('asks the camera to focus on the given point', () async {
      final camera = FakeCameraService();
      final point = FocusPoint(0.2, 0.8);

      final result = await FocusCamera(camera)(point);

      expect(result.isOk, isTrue);
      expect(camera.focusPoints, [point]);
    });

    test('passes a refusal on as a failure', () async {
      final camera = FakeCameraService()..focusFails = true;

      final result = await FocusCamera(camera)(FocusPoint.center);

      expect(result.failureOrNull, const ImageProcessingFailure());
    });
  });
}
