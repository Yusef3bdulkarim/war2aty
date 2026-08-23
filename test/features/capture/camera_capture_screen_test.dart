import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/navigation/app_route_observer.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/capture_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_image.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_to_guide_box.dart';
import 'package:war2aty/features/capture/domain/usecases/dispose_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/initialize_camera.dart';
import 'package:war2aty/features/capture/presentation/cubit/camera_capture_cubit.dart';
import 'package:war2aty/features/capture/presentation/screens/camera_capture_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _strings = ArStrings();

/// Pumps the viewfinder over a fake camera, recording the captured photo and
/// whether the user closed the flow. The camera's animations never settle, so
/// callers pump frames by hand rather than `pumpAndSettle`.
Future<_Result> _pumpViewfinder(
  WidgetTester tester,
  FakeCameraService camera, {
  TextScaler? textScaler,
}) async {
  final result = _Result();
  final cubit = CameraCaptureCubit(
    preview: const FakeCameraPreview(),
    initializeCamera: InitializeCamera(camera),
    capturePhoto: CapturePhoto(camera),
    cropToGuideBox: CropToGuideBox(CropImage(FakeImageCropper())),
    disposeCamera: DisposeCamera(camera),
    cleanupFiles: CleanupCaptureFiles(FakeCaptureFileCleanup()),
  );
  addTearDown(cubit.close);

  await pumpApp(
    tester,
    BlocProvider<CameraCaptureCubit>.value(
      value: cubit,
      child: CameraCaptureScreen(
        onCaptured: (photo) => result.captured = photo,
        onClose: () => result.closed = true,
      ),
    ),
    settle: false,
    textScaler: textScaler,
  );
  // Let start()'s initialize() resolve and the first frame settle.
  await tester.pump();
  await tester.pump();
  return result;
}

void main() {
  group('CameraCaptureScreen', () {
    testWidgets('shows the live preview and framing hint once ready', (
      tester,
    ) async {
      await _pumpViewfinder(tester, FakeCameraService());

      expect(find.byKey(FakeCameraPreview.key), findsOneWidget);
      expect(find.text(_strings.cameraViewfinderHint), findsOneWidget);
    });

    testWidgets('the shutter hands back a captured photo', (tester) async {
      const shot = CapturedPhoto('/tmp/paper.jpg');
      final result = await _pumpViewfinder(
        tester,
        FakeCameraService(photo: shot),
      );

      await tester.tap(find.bySemanticsLabel(_strings.cameraShutterLabel));
      await tester.pump();
      await tester.pump();

      expect(result.captured, shot);
    });

    testWidgets('the close button leaves the flow', (tester) async {
      final result = await _pumpViewfinder(tester, FakeCameraService());

      await tester.tap(find.bySemanticsLabel(_strings.cameraCloseLabel));
      await tester.pump();

      expect(result.closed, isTrue);
    });

    testWidgets('a camera that will not open shows the error with a retry', (
      tester,
    ) async {
      await _pumpViewfinder(tester, FakeCameraService(initFails: true));

      expect(find.text(_strings.cameraCaptureErrorTitle), findsOneWidget);
      expect(find.text(_strings.actionRetry), findsOneWidget);
      expect(find.byKey(FakeCameraPreview.key), findsNothing);
    });

    testWidgets('retry re-opens the camera', (tester) async {
      final camera = FakeCameraService(initFails: true);
      await _pumpViewfinder(tester, camera);

      camera.initFails = false;
      await tester.tap(find.text(_strings.actionRetry));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(FakeCameraPreview.key), findsOneWidget);
    });

    testWidgets('reopens the camera when revealed again by a pop, instead of '
        'staying stuck on the captured/opening state (regression, bug: '
        'retake/back loops forever without opening the camera)', (
      tester,
    ) async {
      final camera = FakeCameraService();
      final cubit = CameraCaptureCubit(
        preview: const FakeCameraPreview(),
        initializeCamera: InitializeCamera(camera),
        capturePhoto: CapturePhoto(camera),
        cropToGuideBox: CropToGuideBox(CropImage(FakeImageCropper())),
        disposeCamera: DisposeCamera(camera),
        cleanupFiles: CleanupCaptureFiles(FakeCaptureFileCleanup()),
      );
      addTearDown(cubit.close);

      // A real host app: a Navigator with the shared route observer, and a
      // second, pushed route standing in for `/preview` (or `/ocr-review`)
      // — the screen this bug is about is never the very first route.
      await pumpApp(
        tester,
        BlocProvider<CameraCaptureCubit>.value(
          value: cubit,
          child: CameraCaptureScreen(onCaptured: (_) {}, onClose: () {}),
        ),
        settle: false,
        navigatorObservers: [appRouteObserver],
      );
      await tester.pump();
      await tester.pump();
      expect(camera.initializeCount, 1);

      // Take a shot: the cubit parks on the terminal `CameraCaptured`
      // state, exactly like right before the real preview screen is
      // pushed on top of this one.
      await tester.tap(find.bySemanticsLabel(_strings.cameraShutterLabel));
      await tester.pump();
      await tester.pump();

      // Push a screen on top (the preview/OCR-review stand-in), then pop
      // back — mirroring "retake" or the device back button.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      );
      await tester.pump();
      navigator.pop();
      await tester.pump();
      await tester.pump();

      // The camera must have been reopened rather than left parked on its
      // last, already-consumed state.
      expect(camera.initializeCount, 2);
      expect(find.byKey(FakeCameraPreview.key), findsOneWidget);
    });

    testWidgets('lays out right-to-left', (tester) async {
      await _pumpViewfinder(tester, FakeCameraService());

      expect(
        Directionality.of(
          tester.element(find.text(_strings.cameraViewfinderHint)),
        ),
        TextDirection.rtl,
      );
    });

    testWidgets('survives Large Text without overflowing', (tester) async {
      await _pumpViewfinder(
        tester,
        FakeCameraService(),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

/// What the screen handed back to its host.
final class _Result {
  CapturedPhoto? captured;
  bool closed = false;
}
