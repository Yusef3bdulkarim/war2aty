import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/analysis/presentation/image_analysis_session_holder.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/image_quality_result.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';
import 'package:war2aty/features/capture/domain/usecases/assess_image_quality.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/correct_perspective.dart';
import 'package:war2aty/features/capture/domain/usecases/create_analysis_session.dart';
import 'package:war2aty/features/capture/domain/usecases/crop_image.dart';
import 'package:war2aty/features/capture/domain/usecases/decide_analysis_route.dart';
import 'package:war2aty/features/capture/domain/usecases/rotate_image.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_cubit.dart';
import 'package:war2aty/features/capture/presentation/screens/image_preview_screen.dart';
import 'package:war2aty/features/capture/presentation/widgets/draggable_crop_overlay.dart';
import 'package:war2aty/features/ocr/presentation/ocr_session_holder.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _strings = ArStrings();

const _imagePath = '/tmp/paper.jpg';

Future<_Result> _pumpPreview(
  WidgetTester tester, {
  FakeImageRotator? rotator,
  FakeImageQualityService? quality,
  FakeAnalysisSessionStorage? storage,
  FakeConnectivityService? connectivity,
  FakeUsageRepository? usage,
  FakePerspectiveCorrector? perspectiveCorrector,
  ImageAnalysisSessionHolder? onlineHandoff,
  OcrSessionHolder? ocrHandoff,
  TextScaler? textScaler,
}) async {
  final result = _Result();
  final cubit = ImagePreviewCubit(
    source: const CapturedPhoto(_imagePath),
    rotate: RotateImage(rotator ?? FakeImageRotator()),
    cropImage: CropImage(FakeImageCropper()),
    assessQuality: AssessImageQuality(quality ?? FakeImageQualityService()),
    decideRoute: DecideAnalysisRoute(
      connectivity ?? FakeConnectivityService(connected: false),
      // Live by default so a test that opts into `connected: true` exercises
      // the online route without also having to know this flag exists.
      usage ??
          FakeUsageRepository(
            seed: usageWith(limit: 3, remaining: 3, azureOcrEnabled: true),
          ),
    ),
    correctPerspective: CorrectPerspective(
      perspectiveCorrector ?? FakePerspectiveCorrector(),
    ),
    createSession: CreateAnalysisSession(
      storage ?? FakeAnalysisSessionStorage(),
    ),
    onlineHandoff: onlineHandoff ?? ImageAnalysisSessionHolder(),
    ocrHandoff: ocrHandoff ?? OcrSessionHolder(),
    cleanupFiles: CleanupCaptureFiles(FakeCaptureFileCleanup()),
  );
  addTearDown(cubit.close);

  await pumpApp(
    tester,
    BlocProvider<ImagePreviewCubit>.value(
      value: cubit,
      child: ImagePreviewScreen(
        imagePath: _imagePath,
        onSessionCreated: (session) {
          result.session = session;
        },
        onOnlineReady: (session) {
          result.onlineSession = session;
        },
        onRetake: () => result.retook = true,
      ),
    ),
    settle: false,
    textScaler: textScaler,
  );
  await tester.pump();
  return result;
}

void main() {
  group('ImagePreviewScreen', () {
    testWidgets('shows the title, hint and both actions', (tester) async {
      await _pumpPreview(tester);

      expect(find.text(_strings.previewTitle), findsOneWidget);
      expect(find.text(_strings.previewHint), findsOneWidget);
      expect(find.text(_strings.previewUseImage), findsOneWidget);
      expect(find.text(_strings.previewRetake), findsOneWidget);
    });

    testWidgets('the rotate button turns the preview a quarter', (
      tester,
    ) async {
      await _pumpPreview(tester);

      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        0,
      );

      await tester.tap(find.bySemanticsLabel(_strings.previewRotateLabel));
      await tester.pump();

      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        1,
      );
    });

    testWidgets('use-image creates a session and hands it back', (
      tester,
    ) async {
      final storage = FakeAnalysisSessionStorage(sessionId: 'sess-1');
      final result = await _pumpPreview(tester, storage: storage);

      await tester.tap(find.text(_strings.previewUseImage));
      await tester.pump();
      await tester.pump();

      expect(
        result.session,
        const AnalysisSession(
          id: 'sess-1',
          imagePath: '/cache/analysis_sessions/sess-1/processed.jpg',
        ),
      );
      expect(storage.createCount, 1);
    });

    testWidgets(
      'use-image on the online route skips straight to onOnlineReady, '
      'never onSessionCreated',
      (tester) async {
        final result = await _pumpPreview(
          tester,
          connectivity: FakeConnectivityService(),
        );

        await tester.tap(find.text(_strings.previewUseImage));
        await tester.pump();
        await tester.pump();

        expect(result.onlineSession, isNotNull);
        expect(result.session, isNull);
      },
    );

    testWidgets('retake backs out of the flow', (tester) async {
      final result = await _pumpPreview(tester);

      await tester.tap(find.text(_strings.previewRetake));
      await tester.pump();

      expect(result.retook, isTrue);
    });

    testWidgets('a failed export shows a message and stays put', (
      tester,
    ) async {
      final result = await _pumpPreview(
        tester,
        rotator: FakeImageRotator(fails: true),
      );

      await tester.tap(find.text(_strings.previewUseImage));
      await tester.pump();
      await tester.pump();

      expect(result.session, isNull);
      expect(find.text(_strings.previewErrorMessage), findsOneWidget);
      // Still on the preview, able to try again.
      expect(find.text(_strings.previewUseImage), findsOneWidget);
    });

    testWidgets('the crop stays on screen while the export runs (F15-T13)', (
      tester,
    ) async {
      const chosen = UnitRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8);
      // Hold the rotate step so the screen sits in the processing state.
      final rotator = FakeImageRotator()..gate = Completer<void>();
      await _pumpPreview(tester, rotator: rotator);

      // Set the crop through the cubit rather than by dragging: `_imagePath`
      // does not exist, and the placeholder only appears after real file I/O
      // that a widget test's fake clock never lets complete.
      BlocProvider.of<ImagePreviewCubit>(
        tester.element(find.byType(ImagePreviewScreen)),
      ).updateCrop(chosen);
      await tester.pump();
      await tester.pump();
      expect(_overlayCrop(tester), chosen);

      await tester.tap(find.text(_strings.previewUseImage));
      await tester.pump();
      await tester.pump();

      // Mid-export: the overlay used to spring back open behind the veil.
      expect(_overlayCrop(tester), chosen);

      rotator.gate!.complete();
      await tester.pump();
    });

    testWidgets('the crop stays on screen behind the quality sheet (F15-T14)', (
      tester,
    ) async {
      const chosen = UnitRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8);
      // Poor quality → the «ممكن الصورة تطلع أوضح» sheet opens over the
      // preview, which stays visible underneath it.
      await _pumpPreview(
        tester,
        quality: FakeImageQualityService(
          result: const ImageQualityResult(
            overall: ImageQuality.poor,
            blur: ImageQuality.poor,
            resolution: ImageQuality.good,
            brightness: ImageQuality.good,
          ),
        ),
      );

      final cubit = BlocProvider.of<ImagePreviewCubit>(
        tester.element(find.byType(ImagePreviewScreen)),
      );
      cubit.rotateClockwise();
      cubit.updateCrop(chosen);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text(_strings.previewUseImage));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        find.text(_strings.qualityAlertTitle),
        findsOneWidget,
        reason: 'the quality sheet should be up',
      );
      // It used to spring back to the raw photo right as the user was asked
      // to judge it.
      expect(_overlayCrop(tester), chosen);
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        1,
      );
    });

    testWidgets('lays out right-to-left', (tester) async {
      await _pumpPreview(tester);

      expect(
        Directionality.of(tester.element(find.text(_strings.previewTitle))),
        TextDirection.rtl,
      );
    });

    testWidgets('survives Large Text without overflowing', (tester) async {
      await _pumpPreview(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });
  });
}

/// What the screen handed back to its host.
/// The crop rect the on-screen overlay is currently showing.
UnitRect _overlayCrop(WidgetTester tester) => tester
    .widget<DraggableCropOverlay>(find.byType(DraggableCropOverlay))
    .cropRect;

final class _Result {
  AnalysisSession? session;
  AnalysisSession? onlineSession;
  bool retook = false;
}
