import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/bootstrap/domain/entities/bootstrap_stage.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/initialize_app.dart';

void main() {
  /// Builds a step that records it ran, then returns [result].
  BootstrapStep step(
    BootstrapStage stage,
    List<BootstrapStage> ran, {
    Result<void, AppFailure> result = const Ok(null),
    bool critical = true,
  }) {
    return BootstrapStep(stage, () async {
      ran.add(stage);
      return result;
    }, critical: critical);
  }

  test('runs every step in the given order', () async {
    final ran = <BootstrapStage>[];
    final initialize = InitializeApp([
      step(BootstrapStage.session, ran),
      step(BootstrapStage.config, ran),
      step(BootstrapStage.cleanup, ran),
    ]);

    final result = await initialize();

    expect(result, const Ok<void, AppFailure>(null));
    expect(ran, [
      BootstrapStage.session,
      BootstrapStage.config,
      BootstrapStage.cleanup,
    ]);
  });

  test('reports each stage as it starts', () async {
    final ran = <BootstrapStage>[];
    final seen = <BootstrapStage>[];
    final initialize = InitializeApp([
      step(BootstrapStage.session, ran),
      step(BootstrapStage.usage, ran),
    ]);

    await initialize(onStage: seen.add);

    expect(seen, [BootstrapStage.session, BootstrapStage.usage]);
  });

  test('exposes the current stage', () async {
    final ran = <BootstrapStage>[];
    final initialize = InitializeApp([step(BootstrapStage.config, ran)]);

    expect(initialize.currentStage, isNull);
    await initialize();
    expect(initialize.currentStage, BootstrapStage.config);
  });

  test('a critical failure aborts and skips the remaining steps', () async {
    final ran = <BootstrapStage>[];
    final initialize = InitializeApp([
      step(BootstrapStage.session, ran, result: const Err(NoInternetFailure())),
      step(BootstrapStage.config, ran),
    ]);

    final result = await initialize();

    expect(result, const Err<void, AppFailure>(NoInternetFailure()));
    expect(ran, [BootstrapStage.session], reason: 'must stop at the failure');
  });

  test('a non-critical failure does not abort the launch', () async {
    final ran = <BootstrapStage>[];
    final initialize = InitializeApp([
      step(
        BootstrapStage.cleanup,
        ran,
        result: const Err(FileStorageFailure()),
        critical: false,
      ),
      step(BootstrapStage.usage, ran),
    ]);

    final result = await initialize();

    expect(result, const Ok<void, AppFailure>(null));
    expect(ran, [BootstrapStage.cleanup, BootstrapStage.usage]);
  });

  test('an empty sequence succeeds', () async {
    expect(await InitializeApp(const [])(), const Ok<void, AppFailure>(null));
  });
}
