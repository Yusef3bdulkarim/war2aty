import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/initialize_app.dart';
import 'bootstrap_state.dart';

/// Drives the launch sequence and exposes it to the splash screen.
///
/// Depends on the [InitializeApp] use case only — no repositories, no
/// BuildContext.
final class BootstrapCubit extends Cubit<BootstrapState> {
  BootstrapCubit(this._initializeApp, {this.splashEntranceTimeout})
    : super(const BootstrapInitial());

  final InitializeApp _initializeApp;

  /// How long a successful launch will wait for the splash to report that its
  /// entrance animation has played out, before handing off anyway.
  ///
  /// `null` (the default) hands off as soon as initialization finishes — what
  /// tests and any host without a splash want. It is only a safety net: the
  /// hand-off normally happens the moment [splashEntranceFinished] is called.
  final Duration? splashEntranceTimeout;

  Completer<void>? _splashEntrance;
  bool _splashEntranceDone = false;

  /// Runs (or re-runs, on retry) the launch sequence.
  Future<void> start() async {
    if (isClosed) return;
    emit(const BootstrapInProgress());

    // Nothing to wait for if the entrance has already played — under reduced
    // motion it reports before this even runs, and on a retry the user has
    // watched it once already.
    final entrance = splashEntranceTimeout == null || _splashEntranceDone
        ? null
        : (_splashEntrance = Completer<void>());

    final result = await _initializeApp(
      onStage: (stage) {
        if (!isClosed) emit(BootstrapInProgress(stage));
      },
    );

    if (isClosed) return;

    final next = result.when(
      ok: (_) => const BootstrapSuccess(),
      err: BootstrapFailure.new,
    );

    // A failure needs the user's attention now; only success waits.
    if (next is BootstrapSuccess && entrance != null) {
      await entrance.future.timeout(splashEntranceTimeout!, onTimeout: () {});
      if (isClosed) return;
    }

    emit(next);
  }

  /// Called by the splash once its entrance animation has played out.
  ///
  /// The wait is driven from here rather than by a timer started in [start]
  /// because the two clocks do not line up: on a cold start the first frame can
  /// land seconds after launch, and a timer started here would run out that
  /// much sooner than the animation, cutting it off mid-flight.
  /// Safe to call before [start], after it, or more than once.
  void splashEntranceFinished() {
    _splashEntranceDone = true;
    final entrance = _splashEntrance;
    if (entrance != null && !entrance.isCompleted) entrance.complete();
  }
}
