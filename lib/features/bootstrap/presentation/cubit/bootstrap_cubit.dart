import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/initialize_app.dart';
import 'bootstrap_state.dart';

/// Drives the launch sequence and exposes it to the splash screen.
///
/// Depends on the [InitializeApp] use case only — no repositories, no
/// BuildContext.
final class BootstrapCubit extends Cubit<BootstrapState> {
  BootstrapCubit(this._initializeApp) : super(const BootstrapInitial());

  final InitializeApp _initializeApp;

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
}
