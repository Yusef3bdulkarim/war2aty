import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/navigation/app_route_observer.dart';
import 'package:war2aty/features/capture/domain/entities/camera_frame.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/document_quad.dart';
import 'package:war2aty/features/capture/domain/entities/unit_point.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';
import 'package:war2aty/features/capture/domain/usecases/capture_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_image.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_to_guide_box.dart';
import 'package:war2aty/features/capture/domain/usecases/detect_document_edges.dart';
import 'package:war2aty/features/capture/domain/usecases/dispose_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/initialize_camera.dart';
import 'package:war2aty/features/capture/domain/usecases/start_frame_stream.dart';
import 'package:war2aty/features/capture/domain/usecases/stop_frame_stream.dart';
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
  FakeDocumentEdgeDetector? detector,
}) async {
  final result = _Result();
  final cubit = CameraCaptureCubit(
    preview: const FakeCameraPreview(),
    initializeCamera: InitializeCamera(camera),
    capturePhoto: CapturePhoto(camera),
    cropToGuideBox: CropToGuideBox(CropImage(FakeImageCropper())),
    disposeCamera: DisposeCamera(camera),
    cleanupFiles: CleanupCaptureFiles(FakeCaptureFileCleanup()),
    startFrameStream: StartFrameStream(camera),
    stopFrameStream: StopFrameStream(camera),
    detectDocumentEdges: DetectDocumentEdges(
      detector ?? FakeDocumentEdgeDetector(),
    ),
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
        startFrameStream: StartFrameStream(camera),
        stopFrameStream: StopFrameStream(camera),
        detectDocumentEdges: DetectDocumentEdges(FakeDocumentEdgeDetector()),
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

  group('CameraCaptureScreen · the capture keeps the whole frame', () {
    /// A page filling the middle of the frame.
    const quad = DocumentQuad(
      topLeft: UnitPoint(0.2, 0.15),
      topRight: UnitPoint(0.75, 0.15),
      bottomRight: UnitPoint(0.75, 0.7),
      bottomLeft: UnitPoint(0.2, 0.7),
    );

    /// The failure T10 caught on a real device: a detection collapsed to a
    /// wide, flat sliver. Cropping to it discarded ~85% of the page.
    const sliver = DocumentQuad(
      topLeft: UnitPoint(0.05, 0.60),
      topRight: UnitPoint(0.95, 0.60),
      bottomRight: UnitPoint(0.95, 0.72),
      bottomLeft: UnitPoint(0.05, 0.72),
    );

    CameraFrame frameFor() => CameraFrame(
      bytes: Uint8List(0),
      width: 800,
      height: 600,
      bytesPerRow: 800,
      format: CameraFrameFormat.luma8,
    );

    /// Pumps the viewfinder with a cropper the test can read back, optionally
    /// feeding one detected frame through before the shutter is tapped.
    Future<FakeImageCropper> pumpAndCapture(
      WidgetTester tester, {
      DocumentQuad? detected,
    }) async {
      final camera = FakeCameraService();
      final cropper = FakeImageCropper(
        output: const CapturedPhoto('/tmp/c.jpg'),
      );
      final detector = FakeDocumentEdgeDetector(quad: detected);
      final cubit = CameraCaptureCubit(
        preview: const FakeCameraPreview(),
        initializeCamera: InitializeCamera(camera),
        capturePhoto: CapturePhoto(camera),
        cropToGuideBox: CropToGuideBox(CropImage(cropper)),
        disposeCamera: DisposeCamera(camera),
        cleanupFiles: CleanupCaptureFiles(FakeCaptureFileCleanup()),
        startFrameStream: StartFrameStream(camera),
        stopFrameStream: StopFrameStream(camera),
        detectDocumentEdges: DetectDocumentEdges(detector),
      );
      addTearDown(cubit.close);

      await pumpApp(
        tester,
        BlocProvider<CameraCaptureCubit>.value(
          value: cubit,
          child: CameraCaptureScreen(onCaptured: (_) {}, onClose: () {}),
        ),
        settle: false,
      );
      await tester.pump();
      await tester.pump();

      if (detected != null) {
        await camera.deliverFrame(frameFor());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.tap(find.bySemanticsLabel(_strings.cameraShutterLabel));
      await tester.pump();
      await tester.pump();
      return cropper;
    }

    testWidgets('with no document, nothing is cropped', (tester) async {
      final cropper = await pumpAndCapture(tester);

      expect(cropper.lastRegion, UnitRect.full);
    });

    testWidgets('a detected document does not crop the capture', (
      tester,
    ) async {
      final cropper = await pumpAndCapture(tester, detected: quad);

      // The guide is drawn on the page, but the file keeps the whole frame —
      // `doclens` does the real edge-detect/dewarp on it afterwards.
      expect(cropper.lastRegion, UnitRect.full);
    });

    testWidgets(
      'a collapsed detection cannot crop the document away — the regression '
      'T10 found on a real device',
      (tester) async {
        final cropper = await pumpAndCapture(tester, detected: sliver);

        // Following this quad would have kept a band ~12% of the frame tall
        // and thrown the rest of the page away.
        expect(cropper.lastRegion, UnitRect.full);
      },
    );
  });
}

/// What the screen handed back to its host.
final class _Result {
  CapturedPhoto? captured;
  bool closed = false;
}
