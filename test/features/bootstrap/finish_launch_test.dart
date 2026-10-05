import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/log_event.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/bootstrap/domain/entities/bootstrap_stage.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/finish_launch.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/initialize_app.dart';

void main() {
  late List<BootstrapStage> ran;
  late _RecordingLogger logger;

  setUp(() {
    ran = [];
    logger = _RecordingLogger();
  });

  BootstrapStep step(
    BootstrapStage stage, {
    Result<void, AppFailure> result = const Ok(null),
  }) => BootstrapStep(stage, () async {
    ran.add(stage);
    return result;
  }, critical: false);

  test('runs every step, in order', () async {
    await FinishLaunch([
      step(BootstrapStage.cleanup),
      step(BootstrapStage.reminders),
      step(BootstrapStage.usage),
    ])();

    expect(ran, [
      BootstrapStage.cleanup,
      BootstrapStage.reminders,
      BootstrapStage.usage,
    ]);
  });

  test('carries on past a step that fails, and logs it', () async {
    await FinishLaunch([
      step(BootstrapStage.cleanup, result: const Err(LocalDatabaseFailure())),
      step(BootstrapStage.usage),
    ], logger: logger)();

    expect(
      ran,
      [BootstrapStage.cleanup, BootstrapStage.usage],
      reason: 'housekeeping is non-critical: one failure cannot stop the rest',
    );
    expect(logger.failures, [const LocalDatabaseFailure()]);
  });

  test('survives a step that throws', () async {
    await FinishLaunch([
      BootstrapStep(
        BootstrapStage.cleanup,
        () async => throw StateError('unregistered service'),
        critical: false,
      ),
      step(BootstrapStage.usage),
    ], logger: logger)();

    expect(ran, [BootstrapStage.usage]);
    expect(logger.failures, [const LaunchFailure()]);
  });

  test('gives up on a step that never finishes', () async {
    await FinishLaunch([
      BootstrapStep(
        BootstrapStage.cleanup,
        () => Completer<Result<void, AppFailure>>().future,
        critical: false,
        timeout: const Duration(milliseconds: 10),
      ),
      step(BootstrapStage.usage),
    ], logger: logger)();

    expect(ran, [
      BootstrapStage.usage,
    ], reason: 'a hung step must not strand the rest of the housekeeping');
    expect(logger.failures, [const RequestTimeoutFailure()]);
  });

  test('runs once, however often it is called', () async {
    // The reveal fires once per launch, but a retried launch reveals again —
    // the usage sync and the reminder reconcile must not run twice.
    final finish = FinishLaunch([step(BootstrapStage.usage)]);

    await finish();
    await finish();

    expect(ran, [BootstrapStage.usage]);
  });
}

final class _RecordingLogger implements AppLogger {
  final List<AppFailure> failures = [];

  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) =>
      failures.add(failure);

  @override
  void event(LogEvent e) {}
}
