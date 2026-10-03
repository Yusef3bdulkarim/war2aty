import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/domain/entities/camera_flash_mode.dart';

void main() {
  group('CameraFlashMode.next', () {
    test('off moves to auto', () {
      expect(CameraFlashMode.off.next, CameraFlashMode.auto);
    });

    test('auto moves to on', () {
      expect(CameraFlashMode.auto.next, CameraFlashMode.on);
    });

    test('on wraps back to off', () {
      expect(CameraFlashMode.on.next, CameraFlashMode.off);
    });
  });
}
