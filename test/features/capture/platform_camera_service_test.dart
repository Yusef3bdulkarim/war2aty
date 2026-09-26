import 'dart:typed_data';

import 'package:camera/camera.dart';
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

    test('an ultraHigh luma frame with a padded stride survives (F17-T07)', () {
      // The preset drives the stream as well as the shutter, so the ladder's
      // top rung means 3840x2160 frames on Android. 4K rows are likelier to
      // be hardware-aligned than 720p ones were: 3840 padded to 3904 is the
      // case that shears the image if the stride is ignored.
      final frame = PlatformCameraService.buildFrame(
        bytes: Uint8List(3904 * 2160),
        width: 3840,
        height: 2160,
        bytesPerRow: 3904,
        format: CameraFrameFormat.luma8,
      );

      expect(frame, isNotNull);
      expect(frame!.bytesPerRow, 3904);
      expect(frame.width, 3840);
      expect(frame.height, 2160);
    });

    test('an ultraHigh BGRA frame survives — ~33 MB, four bytes a pixel', () {
      // iOS streams BGRA, so the same rung costs 4 bytes per pixel here. The
      // size is the point: this is the per-frame allocation F17-T11 has to
      // measure on a real device.
      final frame = PlatformCameraService.buildFrame(
        bytes: Uint8List(3840 * 4 * 2160),
        width: 3840,
        height: 2160,
        bytesPerRow: null,
        format: CameraFrameFormat.bgra8888,
      );

      expect(frame, isNotNull);
      expect(frame!.bytesPerRow, 3840 * 4);
      expect(frame.format, CameraFrameFormat.bgra8888);
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

  group('PlatformCameraService.presetLadder', () {
    test('runs from ultraHigh down to high, best first', () {
      expect(PlatformCameraService.presetLadder, [
        ResolutionPreset.ultraHigh,
        ResolutionPreset.veryHigh,
        ResolutionPreset.high,
      ]);
    });

    test('never asks for max — an unbounded file the backend would reject', () {
      expect(
        PlatformCameraService.presetLadder,
        isNot(contains(ResolutionPreset.max)),
      );
    });
  });

  group('PlatformCameraService.openAtBestPreset', () {
    test('takes the top rung when the device accepts it', () async {
      final device = _FakeDevice();

      final session = await PlatformCameraService.openAtBestPreset<String>(
        ladder: PlatformCameraService.presetLadder,
        open: device.open,
        isSuperseded: () => false,
      );

      expect(session, 'ultraHigh');
      expect(device.tried, [ResolutionPreset.ultraHigh]);
    });

    test('steps down one rung when the top preset is refused', () async {
      final device = _FakeDevice(refuses: const {ResolutionPreset.ultraHigh});

      final session = await PlatformCameraService.openAtBestPreset<String>(
        ladder: PlatformCameraService.presetLadder,
        open: device.open,
        isSuperseded: () => false,
      );

      expect(session, 'veryHigh');
      expect(device.tried, [
        ResolutionPreset.ultraHigh,
        ResolutionPreset.veryHigh,
      ]);
    });

    test('keeps stepping down to the bottom rung', () async {
      final device = _FakeDevice(
        refuses: const {ResolutionPreset.ultraHigh, ResolutionPreset.veryHigh},
      );

      final session = await PlatformCameraService.openAtBestPreset<String>(
        ladder: PlatformCameraService.presetLadder,
        open: device.open,
        isSuperseded: () => false,
      );

      expect(session, 'high');
      expect(device.tried, PlatformCameraService.presetLadder);
    });

    test('a device that refuses every rung yields no session', () async {
      final device = _FakeDevice(
        refuses: PlatformCameraService.presetLadder.toSet(),
      );

      final session = await PlatformCameraService.openAtBestPreset<String>(
        ladder: PlatformCameraService.presetLadder,
        open: device.open,
        isSuperseded: () => false,
      );

      expect(session, isNull);
      expect(device.tried, PlatformCameraService.presetLadder);
    });

    test(
      'a dispose mid-ladder stops it opening a camera nobody wants',
      () async {
        final device = _FakeDevice(refuses: const {ResolutionPreset.ultraHigh});

        final session = await PlatformCameraService.openAtBestPreset<String>(
          ladder: PlatformCameraService.presetLadder,
          open: device.open,
          // Superseded as soon as the first rung has been tried and refused.
          isSuperseded: () => device.tried.isNotEmpty,
        );

        expect(session, isNull);
        expect(device.tried, [ResolutionPreset.ultraHigh]);
      },
    );

    test('a session already superseded opens nothing at all', () async {
      final device = _FakeDevice();

      final session = await PlatformCameraService.openAtBestPreset<String>(
        ladder: PlatformCameraService.presetLadder,
        open: device.open,
        isSuperseded: () => true,
      );

      expect(session, isNull);
      expect(device.tried, isEmpty);
    });

    test('an empty ladder yields no session rather than hanging', () async {
      final session = await PlatformCameraService.openAtBestPreset<String>(
        ladder: const [],
        open: (preset) async => preset.name,
        isSuperseded: () => false,
      );

      expect(session, isNull);
    });
  });
}

/// A stand-in device for the ladder walker: accepts every preset except the
/// ones it [refuses], and records which rungs it was asked for, so a test can
/// assert where the ladder stopped rather than only what it returned.
final class _FakeDevice {
  _FakeDevice({this.refuses = const {}});

  final Set<ResolutionPreset> refuses;
  final List<ResolutionPreset> tried = [];

  Future<String> open(ResolutionPreset preset) async {
    tried.add(preset);
    if (refuses.contains(preset)) {
      throw CameraException('resolution_not_supported', '$preset');
    }
    return preset.name;
  }
}
