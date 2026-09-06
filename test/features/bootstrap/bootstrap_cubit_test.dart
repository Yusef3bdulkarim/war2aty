import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/bootstrap/domain/entities/bootstrap_stage.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/initialize_app.dart';
import 'package:war2aty/features/bootstrap/presentation/cubit/bootstrap_cubit.dart';
import 'package:war2aty/features/bootstrap/presentation/cubit/bootstrap_state.dart';

void main() {
  BootstrapStep okStep(BootstrapStage stage) =>
      BootstrapStep(stage, () async => const Ok(null));

  BootstrapStep failingStep(BootstrapStage stage, AppFailure failure) =>
      BootstrapStep(stage, () async => Err(failure));

  test('starts in the initial state', () {
    final cubit = BootstrapCubit(InitializeApp(const []));
    addTearDown(cubit.close);

    expect(cubit.state, const BootstrapInitial());
  });

  test('emits in-progress per stage, then success', () async {
    final cubit = BootstrapCubit(
      InitializeApp([
        okStep(BootstrapStage.session),
        okStep(BootstrapStage.config),
      ]),
    );
    addTearDown(cubit.close);

    // Set the expectation up before starting, then await it — stream events
    // are delivered asynchronously.
    final expectation = expectLater(
      cubit.stream,
      emitsInOrder(const [
        BootstrapInProgress(),
        BootstrapInProgress(BootstrapStage.session),
        BootstrapInProgress(BootstrapStage.config),
        BootstrapSuccess(),
      ]),
    );

    await cubit.start();
    await expectation;
  });

  test('emits failure when a critical step fails', () async {
    final cubit = BootstrapCubit(
      InitializeApp([
        failingStep(BootstrapStage.session, const NoInternetFailure()),
      ]),
    );
    addTearDown(cubit.close);

    await cubit.start();

    expect(cubit.state, const BootstrapFailure(NoInternetFailure()));
  });

  test('retrying after a failure can succeed', () async {
    var shouldFail = true;
    final cubit = BootstrapCubit(
      InitializeApp([
        BootstrapStep(BootstrapStage.session, () async {
          if (shouldFail) return const Err(NoInternetFailure());
          return const Ok(null);
        }),
      ]),
    );
    addTearDown(cubit.close);

    await cubit.start();
    expect(cubit.state, const BootstrapFailure(NoInternetFailure()));

    shouldFail = false;
    await cubit.start();
    expect(cubit.state, const BootstrapSuccess());
  });

  group('splash entrance hold', () {
    test(
      'withholds success until the splash reports its entrance done',
      () async {
        final cubit = BootstrapCubit(
          InitializeApp(const []),
          splashEntranceTimeout: const Duration(seconds: 30),
        );
        addTearDown(cubit.close);

        final launch = cubit.start();
        // The sequence is empty, so it is only the hold keeping this pending.
        await pumpEventQueue();
        expect(cubit.state, isA<BootstrapInProgress>());

        cubit.splashEntranceFinished();
        await launch;
        expect(cubit.state, const BootstrapSuccess());
      },
    );

    test('hands off anyway if the entrance never reports', () async {
      final cubit = BootstrapCubit(
        InitializeApp(const []),
        splashEntranceTimeout: const Duration(milliseconds: 40),
      );
      addTearDown(cubit.close);

      // Nothing ever calls splashEntranceFinished: the timeout is the only way
      // out, and without it the user would be stranded on the splash.
      await cubit.start();
      expect(cubit.state, const BootstrapSuccess());
    });

    test('a failure is not held behind the entrance', () async {
      final cubit = BootstrapCubit(
        InitializeApp([
          failingStep(BootstrapStage.session, const NoInternetFailure()),
        ]),
        // Long enough that a held failure would hang the test rather than pass.
        splashEntranceTimeout: const Duration(seconds: 30),
      );
      addTearDown(cubit.close);

      await cubit.start();
      expect(cubit.state, const BootstrapFailure(NoInternetFailure()));
    });

    test('does not wait at all when no timeout is configured', () async {
      final cubit = BootstrapCubit(InitializeApp(const []));
      addTearDown(cubit.close);

      await cubit.start();
      expect(cubit.state, const BootstrapSuccess());
    });
  });
}
