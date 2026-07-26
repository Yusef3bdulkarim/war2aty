import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/entities/image_quality_result.dart';
import 'package:war2aty/features/capture/domain/usecases/assess_image_quality.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/create_analysis_session.dart';
import 'package:war2aty/features/capture/domain/usecases/rotate_image.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_cubit.dart';
import 'package:war2aty/features/capture/presentation/cubit/image_preview_state.dart';

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
}) {
  final q = quality ?? FakeImageQualityService();
  final s = storage ?? FakeAnalysisSessionStorage();
  final c = cleanup ?? FakeCaptureFileCleanup();
  return ImagePreviewCubit(
    source: _source,
    rotate: RotateImage(rotator),
    assessQuality: AssessImageQuality(q),
    createSession: CreateAnalysisSession(s),
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
  });
}
