import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/analysis/presentation/image_analysis_session_holder.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/image_quality_result.dart';
import 'package:war2aty/features/capture/domain/usecases/assess_image_quality.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/correct_perspective.dart';
import 'package:war2aty/features/capture/domain/usecases/create_analysis_session.dart';
import 'package:war2aty/features/capture/domain/usecases/decide_analysis_route.dart';
import 'package:war2aty/features/capture/domain/usecases/rotate_image.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_state.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/normalized_ocr_text.dart';
import 'package:war2aty/features/ocr/presentation/ocr_session_holder.dart';

import '../../support/fakes.dart';

const _source = CapturedPhoto('/tmp/original.jpg');

const _goodQuality = ImageQualityResult(
  overall: ImageQuality.good,
  blur: ImageQuality.good,
  resolution: ImageQuality.good,
  brightness: ImageQuality.good,
);

ImagePreviewCubit cubitFor(
  FakeImageRotator rotator, {
  FakeImageQualityService? quality,
  FakeAnalysisSessionStorage? storage,
  FakeCaptureFileCleanup? cleanup,
  FakeConnectivityService? connectivity,
  FakeUsageRepository? usage,
  FakePerspectiveCorrector? perspectiveCorrector,
  ImageAnalysisSessionHolder? onlineHandoff,
  OcrSessionHolder? ocrHandoff,
}) {
  final q = quality ?? FakeImageQualityService();
  final s = storage ?? FakeAnalysisSessionStorage();
  final c = cleanup ?? FakeCaptureFileCleanup();
  // Offline by default: every existing (pre-F13) test exercises that route
  // without knowing connectivity exists.
  final conn = connectivity ?? FakeConnectivityService(connected: false);
  // Live by default so a test that opts into `connected: true` exercises the
  // online route without also having to know this flag exists — a test that
  // cares about the gate itself passes its own `usage`.
  final u =
      usage ??
      FakeUsageRepository(
        seed: usageWith(limit: 3, remaining: 3, azureOcrEnabled: true),
      );
  final corrector = perspectiveCorrector ?? FakePerspectiveCorrector();
  return ImagePreviewCubit(
    source: _source,
    rotate: RotateImage(rotator),
    assessQuality: AssessImageQuality(q),
    decideRoute: DecideAnalysisRoute(conn, u),
    correctPerspective: CorrectPerspective(corrector),
    createSession: CreateAnalysisSession(s),
    onlineHandoff: onlineHandoff ?? ImageAnalysisSessionHolder(),
    ocrHandoff: ocrHandoff ?? OcrSessionHolder(),
    cleanupFiles: CleanupCaptureFiles(c),
  );
}

void main() {
  group('ImagePreviewCubit', () {
    test('starts ready with no rotation', () {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      expect(cubit.state, const ImagePreviewReady(0));
    });

    test('each rotate turns the image another quarter, wrapping at 4', () {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      cubit.rotateClockwise();
      expect(cubit.state, const ImagePreviewReady(1));
      cubit.rotateClockwise();
      cubit.rotateClockwise();
      expect(cubit.state, const ImagePreviewReady(3));
      cubit.rotateClockwise();
      expect(cubit.state, const ImagePreviewReady(0));
    });

    test('confirm with no rotation hands back the original image', () async {
      final rotator = FakeImageRotator();
      final cubit = cubitFor(rotator);
      addTearDown(cubit.close);

      await cubit.confirm();

      expect(cubit.state, const ImagePreviewConfirmed(_source, _goodQuality));
      expect(rotator.lastQuarterTurns, 0);
    });

    test(
      'confirm after rotating bakes and hands back the rotated image',
      () async {
        const rotated = CapturedPhoto('/tmp/spun.jpg');
        final rotator = FakeImageRotator(output: rotated);
        final cubit = cubitFor(rotator);
        addTearDown(cubit.close);

        cubit.rotateClockwise();
        await cubit.confirm();

        expect(cubit.state, const ImagePreviewConfirmed(rotated, _goodQuality));
        expect(rotator.lastQuarterTurns, 1);
      },
    );

    test(
      'a failed rotation surfaces the error, keeping the rotation',
      () async {
        final cubit = cubitFor(FakeImageRotator(fails: true));
        addTearDown(cubit.close);

        cubit.rotateClockwise();
        await cubit.confirm();

        expect(cubit.state, const ImagePreviewFailed(1));
      },
    );

    test('a failed quality assessment surfaces the error', () async {
      final quality = FakeImageQualityService(fails: true);
      final cubit = cubitFor(FakeImageRotator(), quality: quality);
      addTearDown(cubit.close);

      await cubit.confirm();

      expect(cubit.state, const ImagePreviewFailed(0));
      expect(quality.assessCount, 1);
    });

    test('confirmed state carries the quality verdict', () async {
      const poorQuality = ImageQualityResult(
        overall: ImageQuality.poor,
        blur: ImageQuality.poor,
        resolution: ImageQuality.good,
        brightness: ImageQuality.good,
      );
      final quality = FakeImageQualityService(result: poorQuality);
      final cubit = cubitFor(FakeImageRotator(), quality: quality);
      addTearDown(cubit.close);

      await cubit.confirm();

      expect(cubit.state, const ImagePreviewConfirmed(_source, poorQuality));
    });

    test('quality assessment receives the rotated photo', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      final quality = FakeImageQualityService();
      final cubit = cubitFor(
        FakeImageRotator(output: rotated),
        quality: quality,
      );
      addTearDown(cubit.close);

      cubit.rotateClockwise();
      await cubit.confirm();

      expect(quality.lastPhoto, rotated);
    });

    test('rotate is ignored while a confirm is in flight', () async {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      final pending = cubit.confirm();
      expect(cubit.state, const ImagePreviewProcessing(0));
      cubit.rotateClockwise();
      expect(cubit.state, const ImagePreviewProcessing(0));

      await pending;
    });

    test('confirming twice keeps the first result', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      final rotator = FakeImageRotator(output: rotated);
      final cubit = cubitFor(rotator);
      addTearDown(cubit.close);

      cubit.rotateClockwise();
      await cubit.confirm();
      await cubit.confirm();

      expect(cubit.state, const ImagePreviewConfirmed(rotated, _goodQuality));
      expect(rotator.rotateCount, 1);
    });

    test('does nothing once closed', () async {
      final rotator = FakeImageRotator();
      final cubit = cubitFor(rotator);
      await cubit.close();

      await cubit.confirm();

      expect(rotator.rotateCount, 0);
    });
  });

  group('ImagePreviewCubit.proceed', () {
    test('creates a session from the confirmed photo', () async {
      final storage = FakeAnalysisSessionStorage();
      final cubit = cubitFor(FakeImageRotator(), storage: storage);
      addTearDown(cubit.close);

      await cubit.confirm();
      await cubit.proceed();

      expect(cubit.state, isA<ImagePreviewSessionCreated>());
      final created = cubit.state as ImagePreviewSessionCreated;
      expect(created.session.id, storage.sessionId);
      expect(storage.createCount, 1);
      expect(storage.lastPhoto, _source);
    });

    test('carries the rotated photo into the session', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      final storage = FakeAnalysisSessionStorage();
      final cubit = cubitFor(
        FakeImageRotator(output: rotated),
        storage: storage,
      );
      addTearDown(cubit.close);

      cubit.rotateClockwise();
      await cubit.confirm();
      await cubit.proceed();

      expect(storage.lastPhoto, rotated);
    });

    test('a failed session creation surfaces the error', () async {
      final storage = FakeAnalysisSessionStorage(fails: true);
      final cubit = cubitFor(FakeImageRotator(), storage: storage);
      addTearDown(cubit.close);

      await cubit.confirm();
      await cubit.proceed();

      expect(cubit.state, const ImagePreviewFailed(0));
    });

    test('is a no-op before confirm', () async {
      final storage = FakeAnalysisSessionStorage();
      final cubit = cubitFor(FakeImageRotator(), storage: storage);
      addTearDown(cubit.close);

      await cubit.proceed();

      expect(cubit.state, const ImagePreviewReady(0));
      expect(storage.createCount, 0);
    });

    test('is a no-op after already created', () async {
      final storage = FakeAnalysisSessionStorage();
      final cubit = cubitFor(FakeImageRotator(), storage: storage);
      addTearDown(cubit.close);

      await cubit.confirm();
      await cubit.proceed();
      await cubit.proceed();

      expect(storage.createCount, 1);
    });

    test('session carries expected id and path', () async {
      final storage = FakeAnalysisSessionStorage(sessionId: 'abc-123');
      final cubit = cubitFor(FakeImageRotator(), storage: storage);
      addTearDown(cubit.close);

      await cubit.confirm();
      await cubit.proceed();

      expect(
        cubit.state,
        const ImagePreviewSessionCreated(
          AnalysisSession(
            id: 'abc-123',
            imagePath: '/cache/analysis_sessions/abc-123/processed.jpg',
          ),
        ),
      );
    });
  });

  group('ImagePreviewCubit.proceed — online route (F13)', () {
    test('perspective-corrects the confirmed photo and hands it off, '
        'skipping OCR entirely', () async {
      const corrected = CapturedPhoto('/tmp/corrected.jpg');
      final storage = FakeAnalysisSessionStorage(sessionId: 'sess-online');
      final corrector = FakePerspectiveCorrector(output: corrected);
      final handoff = ImageAnalysisSessionHolder();
      final cubit = cubitFor(
        FakeImageRotator(),
        storage: storage,
        connectivity: FakeConnectivityService(),
        perspectiveCorrector: corrector,
        onlineHandoff: handoff,
      );
      addTearDown(cubit.close);

      await cubit.confirm();
      await cubit.proceed();

      expect(corrector.correctCount, 1);
      expect(corrector.lastPhoto, _source);
      expect(
        cubit.state,
        const ImagePreviewOnlineReady(
          AnalysisSession(
            id: 'sess-online',
            imagePath: '/cache/analysis_sessions/sess-online/processed.jpg',
          ),
        ),
      );
      expect(
        handoff.session,
        const AnalysisSession(
          id: 'sess-online',
          imagePath: '/cache/analysis_sessions/sess-online/processed.jpg',
        ),
      );
      expect(handoff.photo, corrected);
    });

    test('no detected quad hands the original photo off unchanged', () async {
      final handoff = ImageAnalysisSessionHolder();
      final cubit = cubitFor(
        FakeImageRotator(),
        connectivity: FakeConnectivityService(),
        perspectiveCorrector: FakePerspectiveCorrector(),
        onlineHandoff: handoff,
      );
      addTearDown(cubit.close);

      await cubit.confirm();
      await cubit.proceed();

      expect(cubit.state, isA<ImagePreviewOnlineReady>());
      expect(handoff.photo, _source);
    });

    test('a failed perspective correction fails outright — never falls back '
        'to the offline route', () async {
      final handoff = ImageAnalysisSessionHolder();
      final cubit = cubitFor(
        FakeImageRotator(),
        connectivity: FakeConnectivityService(),
        perspectiveCorrector: FakePerspectiveCorrector(fails: true),
        onlineHandoff: handoff,
      );
      addTearDown(cubit.close);

      await cubit.confirm();
      await cubit.proceed();

      expect(cubit.state, const ImagePreviewFailed(0));
      expect(handoff.session, isNull);
      expect(handoff.photo, isNull);
    });
  });

  group('ImagePreviewCubit.proceed — stale hand-off clearing', () {
    const staleExtraction = ExtractionResult(
      text: NormalizedOcrText(originalText: 'قديم', cleanedText: 'قديم'),
    );

    test(
      'routing online clears a stale offline hand-off from a previous run',
      () async {
        final ocrHandoff = OcrSessionHolder()
          ..set(
            const AnalysisSession(id: 'old', imagePath: '/tmp/old.jpg'),
            staleExtraction,
          );
        final cubit = cubitFor(
          FakeImageRotator(),
          connectivity: FakeConnectivityService(),
          ocrHandoff: ocrHandoff,
        );
        addTearDown(cubit.close);

        await cubit.confirm();
        await cubit.proceed();

        expect(ocrHandoff.session, isNull);
        expect(ocrHandoff.result, isNull);
      },
    );

    test(
      'routing offline clears a stale online hand-off from a previous run',
      () async {
        final onlineHandoff = ImageAnalysisSessionHolder()
          ..set(
            const AnalysisSession(id: 'old', imagePath: '/tmp/old.jpg'),
            const CapturedPhoto('/tmp/old-corrected.jpg'),
          );
        final cubit = cubitFor(
          FakeImageRotator(),
          onlineHandoff: onlineHandoff,
        );
        addTearDown(cubit.close);

        await cubit.confirm();
        await cubit.proceed();

        expect(onlineHandoff.session, isNull);
        expect(onlineHandoff.photo, isNull);
      },
    );
  });

  group('ImagePreviewCubit temp-file cleanup', () {
    test('close without confirm deletes the source file', () async {
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(FakeImageRotator(), cleanup: cleanup);

      await cubit.close();

      expect(cleanup.deleteCalls, hasLength(1));
      expect(cleanup.deleteCalls.first, [_source.path]);
    });

    test('close after no-op rotation deletes only the source', () async {
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(FakeImageRotator(), cleanup: cleanup);

      await cubit.confirm();
      await cubit.close();

      expect(cleanup.deleteCalls, hasLength(1));
      expect(cleanup.deleteCalls.first, [_source.path]);
    });

    test('close after rotation deletes source and rotated file', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(
        FakeImageRotator(output: rotated),
        cleanup: cleanup,
      );

      cubit.rotateClockwise();
      await cubit.confirm();
      await cubit.close();

      expect(cleanup.deleteCalls, hasLength(1));
      expect(
        cleanup.deleteCalls.first,
        unorderedEquals([_source.path, rotated.path]),
      );
    });

    test('close after session created still cleans temp files', () async {
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(FakeImageRotator(), cleanup: cleanup);

      await cubit.confirm();
      await cubit.proceed();
      await cubit.close();

      expect(cleanup.deleteCalls, hasLength(1));
      expect(cleanup.deleteCalls.first, [_source.path]);
    });

    test('close after online route excludes the corrected file '
        'because the holder owns its lifecycle', () async {
      const corrected = CapturedPhoto('/tmp/corrected.jpg');
      final cleanup = FakeCaptureFileCleanup();
      final handoff = ImageAnalysisSessionHolder();
      final cubit = cubitFor(
        FakeImageRotator(),
        cleanup: cleanup,
        connectivity: FakeConnectivityService(),
        perspectiveCorrector: FakePerspectiveCorrector(output: corrected),
        onlineHandoff: handoff,
      );

      await cubit.confirm();
      await cubit.proceed();

      // After proceed, the handoff holds the corrected file.
      expect(handoff.holdsCorrectedFile(corrected.path), isTrue);

      await cubit.close();

      // The corrected file is NOT deleted by close() — the holder owns it
      // until the analysis repository has finished reading its bytes.
      expect(cleanup.deleteCalls, hasLength(1));
      expect(cleanup.deleteCalls.first, [_source.path]);
    });

    test('close after online route with no-op correction '
        'does not duplicate source in cleanup', () async {
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(
        FakeImageRotator(),
        cleanup: cleanup,
        connectivity: FakeConnectivityService(),
        perspectiveCorrector: FakePerspectiveCorrector(),
      );

      await cubit.confirm();
      await cubit.proceed();
      await cubit.close();

      expect(cleanup.deleteCalls, hasLength(1));
      // FakePerspectiveCorrector with no output echoes the input — corrected
      // path equals source, so _correctedPath stays null and only source is
      // cleaned.
      expect(cleanup.deleteCalls.first, [_source.path]);
    });
  });
}
