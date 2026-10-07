import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/finish_launch.dart';
import '../../domain/usecases/initialize_app.dart';
import 'bootstrap_state.dart';

/// Drives the launch sequence and exposes it to the launch screen.
///
/// Depends on use cases only — no repositories, no BuildContext.
final class BootstrapCubit extends Cubit<BootstrapState> {
  BootstrapCubit(this._initializeApp, {FinishLaunch? finishLaunch})
    : _finishLaunch = finishLaunch,
      super(const BootstrapInitial());

  final InitializeApp _initializeApp;

  /// The housekeeping that runs once the app is up (F27-P01). `null` where
  /// there is none — tests, and any host that never calls [finishLaunch].
  final FinishLaunch? _finishLaunch;

  /// Runs (or re-runs, on retry) the launch sequence.
  Future<void> start() async {
    if (isClosed) return;
    emit(const BootstrapInProgress());

    final result = await _initializeApp(
      onStage: (stage) {
        if (!isClosed) emit(BootstrapInProgress(stage));
      },
    );

    if (isClosed) return;

    emit(
      result.when(
        ok: (_) => const BootstrapSuccess(),
        err: BootstrapFailure.new,
      ),
    );
  }

  /// Called once the app is up, to run the launch work that was held back so it
  /// could not stutter the launch animation (F27-P01).
  ///
  /// Emits nothing: every deferred step is non-critical, the user is already
  /// on the first screen, and a failure there is logged, not shown.
  Future<void> finishLaunch() async => _finishLaunch?.call();
}
