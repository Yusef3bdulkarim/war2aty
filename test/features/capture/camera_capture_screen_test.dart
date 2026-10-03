import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/navigation/app_route_observer.dart';
import 'package:war2aty/core/widgets/teal_top_bar.dart';
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
import 'package:war2aty/features/capture/presentation/screens/camera_capture_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _strings = ArStrings();
const _flashButton = ValueKey('camera-flash-button');

CameraCaptureCubit _cubitFor(FakeCameraService camera) => CameraCaptureCubit(
  preview: const FakeCameraPreview(),
  initializeCamera: InitializeCamera(camera),
  capturePhoto: CapturePhoto(camera),
  setCameraFlash: SetCameraFlash(camera),
  focusCamera: FocusCamera(camera),
  disposeCamera: DisposeCamera(camera),
  cleanupFiles: CleanupCaptureFiles(FakeCaptureFileCleanup()),
);

/// Pumps the viewfinder over a fake camera, recording what the screen hands
/// back to its host. The opening spinner never settles, so callers pump
/// frames by hand rather than `pumpAndSettle`.
Future<_Result> _pumpViewfinder(
  WidgetTester tester,
  FakeCameraService camera, {
  TextScaler? textScaler,
  List<NavigatorObserver> navigatorObservers = const [],
}) async {
  final result = _Result();
  final cubit = _cubitFor(camera);
  addTearDown(cubit.close);

  await pumpApp(
    tester,
    BlocProvider<CameraCaptureCubit>.value(
      value: cubit,
      child: CameraCaptureScreen(
        onCaptured: (photo) => result.captured = photo,
        onClose: () => result.closed = true,
        onPickFromPhone: () => result.pickedFromPhone = true,
      ),
    ),
    settle: false,
    textScaler: textScaler,
    navigatorObservers: navigatorObservers,
  );
  // Let start()'s initialize() resolve and the first frame settle.
  await tester.pump();
  await tester.pump();
  return result;
}

/// The opacity the status line gives the pill holding [text].
double _opacityOf(WidgetTester tester, String text) => tester
    .widget<AnimatedOpacity>(
      find
          .ancestor(of: find.text(text), matching: find.byType(AnimatedOpacity))
          .first,
    )
    .opacity;

void main() {
  group('CameraCaptureScreen', () {
    testWidgets('once ready: the teal bar, the feed and the capsule — photos, '
        'shutter, flash (F24)', (tester) async {
      await _pumpViewfinder(tester, FakeCameraService());

      expect(find.byType(TealTopBar), findsOneWidget);
      expect(find.byTooltip(_strings.actionBack), findsOneWidget);
      expect(find.byKey(FakeCameraPreview.key), findsOneWidget);
      expect(
        find.bySemanticsLabel(_strings.cameraPickFromPhone),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(_strings.cameraShutterLabel),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(_strings.cameraFlashOff), findsOneWidget);
    });

    testWidgets('the feed runs the full width of the screen (F24, option b)', (
      tester,
    ) async {
      await _pumpViewfinder(tester, FakeCameraService());

      expect(
        tester.getSize(find.byKey(FakeCameraPreview.key)).width,
        tester.getSize(find.byType(Scaffold)).width,
      );
    });

    testWidgets('asks for light status-bar icons', (tester) async {
      await _pumpViewfinder(tester, FakeCameraService());

      // Light status-bar icons over the teal bar and the dark backdrop.
      final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(
        regions.map((region) => region.value),
        contains(SystemUiOverlayStyle.light),
      );
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

    testWidgets('the bar\'s back arrow leaves the flow', (tester) async {
      final result = await _pumpViewfinder(tester, FakeCameraService());

      await tester.tap(find.byTooltip(_strings.actionBack));
      await tester.pump();

      expect(result.closed, isTrue);
    });

    testWidgets('the photos button swaps the camera for the phone\'s photos', (
      tester,
    ) async {
      final result = await _pumpViewfinder(tester, FakeCameraService());

      await tester.tap(find.bySemanticsLabel(_strings.cameraPickFromPhone));
      await tester.pump();

      expect(result.pickedFromPhone, isTrue);
    });

    testWidgets('a camera that will not open shows the error with a retry '
        'and the photos instead, under the bar', (tester) async {
      final result = await _pumpViewfinder(
        tester,
        FakeCameraService(initFails: true),
      );

      expect(find.text(_strings.cameraCaptureErrorTitle), findsOneWidget);
      expect(find.text(_strings.actionRetry), findsOneWidget);
      expect(find.byType(TealTopBar), findsOneWidget);
      expect(find.byKey(FakeCameraPreview.key), findsNothing);

      await tester.tap(find.text(_strings.cameraPickFromPhone));
      await tester.pump();

      expect(result.pickedFromPhone, isTrue);
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
      await _pumpViewfinder(
        tester,
        camera,
        navigatorObservers: [appRouteObserver],
      );
      expect(camera.initializeCount, 1);

      await _retake(tester);

      // The camera must have been reopened rather than left parked on its
      // last, already-consumed state.
      expect(camera.initializeCount, 2);
      expect(find.byKey(FakeCameraPreview.key), findsOneWidget);
    });

    testWidgets('lays out right-to-left', (tester) async {
      await _pumpViewfinder(tester, FakeCameraService());

      expect(
        Directionality.of(
          tester.element(find.bySemanticsLabel(_strings.cameraShutterLabel)),
        ),
        TextDirection.rtl,
      );
      // Photos sit at the start of the capsule — on the right in Arabic.
      expect(
        tester
            .getCenter(find.bySemanticsLabel(_strings.cameraPickFromPhone))
            .dx,
        greaterThan(
          tester
              .getCenter(find.bySemanticsLabel(_strings.cameraShutterLabel))
              .dx,
        ),
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

  group('CameraCaptureScreen · flash (F24)', () {
    testWidgets('each tap names the next mode on the button and in the '
        'status line', (tester) async {
      final camera = FakeCameraService();
      await _pumpViewfinder(tester, camera);

      await tester.tap(find.byKey(_flashButton));
      await tester.pump();

      expect(camera.flashModes, [CameraFlashMode.auto]);
      expect(find.bySemanticsLabel(_strings.cameraFlashAuto), findsOneWidget);
      expect(_opacityOf(tester, _strings.cameraFlashAuto), 1);
    });

    testWidgets("a screen reader's double-tap changes the mode too", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final camera = FakeCameraService();
      await _pumpViewfinder(tester, camera);

      final node = tester.getSemantics(
        find.bySemanticsLabel(_strings.cameraFlashOff),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel(_strings.cameraFlashOff));
      await tester.pump();

      expect(camera.flashModes, [CameraFlashMode.auto]);
      semantics.dispose();
    });

    testWidgets('the mode is spelled out for two seconds, then fades out '
        'with its words rather than vanishing', (tester) async {
      await _pumpViewfinder(tester, FakeCameraService());
      await tester.tap(find.byKey(_flashButton));
      await tester.pump();

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Mid-fade: the words are still drawn, fading.
      expect(find.text(_strings.cameraFlashAuto), findsOneWidget);
      expect(_opacityOf(tester, _strings.cameraFlashAuto), 0);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      // Faded: the chip is gone; the button keeps the mode.
      expect(find.text(_strings.cameraFlashAuto), findsNothing);
      expect(find.bySemanticsLabel(_strings.cameraFlashAuto), findsOneWidget);
    });

    testWidgets('a phone without a flash shows no flash button, and the '
        'shutter stays centred', (tester) async {
      await _pumpViewfinder(
        tester,
        FakeCameraService(
          capabilities: const CameraCapabilities(
            hasFlash: false,
            canFocus: true,
          ),
        ),
      );

      expect(find.byKey(_flashButton), findsNothing);
      final screenCentre = tester.getSize(find.byType(Scaffold)).width / 2;
      expect(
        tester.getCenter(find.bySemanticsLabel(_strings.cameraShutterLabel)).dx,
        moreOrLessEquals(screenCentre),
      );
    });

    testWidgets('with a flash, the shutter is centred too', (tester) async {
      await _pumpViewfinder(tester, FakeCameraService());

      final screenCentre = tester.getSize(find.byType(Scaffold)).width / 2;
      expect(
        tester.getCenter(find.bySemanticsLabel(_strings.cameraShutterLabel)).dx,
        moreOrLessEquals(screenCentre),
      );
    });
  });

  group('CameraCaptureScreen · tap to focus (F24)', () {
    testWidgets('a tap focuses on that point of the feed', (tester) async {
      final camera = FakeCameraService();
      await _pumpViewfinder(tester, camera);

      await tester.tap(find.byKey(FakeCameraPreview.key));
      await tester.pump();

      expect(camera.focusPoints, [FocusPoint.center]);
    });

    testWidgets('a lens that cannot focus on a point ignores the tap', (
      tester,
    ) async {
      final camera = FakeCameraService(
        capabilities: const CameraCapabilities(hasFlash: true, canFocus: false),
      );
      await _pumpViewfinder(tester, camera);

      await tester.tap(find.byKey(FakeCameraPreview.key));
      await tester.pump();

      expect(camera.focusPoints, isEmpty);
    });
  });

  group('CameraCaptureScreen · focus hint, once per visit (F24)', () {
    testWidgets('shows when the camera first opens', (tester) async {
      await _pumpViewfinder(tester, FakeCameraService());

      expect(_opacityOf(tester, _strings.cameraFocusHint), 1);
    });

    testWidgets('is not shown on a lens that cannot focus on a point', (
      tester,
    ) async {
      await _pumpViewfinder(
        tester,
        FakeCameraService(
          capabilities: const CameraCapabilities(
            hasFlash: true,
            canFocus: false,
          ),
        ),
      );

      expect(_opacityOf(tester, _strings.cameraFocusHint), 0);
    });

    testWidgets('hides on its own after four seconds', (tester) async {
      await _pumpViewfinder(tester, FakeCameraService());

      await tester.pump(const Duration(seconds: 4));

      expect(_opacityOf(tester, _strings.cameraFocusHint), 0);
    });

    testWidgets('is read by a screen reader only while it shows', (
      tester,
    ) async {
      await _pumpViewfinder(tester, FakeCameraService());
      // The live semantics tree — what TalkBack and VoiceOver walk.
      final hint = find.semantics.byLabel(_strings.cameraFocusHint);
      expect(hint, findsOne);

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(hint, findsNothing);
    });

    testWidgets('hides at the first tap on the feed', (tester) async {
      await _pumpViewfinder(tester, FakeCameraService());

      await tester.tap(find.byKey(FakeCameraPreview.key));
      await tester.pump();

      expect(_opacityOf(tester, _strings.cameraFocusHint), 0);
    });

    testWidgets('does not come back after a retake', (tester) async {
      await _pumpViewfinder(
        tester,
        FakeCameraService(),
        navigatorObservers: [appRouteObserver],
      );
      await tester.pump(const Duration(seconds: 4));

      await _retake(tester);

      expect(_opacityOf(tester, _strings.cameraFocusHint), 0);
    });
  });
}

/// Takes a shot, then pushes and pops a stand-in for the preview screen —
/// the camera is revealed again exactly as a "retake" reveals it.
Future<void> _retake(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(_strings.cameraShutterLabel));
  await tester.pump();
  await tester.pump();

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
}

/// What the screen handed back to its host.
final class _Result {
  CapturedPhoto? captured;
  bool closed = false;
  bool pickedFromPhone = false;
}
