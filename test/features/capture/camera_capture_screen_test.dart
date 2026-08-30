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
import 'package:war2aty/features/capture/presentation/widgets/viewfinder_frame.dart';

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

  group(
    'CameraCaptureScreen · the crop follows the visible guide (F16-T08)',
    () {
      /// A page filling the middle of the frame. The sensor is upright and the
      /// aspects match, so this arrives on the preview unchanged and the numbers
      /// below are the ones the crop must use.
      const quad = DocumentQuad(
        topLeft: UnitPoint(0.2, 0.15),
        topRight: UnitPoint(0.75, 0.15),
        bottomRight: UnitPoint(0.75, 0.7),
        bottomLeft: UnitPoint(0.2, 0.7),
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
      Future<({FakeImageCropper cropper, Size preview})> pumpAndCapture(
        WidgetTester tester, {
        DocumentQuad? detected,

        /// A second detection, delivered after the first has settled. The
        /// shutter then fires part-way through the glide toward it.
        DocumentQuad? thenMovedTo,
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
        if (thenMovedTo != null) {
          detector.quad = thenMovedTo;
          await camera.deliverFrame(frameFor());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
        }

        // Measured before the shutter, since the preview leaves the tree the
        // moment the capture starts.
        final preview = tester.getSize(find.byKey(FakeCameraPreview.key));

        await tester.tap(find.bySemanticsLabel(_strings.cameraShutterLabel));
        await tester.pump();
        await tester.pump();
        return (cropper: cropper, preview: preview);
      }

      testWidgets(
        'with a document, the crop is its bounding rect plus the margin',
        (tester) async {
          final (:cropper, :preview) = await pumpAndCapture(
            tester,
            detected: quad,
          );

          // The one promise of this task: what was framed is what is kept. The
          // 20% margin is CropToGuideBox's and is applied exactly once.
          final expected = quad.boundingRect.expanded(CropToGuideBox.margin);
          expect(cropper.lastRegion!.left, closeTo(expected.left, 0.01));
          expect(cropper.lastRegion!.top, closeTo(expected.top, 0.01));
          expect(cropper.lastRegion!.right, closeTo(expected.right, 0.01));
          expect(cropper.lastRegion!.bottom, closeTo(expected.bottom, 0.01));
        },
      );

      testWidgets('with no document, the crop is the F15-T12 static box', (
        tester,
      ) async {
        final (:cropper, :preview) = await pumpAndCapture(tester);

        final box = ViewfinderFrame.resolveSize(preview);
        final expected = UnitRect(
          left: (preview.width - box.width) / 2 / preview.width,
          top: (preview.height - box.height) / 2 / preview.height,
          right: (preview.width + box.width) / 2 / preview.width,
          bottom: (preview.height + box.height) / 2 / preview.height,
        ).expanded(CropToGuideBox.margin);

        expect(cropper.lastRegion!.left, closeTo(expected.left, 0.01));
        expect(cropper.lastRegion!.top, closeTo(expected.top, 0.01));
        expect(cropper.lastRegion!.right, closeTo(expected.right, 0.01));
        expect(cropper.lastRegion!.bottom, closeTo(expected.bottom, 0.01));
      });

      testWidgets(
        'a capture mid-glide crops to what is drawn, not to the state',
        (tester) async {
          const moved = DocumentQuad(
            topLeft: UnitPoint(0.05, 0.05),
            topRight: UnitPoint(0.5, 0.05),
            bottomRight: UnitPoint(0.5, 0.5),
            bottomLeft: UnitPoint(0.05, 0.5),
          );

          final (:cropper, :preview) = await pumpAndCapture(
            tester,
            detected: quad,
            thenMovedTo: moved,
          );

          // The guide is still gliding toward the new detection, so the crop is
          // what the user saw — between the two — and not the quad the cubit is
          // already holding.
          final target = moved.boundingRect.expanded(CropToGuideBox.margin);
          final previous = quad.boundingRect.expanded(CropToGuideBox.margin);
          expect(
            (cropper.lastRegion!.left - target.left).abs(),
            greaterThan(0.005),
          );
          expect(cropper.lastRegion!.left, lessThan(previous.left));
        },
      );

      testWidgets('a collapsed detection keeps the whole photo', (
        tester,
      ) async {
        const collapsed = DocumentQuad(
          topLeft: UnitPoint(0.5, 0.5),
          topRight: UnitPoint(0.52, 0.5),
          bottomRight: UnitPoint(0.52, 0.52),
          bottomLeft: UnitPoint(0.5, 0.52),
        );

        final (:cropper, :preview) = await pumpAndCapture(
          tester,
          detected: collapsed,
        );

        // Never a hairline crop: the shutter still fires, and the whole frame
        // is kept for doclens to work on.
        expect(cropper.lastRegion, UnitRect.full);
      });
    },
  );
}

/// What the screen handed back to its host.
final class _Result {
  CapturedPhoto? captured;
  bool closed = false;
}
