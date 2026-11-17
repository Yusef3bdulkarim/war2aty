import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/papers/usecases/save_paper.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/downscale_photo.dart';
import 'package:war2aty/features/explain/domain/usecases/explain_and_save_paper.dart';
import 'package:war2aty/features/explain/domain/usecases/explain_paper.dart';

import '../../support/fakes.dart';

void main() {
  late FakeImageDownscaler downscaler;
  late FakeExplainRepository explainRepository;
  late FakePapersRepository papersRepository;
  late FakePaperImageStore images;
  late FakeUsageRepository usageRepository;
  late FakeCaptureFileCleanup cleanup;
  late _RecordingLogger logger;
  late ExplainAndSavePaper explainAndSave;

  const source = CapturedPhoto('/tmp/source.jpg');
  const shrunk = CapturedPhoto('/tmp/shrunk.jpg');
  final fixedNow = DateTime(2026, 11, 18, 10);

  setUp(() {
    downscaler = FakeImageDownscaler(output: shrunk);
    explainRepository = FakeExplainRepository();
    papersRepository = FakePapersRepository();
    images = FakePaperImageStore();
    usageRepository = FakeUsageRepository();
    cleanup = FakeCaptureFileCleanup();
    logger = _RecordingLogger();

    explainAndSave = ExplainAndSavePaper(
      DownscalePhoto(downscaler),
      ExplainPaper(explainRepository),
      SavePaper(papersRepository, images, idGenerator: () => 'p1'),
      SyncDailyUsage(usageRepository),
      CleanupCaptureFiles(cleanup),
      logger,
      clock: () => fixedNow,
    );
  });

  test('downscales, explains, saves and reports the new paper\'s id', () async {
    final result = await explainAndSave(source);

    expect(result, const Ok<String, AppFailure>('p1'));
    expect(downscaler.lastPhoto, source);
    expect(explainRepository.lastPhoto, shrunk);
    expect(images.stored['p1'], shrunk.path);
  });

  test('saves with photographedAt set to now', () async {
    await explainAndSave(source);

    expect(papersRepository.lastPhotographedAt, fixedNow);
  });

  test('saves the downscaled photo\'s path, not the original', () async {
    await explainAndSave(source);

    expect(papersRepository.lastEncryptedImagePath, isNotNull);
    expect(images.stored['p1'], shrunk.path);
  });

  test('syncs the daily usage quota best-effort after saving', () async {
    final result = await explainAndSave(source);

    expect(result.isOk, isTrue);
    expect(usageRepository.syncCallCount, 1);
  });

  test(
    'still reports the saved paper when the best-effort usage sync fails',
    () async {
      usageRepository.emitFailure();

      final result = await explainAndSave(source);

      expect(result, const Ok<String, AppFailure>('p1'));
    },
  );

  test('deletes the original and downscaled temp files on success', () async {
    await explainAndSave(source);

    expect(cleanup.deleteCalls, [
      unorderedEquals([source.path, shrunk.path]),
    ]);
  });

  test('deletes only the original file when downscaling was a no-op', () async {
    final noOpExplainAndSave = ExplainAndSavePaper(
      DownscalePhoto(FakeImageDownscaler(output: source)),
      ExplainPaper(explainRepository),
      SavePaper(papersRepository, images, idGenerator: () => 'p1'),
      SyncDailyUsage(usageRepository),
      CleanupCaptureFiles(cleanup),
      logger,
      clock: () => fixedNow,
    );

    await noOpExplainAndSave(source);

    expect(cleanup.deleteCalls, [
      [source.path],
    ]);
  });

  test(
    'passes a downscale failure through untouched, logged at its origin',
    () async {
      downscaler.fails = true;

      final result = await explainAndSave(source);

      expect(result, const Err<String, AppFailure>(ImageProcessingFailure()));
      expect(explainRepository.explainCount, 0);
      expect(papersRepository.lastInsertedId, isNull);
      expect(cleanup.deleteCalls, isEmpty);
      expect(logger.failures, [const ImageProcessingFailure()]);
      expect(logger.stages, [LogStage.capture]);
    },
  );

  test('passes an explain failure through untouched, without logging it again '
      '(the explain repository already logs its own failures)', () async {
    explainRepository.fails = true;

    final result = await explainAndSave(source);

    expect(result, const Err<String, AppFailure>(AnalysisServiceFailure()));
    expect(papersRepository.lastInsertedId, isNull);
    expect(cleanup.deleteCalls, isEmpty);
    expect(logger.failures, isEmpty);
  });

  test(
    'passes a DailyLimitReachedFailure from explain through untouched',
    () async {
      final resetAt = DateTime(2026, 11, 18, 0, 1);
      explainRepository.fails = true;
      explainRepository.failure = DailyLimitReachedFailure(resetAt);

      final result = await explainAndSave(source);

      expect(
        result,
        Err<String, AppFailure>(DailyLimitReachedFailure(resetAt)),
      );
      expect(cleanup.deleteCalls, isEmpty);
    },
  );

  test('passes a NoInternetFailure from explain through untouched', () async {
    explainRepository.fails = true;
    explainRepository.failure = const NoInternetFailure();

    final result = await explainAndSave(source);

    expect(result, const Err<String, AppFailure>(NoInternetFailure()));
    expect(papersRepository.lastInsertedId, isNull);
    expect(cleanup.deleteCalls, isEmpty);
  });

  test(
    'passes a RequestTimeoutFailure from explain through untouched',
    () async {
      explainRepository.fails = true;
      explainRepository.failure = const RequestTimeoutFailure();

      final result = await explainAndSave(source);

      expect(result, const Err<String, AppFailure>(RequestTimeoutFailure()));
      expect(papersRepository.lastInsertedId, isNull);
      expect(cleanup.deleteCalls, isEmpty);
    },
  );

  test(
    'reports (returns and logs) a database failure after a successful explain',
    () async {
      papersRepository.insertOutcome = const Err(LocalDatabaseFailure());

      final result = await explainAndSave(source);

      expect(result, const Err<String, AppFailure>(LocalDatabaseFailure()));
      expect(logger.failures, [const LocalDatabaseFailure()]);
      expect(logger.stages, [LogStage.save]);
    },
  );

  test('keeps the temp files when the save fails, for a retry', () async {
    papersRepository.insertOutcome = const Err(LocalDatabaseFailure());

    await explainAndSave(source);

    expect(cleanup.deleteCalls, isEmpty);
  });
}

final class _RecordingLogger implements AppLogger {
  final List<AppFailure> failures = [];
  final List<LogStage?> stages = [];

  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) {
    failures.add(failure);
    stages.add(stage);
  }

  @override
  void event(LogEvent e) {}
}
