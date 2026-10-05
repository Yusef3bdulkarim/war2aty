import '../../../../core/logging/app_logger.dart';
import '../../../../core/result/result.dart';
import 'initialize_app.dart';

/// Runs the launch work the user never waits for (F27-P01).
///
/// Housekeeping — clearing stale temporary files, re-aligning scheduled
/// reminders, syncing the usage counter — does not gate the first screen, and
/// on a mid-range phone its platform calls cost enough to drop frames. Run
/// during the splash it stuttered the animation; run here, after the splash has
/// faded off a first screen that is already still, a long frame costs nothing
/// anyone can see.
///
/// Every step is non-critical by definition: a failure is logged and the app
/// carries on. Never throws, so the caller can fire it and forget it.
final class FinishLaunch {
  FinishLaunch(this._steps, {AppLogger? logger}) : _logger = logger;

  final List<BootstrapStep> _steps;
  final AppLogger? _logger;

  bool _done = false;

  /// Runs every step in order, once per app start. Later calls do nothing, so
  /// a second reveal (a retried launch) cannot run the work twice.
  Future<void> call() async {
    if (_done) return;
    _done = true;

    for (final step in _steps) {
      final result = await step.runGuarded();
      // Classified code only — the step's own data never reaches a log (§7).
      if (result case Err(:final failure)) _logger?.failure(failure);
    }
  }
}
