import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/bootstrap/domain/entities/bootstrap_stage.dart';
import 'package:war2aty/features/bootstrap/domain/usecases/finish_launch.dart';
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

  // F28-T02 deleted the 'splash entrance hold' group with the feature it
  // covered: the launch no longer withholds success until a splash animation
  // reports itself finished, so there is no hold, no escape-hatch timeout and
  // no `splashEntranceFinished`. The remaining assertion worth keeping — that
  // `start` reaches `BootstrapSuccess` without waiting for anything — is made
  // by the retry test above. F28-T07 decides what, if anything, paces the
  // launch, and brings its own tests.

  group('deferred housekeeping (F27-P01)', () {
    test('does not run it as part of the launch', () async {
      var ran = false;
      final cubit = BootstrapCubit(
        InitializeApp(const []),
        finishLaunch: FinishLaunch([
          BootstrapStep(BootstrapStage.usage, () async {
            ran = true;
            return const Ok(null);
          }, critical: false),
        ]),
      );
      addTearDown(cubit.close);

      await cubit.start();

      expect(
        ran,
        isFalse,
        reason: 'it would stutter the splash it was moved out of',
      );

      // Only once the splash has faded off the first screen.
      await cubit.finishLaunch();
      expect(ran, isTrue);
    });

    test('has nothing to run when none is configured', () async {
      final cubit = BootstrapCubit(InitializeApp(const []));
      addTearDown(cubit.close);

      await expectLater(cubit.finishLaunch(), completes);
    });
  });
}
