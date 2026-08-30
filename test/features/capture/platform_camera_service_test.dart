import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/data/services/platform_camera_service.dart';
import 'package:war2aty/features/capture/domain/entities/camera_frame.dart';

void main() {
  group('PlatformCameraService.buildFrame', () {
    test('keeps the reported row stride rather than assuming the width', () {
      // A padded plane: 640 pixels of luma in rows of 672 bytes. Reading this
      // as if the stride were the width is what shears the image.
      final frame = PlatformCameraService.buildFrame(
        bytes: Uint8List(672 * 480),
        width: 640,
        height: 480,
        bytesPerRow: 672,
        format: CameraFrameFormat.luma8,
      );

      expect(frame, isNotNull);
      expect(frame!.bytesPerRow, 672);
      expect(frame.width, 640);
    });

    test('falls back to a packed row when the platform reports no stride', () {
      final frame = PlatformCameraService.buildFrame(
        bytes: Uint8List(640 * 480),
        width: 640,
        height: 480,
        bytesPerRow: null,
        format: CameraFrameFormat.luma8,
      );

      expect(frame!.bytesPerRow, 640);
    });

    test('a BGRA plane is four bytes per pixel', () {
      final frame = PlatformCameraService.buildFrame(
        bytes: Uint8List(640 * 4 * 480),
        width: 640,
        height: 480,
        bytesPerRow: null,
        format: CameraFrameFormat.bgra8888,
      );

      expect(frame!.bytesPerRow, 640 * 4);
      expect(frame.format, CameraFrameFormat.bgra8888);
    });

    test('an impossibly short stride is treated as unreported', () {
      final frame = PlatformCameraService.buildFrame(
        bytes: Uint8List(640 * 480),
        width: 640,
        height: 480,
        bytesPerRow: 12,
        format: CameraFrameFormat.luma8,
      );

      expect(frame!.bytesPerRow, 640);
    });

    test('a buffer too small for its own geometry is rejected', () {
      final frame = PlatformCameraService.buildFrame(
        bytes: Uint8List(1000),
        width: 640,
        height: 480,
        bytesPerRow: 640,
        format: CameraFrameFormat.luma8,
      );

      expect(frame, isNull);
    });

    test('carries the sensor orientation and mirroring for the mapper', () {
      final frame = PlatformCameraService.buildFrame(
        bytes: Uint8List(640 * 480),
        width: 640,
        height: 480,
        bytesPerRow: 640,
        format: CameraFrameFormat.luma8,
        sensorOrientation: 270,
        isMirrored: true,
      );

      expect(frame!.sensorOrientation, 270);
      expect(frame.isMirrored, isTrue);
    });

    test('never puts frame content in its string form', () {
      final frame = PlatformCameraService.buildFrame(
        bytes: Uint8List.fromList(List.filled(640 * 480, 42)),
        width: 640,
        height: 480,
        bytesPerRow: 640,
        format: CameraFrameFormat.luma8,
      );

      expect(frame.toString(), isNot(contains('42')));
    });
  });
}
