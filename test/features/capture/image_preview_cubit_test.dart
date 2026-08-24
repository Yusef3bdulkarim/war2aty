import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
  FakeImageCropper? cropper,
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
    cropImage: CropImage(cropper ?? FakeImageCropper()),
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

    test(
      'quality assessment receives the final (rotated + cropped) photo',
      () async {
        const rotated = CapturedPhoto('/tmp/spun.jpg');
        final quality = FakeImageQualityService();
        // Default cropper: no output set, crop is a no-op (returns input
        // unchanged when cropRect is full). So quality sees the rotated file.
        final cubit = cubitFor(
          FakeImageRotator(output: rotated),
          quality: quality,
        );
        addTearDown(cubit.close);

        cubit.rotateClockwise();
        await cubit.confirm();

        expect(quality.lastPhoto, rotated);
      },
    );

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

    test('close after online route skips cleanup entirely — '
        'the holder owns every temp file', () async {
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

      // After proceed, the holder received all cleanup paths.
      expect(handoff.photo?.path, corrected.path);

      await cubit.close();

      // close() does NOT delete anything — the holder deletes all files
      // in clear() after the analysis has read the image bytes.
      expect(cleanup.deleteCalls, isEmpty);
    });

    test('close after online route with no-op correction '
        'also skips cleanup — holder owns the files', () async {
      final cleanup = FakeCaptureFileCleanup();
      final handoff = ImageAnalysisSessionHolder();
      final cubit = cubitFor(
        FakeImageRotator(),
        cleanup: cleanup,
        connectivity: FakeConnectivityService(),
        perspectiveCorrector: FakePerspectiveCorrector(),
        onlineHandoff: handoff,
      );

      await cubit.confirm();
      await cubit.proceed();
      await cubit.close();

      // Even when doclens returned the input unchanged (no new corrected
      // file), close() skips cleanup because the handoff succeeded.
      // The holder's clear() will delete the source file later.
      expect(cleanup.deleteCalls, isEmpty);
    });
  });

  group('ImagePreviewCubit manual crop (F15)', () {
    const cropRect = UnitRect(left: 0.1, top: 0.15, right: 0.9, bottom: 0.85);

    test('updateCrop stores the rect in the state', () {
      final cubit = cubitFor(FakeImageRotator());
      addTearDown(cubit.close);

      cubit.updateCrop(cropRect);

      expect(cubit.state, const ImagePreviewReady(0, cropRect: cropRect));
    });

    test(
      'rotateClockwise resets cropRect to full (F15 locked decision #7)',
      () {
        final cubit = cubitFor(FakeImageRotator());
        addTearDown(cubit.close);

        cubit.updateCrop(cropRect);
        cubit.rotateClockwise();

        expect(cubit.state, const ImagePreviewReady(1));
        expect((cubit.state as ImagePreviewReady).cropRect, UnitRect.full);
      },
    );

    test(
      'confirm crops after rotating — quality check sees cropped photo',
      () async {
        const cropped = CapturedPhoto('/tmp/cropped.jpg');
        final fakeCropper = FakeImageCropper(output: cropped);
        final quality = FakeImageQualityService();
        final cubit = cubitFor(
          FakeImageRotator(),
          cropper: fakeCropper,
          quality: quality,
        );
        addTearDown(cubit.close);

        cubit.updateCrop(cropRect);
        await cubit.confirm();

        expect(fakeCropper.cropCount, 1);
        expect(fakeCropper.lastRegion, cropRect);
        // Quality check runs on the final, cropped photo.
        expect(quality.lastPhoto, cropped);
        expect(cubit.state, const ImagePreviewConfirmed(cropped, _goodQuality));
      },
    );

    test('confirm with full cropRect skips the crop entirely', () async {
      final fakeCropper = FakeImageCropper();
      final cubit = cubitFor(FakeImageRotator(), cropper: fakeCropper);
      addTearDown(cubit.close);

      // No updateCrop — rect stays at UnitRect.full.
      await cubit.confirm();

      // The cropper's no-op path runs (region.isFull returns input unchanged)
      // but no new file is produced.
      expect(cubit.state, const ImagePreviewConfirmed(_source, _goodQuality));
    });

    test('a failed crop surfaces the error', () async {
      final cubit = cubitFor(
        FakeImageRotator(),
        cropper: FakeImageCropper(fails: true),
      );
      addTearDown(cubit.close);

      cubit.updateCrop(cropRect);
      await cubit.confirm();

      expect(cubit.state, const ImagePreviewFailed(0));
    });

    test('close after crop deletes source + rotated + cropped files', () async {
      const rotated = CapturedPhoto('/tmp/spun.jpg');
      const cropped = CapturedPhoto('/tmp/cropped.jpg');
      final cleanup = FakeCaptureFileCleanup();
      final cubit = cubitFor(
        FakeImageRotator(output: rotated),
        cropper: FakeImageCropper(output: cropped),
        cleanup: cleanup,
      );

      cubit.rotateClockwise();
      cubit.updateCrop(cropRect);
      await cubit.confirm();
      await cubit.close();

      expect(cleanup.deleteCalls, hasLength(1));
      expect(
        cleanup.deleteCalls.first,
        unorderedEquals([_source.path, rotated.path, cropped.path]),
      );
    });

    test('online handoff includes the cropped file in cleanup paths', () async {
      const cropped = CapturedPhoto('/tmp/cropped.jpg');
      const corrected = CapturedPhoto('/tmp/corrected.jpg');
      final cleanup = FakeCaptureFileCleanup();
      final handoff = ImageAnalysisSessionHolder();
      final cubit = cubitFor(
        FakeImageRotator(),
        cropper: FakeImageCropper(output: cropped),
        cleanup: cleanup,
        connectivity: FakeConnectivityService(),
        perspectiveCorrector: FakePerspectiveCorrector(output: corrected),
        onlineHandoff: handoff,
      );

      cubit.updateCrop(cropRect);
      await cubit.confirm();
      await cubit.proceed();
      await cubit.close();

      // close() skips cleanup — holder owns all temp files.
      expect(cleanup.deleteCalls, isEmpty);
      // The holder received the corrected photo.
      expect(handoff.photo, corrected);
    });
  });

  group(
    'ImagePreviewCubit orphaned temp-file cleanup on close race (F15-T09)',
    () {
      test('close racing an in-flight rotate cleans up the orphaned rotated '
          'file', () async {
        const rotated = CapturedPhoto('/tmp/spun.jpg');
        final gate = Completer<void>();
        final rotator = FakeImageRotator(output: rotated)..gate = gate;
        final cleanup = FakeCaptureFileCleanup();
        final cubit = cubitFor(rotator, cleanup: cleanup);

        cubit.rotateClockwise();
        final confirming = cubit.confirm();
        // Let confirm() reach the awaiting-rotate point.
        await Future<void>.delayed(Duration.zero);

        await cubit.close();

        // The stale rotate now resolves — its file must never reach a
        // terminal state, and must not be left as an orphaned temp file.
        gate.complete();
        await confirming;

        // close()'s own sweep already deleted the source; the orphaned
        // rotated file is a second, separate cleanup call made once the
        // stale await notices isClosed.
        expect(cleanup.deleteCalls, hasLength(2));
        expect(cleanup.deleteCalls[0], [_source.path]);
        expect(cleanup.deleteCalls[1], [rotated.path]);
      });

      test(
        'close racing an in-flight crop cleans up the orphaned cropped file',
        () async {
          const cropped = CapturedPhoto('/tmp/cropped.jpg');
          final gate = Completer<void>();
          final cropper = FakeImageCropper(output: cropped)..gate = gate;
          final cleanup = FakeCaptureFileCleanup();
          final cubit = cubitFor(
            FakeImageRotator(),
            cropper: cropper,
            cleanup: cleanup,
          );

          cubit.updateCrop(
            const UnitRect(left: 0.1, top: 0.15, right: 0.9, bottom: 0.85),
          );
          final confirming = cubit.confirm();
          // Let confirm() clear the (gate-less) rotate and reach the
          // awaiting-crop point.
          await Future<void>.delayed(Duration.zero);

          await cubit.close();

          gate.complete();
          await confirming;

          expect(cleanup.deleteCalls, hasLength(2));
          expect(cleanup.deleteCalls[0], [_source.path]);
          expect(cleanup.deleteCalls[1], [cropped.path]);
        },
      );

      test('close racing an in-flight perspective-correct cleans up the '
          'orphaned corrected file', () async {
        const corrected = CapturedPhoto('/tmp/corrected.jpg');
        final gate = Completer<void>();
        final corrector = FakePerspectiveCorrector(output: corrected)
          ..gate = gate;
        final cleanup = FakeCaptureFileCleanup();
        final cubit = cubitFor(
          FakeImageRotator(),
          cleanup: cleanup,
          perspectiveCorrector: corrector,
        );

        await cubit.confirm();
        final proceeding = cubit.proceed();
        // Let proceed() reach the awaiting-perspective-correct point.
        await Future<void>.delayed(Duration.zero);

        await cubit.close();

        gate.complete();
        await proceeding;

        expect(cleanup.deleteCalls, hasLength(2));
        expect(cleanup.deleteCalls[0], [_source.path]);
        expect(cleanup.deleteCalls[1], [corrected.path]);
      });
    },
  );
}
