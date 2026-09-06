import 'dart:async';

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

  group('launch always terminates', () {
    // Both of these produced a splash screen that spun forever, with no error
    // and no retry — the worst failure mode the app has, because there is
    // nothing the user can do but force-quit.

    test('a step that never completes times out instead of hanging', () async {
      final initialize = InitializeApp([
        BootstrapStep(
          BootstrapStage.session,
          // A network call that never resolves. Since F06-T14 the session step
          // really does perform one.
          () => Completer<Result<void, AppFailure>>().future,
          timeout: const Duration(milliseconds: 50),
        ),
      ]);

      final result = await initialize();

      expect(result, isA<Err<void, AppFailure>>());
      expect((result as Err).failure, isA<RequestTimeoutFailure>());
    });

    test(
      'a step that throws becomes a failure, not an escaped exception',
      () async {
        // `run` is a closure that resolves dependencies: an unregistered service
        // or a client that failed to initialize throws straight out of it.
        final initialize = InitializeApp([
          BootstrapStep(
            BootstrapStage.session,
            () async =>
                throw StateError('Supabase.instance was not initialized'),
          ),
        ]);

        final result = await initialize();

        expect((result as Err).failure, isA<LaunchFailure>());
      },
    );

    test('a throw in a non-critical step does not abort launch', () async {
      final ran = <BootstrapStage>[];
      final initialize = InitializeApp([
        BootstrapStep(
          BootstrapStage.usage,
          () async => throw StateError('boom'),
          critical: false,
        ),
        step(BootstrapStage.reminders, ran),
      ]);

      expect(await initialize(), const Ok<void, AppFailure>(null));
      expect(ran, [BootstrapStage.reminders]);
    });

    test('a timeout in a non-critical step does not abort launch', () async {
      // Usage sync talks to get-usage now; a slow backend must not stop the
      // user reaching a screen that works perfectly well from cache.
      final ran = <BootstrapStage>[];
      final initialize = InitializeApp([
        BootstrapStep(
          BootstrapStage.usage,
          () => Completer<Result<void, AppFailure>>().future,
          critical: false,
          timeout: const Duration(milliseconds: 50),
        ),
        step(BootstrapStage.reminders, ran),
      ]);

      expect(await initialize(), const Ok<void, AppFailure>(null));
      expect(ran, [BootstrapStage.reminders]);
    });

    test('every step is bounded unless a caller opts out explicitly', () {
      const bounded = BootstrapStep(BootstrapStage.session, _never);
      expect(bounded.timeout, BootstrapStep.defaultTimeout);

      const unbounded = BootstrapStep(
        BootstrapStage.session,
        _never,
        timeout: null,
      );
      expect(unbounded.timeout, isNull);
    });
  });
}

Future<Result<void, AppFailure>> _never() =>
    Completer<Result<void, AppFailure>>().future;
