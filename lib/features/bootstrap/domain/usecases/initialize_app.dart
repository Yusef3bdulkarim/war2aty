import 'dart:async';

import '../../../../core/error/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/result/result.dart';
import '../entities/bootstrap_stage.dart';

/// A single unit of launch work.
final class BootstrapStep {
  const BootstrapStep(
    this.stage,
    this.run, {
    this.critical = true,
    this.timeout = defaultTimeout,
  });

  /// How long a step may take before launch gives up on it.
  ///
  /// Every step must have one. Since F06-T14 the session step performs real
  /// network I/O, and a request that never resolves would leave the splash
  /// screen spinning forever — no error, no retry, nothing the user can do but
  /// force-quit. A bounded wait turns that into the error screen F01-T06
  /// already provides.
  static const Duration defaultTimeout = Duration(seconds: 15);

  final BootstrapStage stage;
  final Future<Result<void, AppFailure>> Function() run;

  /// When `true` (default), a failure aborts launch and is surfaced to the
  /// user with a retry. Non-critical steps (housekeeping) are allowed to fail
  /// quietly — the app is still perfectly usable without them.
  final bool critical;

  /// `null` disables the bound. Only for steps that cannot block.
  final Duration? timeout;
}

/// Runs the ordered launch sequence and reports progress.
///
/// Returns `Ok(null)` once every step has been attempted, or `Err` with the
/// first *critical* failure. Never throws.
final class InitializeApp {
  InitializeApp(this._steps, {AppLogger? logger}) : _logger = logger;

  final List<BootstrapStep> _steps;
  final AppLogger? _logger;

  BootstrapStage? _currentStage;

  /// The stage currently running (or the last one reached).
  BootstrapStage? get currentStage => _currentStage;

  Future<Result<void, AppFailure>> call({
    void Function(BootstrapStage stage)? onStage,
  }) async {
    for (final step in _steps) {
      _currentStage = step.stage;
      onStage?.call(step.stage);

      final result = await _run(step);

      if (result case Err(:final failure)) {
        // Record the classified code either way. A critical failure is the one
        // that ends launch on an error screen whose copy is deliberately
        // generic, so without this line the only signal a developer gets is a
        // dead splash — which failure, and at which stage, is unknowable.
        _logger?.failure(failure);
        if (step.critical) return Err(failure);
      }
    }

    return const Ok(null);
  }

  /// Runs one step under its timeout, and survives a step that misbehaves.
  ///
  /// [BootstrapStep.run] is *supposed* to return a `Result` rather than throw,
  /// but it is a closure resolving dependencies — an unregistered service or a
  /// client that failed to initialize throws out of it. Left uncaught, that
  /// escapes through `BootstrapCubit.start()` and the splash screen never
  /// changes state: the user sees a spinner forever, with no error and no
  /// retry. Catching here is what makes this class's "never throws" contract
  /// true rather than aspirational.
  Future<Result<void, AppFailure>> _run(BootstrapStep step) async {
    final timeout = step.timeout;

    try {
      final pending = step.run();
      return await (timeout == null ? pending : pending.timeout(timeout));
    } on TimeoutException {
      return const Err(RequestTimeoutFailure());
    } on Object {
      // The caught object is deliberately dropped: it can quote whatever the
      // step was working on, and launch runs before any redaction (§7, §51).
      return const Err(LaunchFailure());
    }
  }
}
