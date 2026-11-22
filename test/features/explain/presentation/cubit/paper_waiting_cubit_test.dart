import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/papers/usecases/save_paper.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/core/voice/usecases/speak_fixed_line.dart';
import 'package:war2aty/core/voice/voice_line.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/capture/domain/usecases/cleanup_capture_files.dart';
import 'package:war2aty/features/capture/domain/usecases/downscale_photo.dart';
import 'package:war2aty/features/explain/domain/entities/paper_failure_kind.dart';
import 'package:war2aty/features/explain/domain/services/paper_explain_runner.dart';
import 'package:war2aty/features/explain/domain/usecases/explain_and_save_paper.dart';
import 'package:war2aty/features/explain/domain/usecases/explain_paper.dart';
import 'package:war2aty/features/explain/presentation/cubit/paper_waiting_cubit.dart';
import 'package:war2aty/features/explain/presentation/cubit/paper_waiting_state.dart';

import '../../../../support/fakes.dart';

void main() {
  const photo = CapturedPhoto('/tmp/source.jpg');

  late FakeFixedLinePlayer player;
  late FakeExplainRepository explainRepository;
  late FakePapersRepository papersRepository;
  late PaperExplainRunner runner;
  late List<PaperWaitingState> states;

  setUp(() {
    player = FakeFixedLinePlayer();
    explainRepository = FakeExplainRepository();
    papersRepository = FakePapersRepository();
    runner = PaperExplainRunner(
      ExplainAndSavePaper(
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
      ),
    );
    states = [];
  });

  PaperWaitingCubit buildCubit({CapturedPhoto? startWith = photo}) {
    final cubit = PaperWaitingCubit(
      speakFixedLine: SpeakFixedLine(player),
      runner: runner,
      photo: startWith,
    );
    cubit.stream.listen(states.add);
    return cubit;
  }

  test('plays waiting_reading on open and starts in progress', () async {
    explainRepository.gate = Completer<void>();
    final cubit = buildCubit();
    await pumpEventQueue();

    expect(player.played, [VoiceLine.waitingReading.assetPath]);
    expect(cubit.state, const PaperWaitingInProgress());

    explainRepository.gate!.complete();
    await cubit.close();
  });

  test('starts the runner with the photo it was given', () async {
    final cubit = buildCubit();
    await pumpEventQueue();

    expect(explainRepository.lastPhoto, photo);
    expect(explainRepository.explainCount, 1);

    await cubit.close();
  });

  test('joins a job already running instead of starting a second', () async {
    explainRepository.gate = Completer<void>();
    runner.start(photo);

    final cubit = buildCubit();
    await pumpEventQueue();
    explainRepository.gate!.complete();
    await pumpEventQueue();

    expect(explainRepository.explainCount, 1);
    expect(states, [const PaperWaitingNavigateToPaper('p1')]);

    await cubit.close();
  });

  test('joins a running job without needing a photo', () async {
    explainRepository.gate = Completer<void>();
    runner.start(photo);

    final cubit = buildCubit(startWith: null);
    explainRepository.gate!.complete();
    await pumpEventQueue();

    expect(states, [const PaperWaitingNavigateToPaper('p1')]);

    await cubit.close();
  });

  test('slow success: navigates as soon as the result lands when the line '
      'has already finished', () async {
    explainRepository.gate = Completer<void>();
    final cubit = buildCubit();
    await pumpEventQueue();
    expect(states, isEmpty);

    explainRepository.gate!.complete();
    await pumpEventQueue();

    expect(states, [const PaperWaitingNavigateToPaper('p1')]);

    await cubit.close();
  });

  test(
    'fast success: waits for the line to finish before navigating',
    () async {
      player.playToEndGate = Completer<void>();
      final cubit = buildCubit();
      await pumpEventQueue();

      expect(papersRepository.lastInsertedId, 'p1');
      expect(states, isEmpty);

      player.playToEndGate!.complete();
      await pumpEventQueue();

      expect(states, [const PaperWaitingNavigateToPaper('p1')]);

      await cubit.close();
    },
  );

  test('a line that fails to play never holds the hand-over back', () async {
    player.failure = const AudioPlaybackFailure();
    final cubit = buildCubit();
    await pumpEventQueue();

    expect(states, [const PaperWaitingNavigateToPaper('p1')]);

    await cubit.close();
  });

  test('success hands over without stopping the finished line again', () async {
    final cubit = buildCubit();
    await pumpEventQueue();
    await cubit.close();

    expect(player.stopCount, 0);
  });

  group('failure', () {
    final cases = <(AppFailure, PaperFailureKind)>[
      (const NoInternetFailure(), PaperFailureKind.offline),
      (
        DailyLimitReachedFailure(DateTime(2026, 11, 23)),
        PaperFailureKind.limitReached,
      ),
      (const AnalysisServiceFailure(), PaperFailureKind.serviceProblem),
    ];

    for (final (failure, kind) in cases) {
      test('${failure.runtimeType} emits $kind', () async {
        explainRepository
          ..fails = true
          ..failure = failure;
        final cubit = buildCubit();
        await pumpEventQueue();

        expect(states, [PaperWaitingFailed(kind)]);

        await cubit.close();
      });
    }

    test('stops the waiting line at once, without waiting for it', () async {
      player.playToEndGate = Completer<void>();
      explainRepository.fails = true;
      final cubit = buildCubit();
      await pumpEventQueue();

      expect(states, [
        const PaperWaitingFailed(PaperFailureKind.serviceProblem),
      ]);
      expect(player.stopCount, 1);

      await cubit.close();
      expect(player.stopCount, 1);
    });

    test('no job and no photo fails as a service problem', () async {
      final cubit = buildCubit(startWith: null);
      await pumpEventQueue();

      expect(states, [
        const PaperWaitingFailed(PaperFailureKind.serviceProblem),
      ]);
      expect(explainRepository.explainCount, 0);

      await cubit.close();
    });
  });

  group('leaving mid-flight', () {
    test('stops the line and the job still saves the paper', () async {
      explainRepository.gate = Completer<void>();
      final cubit = buildCubit();
      await pumpEventQueue();

      await cubit.close();

      expect(player.stopCount, 1);
      expect(runner.isRunning, isTrue);

      explainRepository.gate!.complete();
      await pumpEventQueue();

      expect(papersRepository.lastInsertedId, 'p1');
      expect(runner.isRunning, isFalse);
      expect(states, isEmpty);
    });

    test('leaving while the line is still playing emits nothing', () async {
      player.playToEndGate = Completer<void>();
      final cubit = buildCubit();
      await pumpEventQueue();

      await cubit.close();
      await pumpEventQueue();

      expect(papersRepository.lastInsertedId, 'p1');
      expect(states, isEmpty);
    });
  });
}

final class _SilentLogger implements AppLogger {
  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) {}

  @override
  void event(LogEvent e) {}
}
