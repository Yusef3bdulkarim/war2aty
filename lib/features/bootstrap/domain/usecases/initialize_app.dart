import '../../../../core/error/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/result/result.dart';
import '../entities/bootstrap_stage.dart';

/// A single unit of launch work.
final class BootstrapStep {
  const BootstrapStep(this.stage, this.run, {this.critical = true});

  final BootstrapStage stage;
  final Future<Result<void, AppFailure>> Function() run;

  /// When `true` (default), a failure aborts launch and is surfaced to the
  /// user with a retry. Non-critical steps (housekeeping) are allowed to fail
  /// quietly — the app is still perfectly usable without them.
  final bool critical;
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

      final result = await step.run();

      if (result case Err(:final failure)) {
        if (step.critical) return Err(failure);
        // Non-critical: record the classified code and carry on.
        _logger?.failure(failure);
      }
    }

    return const Ok(null);
  }
}
