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
}
