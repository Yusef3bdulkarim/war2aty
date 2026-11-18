import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/analysis/presentation/image_analysis_session_holder.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/unit_rect.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
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
import '../../support/ui_audit.dart';

const _strings = ArStrings();

const _imagePath = '/tmp/paper.jpg';

Future<_Result> _pumpPreview(
  WidgetTester tester, {
  FakeImageRotator? rotator,
  FakeAnalysisSessionStorage? storage,
  FakeConnectivityService? connectivity,
  FakeUsageRepository? usage,
  ImageAnalysisSessionHolder? onlineHandoff,
  OcrSessionHolder? ocrHandoff,
  Locale locale = AppLocalizations.arabic,
  TextScaler? textScaler,
}) async {
  final result = _Result();
  final cubit = ImagePreviewCubit(
    source: const CapturedPhoto(_imagePath),
    rotate: RotateImage(rotator ?? FakeImageRotator()),
    cropImage: CropImage(FakeImageCropper()),
    decideRoute: DecideAnalysisRoute(
      connectivity ?? FakeConnectivityService(connected: false),
      usage ??
          FakeUsageRepository(
            seed: usageWith(limit: 3, remaining: 3, onlineOcrEnabled: true),
          ),
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
    locale: locale,
    textScaler: textScaler,
  );
  await tester.pump();
  return result;
}

void main() {
  auditScreenLayout(
    'ImagePreviewScreen',
    (tester, locale, scaler) =>
        _pumpPreview(tester, locale: locale, textScaler: scaler),
  );

  group('ImagePreviewScreen', () {
    testWidgets('shows the continue button, voice hint and help button', (
      tester,
    ) async {
      await _pumpPreview(tester);

      expect(find.text(_strings.cropContinue), findsOneWidget);
      expect(find.text(_strings.cropVoiceHint), findsOneWidget);
      expect(find.bySemanticsLabel(_strings.cropHelpLabel), findsOneWidget);
      expect(find.text(_strings.previewTitle), findsNothing);
      expect(find.text(_strings.previewHint), findsNothing);
      expect(find.text(_strings.previewRetake), findsNothing);
    });

    testWidgets('the help button is present but inert', (tester) async {
      final result = await _pumpPreview(tester);

      await tester.tap(find.bySemanticsLabel(_strings.cropHelpLabel));
      await tester.pump();

      expect(result.session, isNull);
      expect(result.retook, isFalse);
    });

    testWidgets('asks for light status-bar icons', (tester) async {
      await _pumpPreview(tester);

      final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(
        regions.map((region) => region.value),
        contains(SystemUiOverlayStyle.light),
      );
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

    testWidgets('continue creates a session and hands it back', (tester) async {
      final storage = FakeAnalysisSessionStorage(sessionId: 'sess-1');
      final result = await _pumpPreview(tester, storage: storage);

      await tester.tap(find.text(_strings.cropContinue));
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
      'continue on the online route skips straight to onOnlineReady',
      (tester) async {
        final result = await _pumpPreview(
          tester,
          connectivity: FakeConnectivityService(),
        );

        await tester.tap(find.text(_strings.cropContinue));
        await tester.pump();
        await tester.pump();

        expect(result.onlineSession, isNotNull);
        expect(result.session, isNull);
      },
    );

    testWidgets('controls disabled while processing', (tester) async {
      final rotator = FakeImageRotator()..gate = Completer<void>();
      await _pumpPreview(tester, rotator: rotator);

      await tester.tap(find.text(_strings.cropContinue));
      await tester.pump();
      await tester.pump();

      final continueButton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text(_strings.cropContinue),
          matching: find.byType(TextButton),
        ),
      );
      expect(continueButton.onPressed, isNull);

      final turnsBefore = tester
          .widget<RotatedBox>(find.byType(RotatedBox))
          .quarterTurns;
      await tester.tap(find.bySemanticsLabel(_strings.previewRotateLabel));
      await tester.pump();
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        turnsBefore,
      );

      rotator.gate!.complete();
      await tester.pump();
    });

    testWidgets('a failed export shows a message and stays put', (
      tester,
    ) async {
      final result = await _pumpPreview(
        tester,
        rotator: FakeImageRotator(fails: true),
      );

      await tester.tap(find.text(_strings.cropContinue));
      await tester.pump();
      await tester.pump();

      expect(result.session, isNull);
      expect(find.text(_strings.previewErrorMessage), findsOneWidget);
      expect(find.text(_strings.cropContinue), findsOneWidget);
    });

    testWidgets('the crop stays on screen while the export runs', (
      tester,
    ) async {
      const chosen = UnitRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8);
      final rotator = FakeImageRotator()..gate = Completer<void>();
      await _pumpPreview(tester, rotator: rotator);

      BlocProvider.of<ImagePreviewCubit>(
        tester.element(find.byType(ImagePreviewScreen)),
      ).updateCrop(chosen);
      await tester.pump();
      await tester.pump();
      expect(_overlayCrop(tester), chosen);

      await tester.tap(find.text(_strings.cropContinue));
      await tester.pump();
      await tester.pump();

      expect(_overlayCrop(tester), chosen);

      rotator.gate!.complete();
      await tester.pump();
    });

    testWidgets('lays out right-to-left', (tester) async {
      await _pumpPreview(tester);

      expect(
        Directionality.of(tester.element(find.text(_strings.cropContinue))),
        TextDirection.rtl,
      );
    });

    testWidgets('survives Large Text without overflowing', (tester) async {
      await _pumpPreview(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });
  });
}

UnitRect _overlayCrop(WidgetTester tester) => tester
    .widget<DraggableCropOverlay>(find.byType(DraggableCropOverlay))
    .cropRect;

final class _Result {
  AnalysisSession? session;
  AnalysisSession? onlineSession;
  bool retook = false;
}
