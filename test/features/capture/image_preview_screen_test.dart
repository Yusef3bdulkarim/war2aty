import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/assess_image_quality.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/create_analysis_session.dart';
import 'package:war2aty/features/capture/domain/usecases/rotate_image.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_cubit.dart';
import 'package:war2aty/features/capture/presentation/screens/image_preview_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _strings = ArStrings();

const _imagePath = '/tmp/paper.jpg';

Future<_Result> _pumpPreview(
  WidgetTester tester, {
  FakeImageRotator? rotator,
  FakeImageQualityService? quality,
  FakeAnalysisSessionStorage? storage,
  TextScaler? textScaler,
}) async {
  final result = _Result();
  final cubit = ImagePreviewCubit(
    source: const CapturedPhoto(_imagePath),
    rotate: RotateImage(rotator ?? FakeImageRotator()),
    assessQuality: AssessImageQuality(quality ?? FakeImageQualityService()),
    createSession: CreateAnalysisSession(
      storage ?? FakeAnalysisSessionStorage(),
    ),
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
final class _Result {
  AnalysisSession? session;
  bool retook = false;
}
