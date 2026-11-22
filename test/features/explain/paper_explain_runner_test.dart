import 'dart:async';

import 'package:fake_async/fake_async.dart';
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
import 'package:war2aty/features/explain/domain/services/paper_explain_runner.dart';
import 'package:war2aty/features/explain/domain/usecases/explain_and_save_paper.dart';
import 'package:war2aty/features/explain/domain/usecases/explain_paper.dart';

import '../../support/fakes.dart';

void main() {
  late FakeExplainRepository explainRepository;
  late FakePapersRepository papersRepository;
  late PaperExplainRunner runner;

  const photo = CapturedPhoto('/tmp/source.jpg');

  setUp(() {
    explainRepository = FakeExplainRepository();
    papersRepository = FakePapersRepository();

    final explainAndSave = ExplainAndSavePaper(
      DownscalePhoto(FakeImageDownscaler(output: photo)),
      ExplainPaper(explainRepository),
      SavePaper(
        papersRepository,
        FakePaperImageStore(),
        idGenerator: () => 'p1',
      ),
      SyncDailyUsage(FakeUsageRepository()),
      CleanupCaptureFiles(FakeCaptureFileCleanup()),
      _SilentLogger(),
    );
    runner = PaperExplainRunner(explainAndSave);
  });

  test('emits the job\'s single result on the returned stream', () {
    fakeAsync((async) {
      final results = <Result<String, AppFailure>>[];
      runner.start(photo).listen(results.add);

      async.flushMicrotasks();

      expect(results, [const Ok<String, AppFailure>('p1')]);
      expect(runner.isRunning, isFalse);
    });
  });

  test('is a broadcast stream every listener can join', () {
    fakeAsync((async) {
      final first = <Result<String, AppFailure>>[];
      final second = <Result<String, AppFailure>>[];
      final stream = runner.start(photo);
      stream.listen(first.add);
      stream.listen(second.add);

      async.flushMicrotasks();

      expect(first, [const Ok<String, AppFailure>('p1')]);
      expect(second, [const Ok<String, AppFailure>('p1')]);
    });
  });

  test('passes a failure result through the stream untouched', () {
    fakeAsync((async) {
      explainRepository.fails = true;
      final results = <Result<String, AppFailure>>[];
      runner.start(photo).listen(results.add);

      async.flushMicrotasks();

      expect(results, [
        const Err<String, AppFailure>(AnalysisServiceFailure()),
      ]);
    });
  });

  test('refuses a second start while a job is running', () {
    fakeAsync((async) {
      explainRepository.gate = Completer<void>();
      runner.start(photo);

      expect(runner.isRunning, isTrue);
      expect(() => runner.start(photo), throwsStateError);

      explainRepository.gate!.complete();
      async.flushMicrotasks();

      expect(runner.isRunning, isFalse);
    });
  });

  test('allows a new start once the previous job has finished', () {
    fakeAsync((async) {
      runner.start(photo);
      async.flushMicrotasks();
      expect(runner.isRunning, isFalse);

      expect(() => runner.start(photo), returnsNormally);
    });
  });

  test('a listener reacting to the result can start a new job at once', () {
    fakeAsync((async) {
      final results = <Result<String, AppFailure>>[];
      runner.start(photo).listen((result) {
        results.add(result);
        runner.start(photo);
      });

      async.flushMicrotasks();

      expect(results, [const Ok<String, AppFailure>('p1')]);
      expect(explainRepository.explainCount, 2);
    });
  });

  test('join returns null when no job is running', () {
    expect(runner.join(), isNull);
  });

  test('join shares the running job\'s result without a second job', () {
    fakeAsync((async) {
      explainRepository.gate = Completer<void>();
      final started = <Result<String, AppFailure>>[];
      final joined = <Result<String, AppFailure>>[];
      runner.start(photo).listen(started.add);
      runner.join()!.listen(joined.add);

      explainRepository.gate!.complete();
      async.flushMicrotasks();

      expect(started, [const Ok<String, AppFailure>('p1')]);
      expect(joined, [const Ok<String, AppFailure>('p1')]);
      expect(explainRepository.explainCount, 1);
      expect(runner.join(), isNull);
    });
  });

  test('cancelling a listener never cancels the job', () {
    fakeAsync((async) {
      explainRepository.gate = Completer<void>();
      final sub = runner.start(photo).listen((_) {});
      unawaited(sub.cancel());

      explainRepository.gate!.complete();
      async.flushMicrotasks();

      expect(papersRepository.lastInsertedId, 'p1');
      expect(runner.isRunning, isFalse);
    });
  });
}

final class _SilentLogger implements AppLogger {
  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) {}

  @override
  void event(LogEvent e) {}
}
