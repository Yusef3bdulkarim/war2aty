import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/logging/app_logger.dart';
import 'package:war2aty/core/logging/global_error_handlers.dart';
import 'package:war2aty/core/logging/log_event.dart';

final class _RecordingLogger implements AppLogger {
  final List<LogEvent> events = [];

  @override
  void event(LogEvent e) => events.add(e);

  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) {
    events.add(LogEvent(failure: failure, stage: stage));
  }

  List<String?> get codes =>
      events.map((e) => e.toLogMap()['errorCode'] as String?).toList();
}

final class _ThrowingLogger implements AppLogger {
  @override
  void event(LogEvent e) => throw StateError('the sink is broken');

  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) =>
      throw StateError('the sink is broken');
}

void main() {
  late _RecordingLogger logger;
  late VoidCallback restore;

  setUp(() => logger = _RecordingLogger());
  tearDown(() => restore());

  group('FlutterError.onError', () {
    test('logs the framework crash code', () {
      restore = installGlobalErrorHandlers(logger);

      FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));

      expect(logger.codes, const ['UNCAUGHT_FLUTTER_ERROR']);
    });

    test('still calls the handler it replaced', () {
      // Chaining, not replacing: the debug console keeps its red screen and
      // its stack trace, and `flutter_test`'s own handler keeps working —
      // which is what stops this from silently disarming test failures.
      final previous = FlutterError.onError;
      var previousRan = 0;
      FlutterError.onError = (_) => previousRan++;

      final undo = installGlobalErrorHandlers(logger);
      FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));
      undo();

      restore = () => FlutterError.onError = previous;

      expect(previousRan, 1);
      expect(logger.codes, const ['UNCAUGHT_FLUTTER_ERROR']);
    });

    test('a throwing logger does not escape the handler', () {
      // A throw here re-enters the very handler that threw.
      restore = installGlobalErrorHandlers(_ThrowingLogger());

      expect(
        () => FlutterError.onError!(
          FlutterErrorDetails(exception: StateError('boom')),
        ),
        returnsNormally,
      );
    });
  });

  group('PlatformDispatcher.onError', () {
    test('logs the platform crash code and reports it unhandled', () {
      restore = installGlobalErrorHandlers(logger);

      final handled = PlatformDispatcher.instance.onError!(
        StateError('boom'),
        StackTrace.empty,
      );

      expect(logger.codes, const ['UNCAUGHT_PLATFORM_ERROR']);
      expect(
        handled,
        isFalse,
        reason:
            'reporting an error is not recovering from it — claiming '
            'otherwise would swallow real defects',
      );
    });

    test('defers to a handler that was already installed', () {
      final previous = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (_, _) => true;

      final undo = installGlobalErrorHandlers(logger);
      final handled = PlatformDispatcher.instance.onError!(
        StateError('boom'),
        StackTrace.empty,
      );
      undo();

      restore = () => PlatformDispatcher.instance.onError = previous;

      expect(handled, isTrue);
      expect(logger.codes, const ['UNCAUGHT_PLATFORM_ERROR']);
    });
  });

  test('restoring puts both handlers back', () {
    final beforeFlutter = FlutterError.onError;
    final beforePlatform = PlatformDispatcher.instance.onError;

    installGlobalErrorHandlers(logger)();
    restore = () {};

    expect(FlutterError.onError, same(beforeFlutter));
    expect(PlatformDispatcher.instance.onError, same(beforePlatform));
  });
}
