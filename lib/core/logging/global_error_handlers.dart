import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'log_event.dart';

/// F27-T12 / H1 · Routes the two errors nobody caught into the logger.
///
/// Flutter has exactly two places an unhandled error can surface, and until
/// this ran, both ended at `print`: in a release build that goes nowhere, so a
/// crash in the field left no trace at all.
///
/// - `FlutterError.onError` — synchronous framework and widget-tree errors
///   (a failed build, a bad layout, an assertion).
/// - `PlatformDispatcher.instance.onError` — asynchronous errors with no
///   `catch` above them, which is the modern replacement for wrapping
///   `runApp` in `runZonedGuarded`.
///
/// Both are chained, never replaced: the previous handler still runs, so the
/// debug console keeps its red screen and its stack trace. Only a code is
/// logged — see [LogCrashKind] for why the exception and its stack stay on the
/// device.
///
/// Returns a function that puts both handlers back, so a test can install this
/// without leaking into the next one.
VoidCallback installGlobalErrorHandlers(AppLogger logger) {
  final previousFlutterOnError = FlutterError.onError;
  final previousPlatformOnError = PlatformDispatcher.instance.onError;

  FlutterError.onError = (details) {
    _report(logger, LogCrashKind.flutterFramework);
    previousFlutterOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _report(logger, LogCrashKind.platformDispatcher);
    // `false` = not handled, so the framework still prints it in debug and
    // the process behaves exactly as it did before. Reporting an error is
    // not the same as recovering from one, and claiming otherwise here would
    // silently swallow real defects.
    return previousPlatformOnError?.call(error, stack) ?? false;
  };

  return () {
    FlutterError.onError = previousFlutterOnError;
    PlatformDispatcher.instance.onError = previousPlatformOnError;
  };
}

/// Logging must never be the thing that brings the app down, and this is the
/// one call site where that is more than a platitude: a throw inside
/// `FlutterError.onError` re-enters the same handler.
void _report(AppLogger logger, LogCrashKind kind) {
  try {
    logger.event(LogEvent(crash: kind));
  } on Object {
    // Nothing to do and nowhere to say it — the logger *is* the reporting
    // channel. Swallowed deliberately.
  }
}
