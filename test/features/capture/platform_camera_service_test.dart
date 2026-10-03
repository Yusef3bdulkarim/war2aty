import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/data/services/platform_camera_service.dart';
import 'package:war2aty/features/capture/domain/entities/camera_flash_mode.dart';

void main() {
  group('PlatformCameraService.pluginFlashMode', () {
    test('off stays off', () {
      expect(
        PlatformCameraService.pluginFlashMode(CameraFlashMode.off),
        FlashMode.off,
      );
    });

    test('auto lets the phone decide', () {
      expect(
        PlatformCameraService.pluginFlashMode(CameraFlashMode.auto),
        FlashMode.auto,
      );
    });

    test('on fires with every shot — never the torch (F24)', () {
      expect(
        PlatformCameraService.pluginFlashMode(CameraFlashMode.on),
        FlashMode.always,
      );
    });
  });
}
