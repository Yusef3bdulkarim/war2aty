import '../error/app_failure.dart';
import 'log_event.dart';
import 'log_sink.dart';

/// Privacy-safe logger. The only way to log is a structured [LogEvent] whose
/// fields are the §51 allowlist — there is no free-form message API, so
/// document content cannot be logged.
abstract interface class AppLogger {
  /// Logs an allowlisted structured record.
  void event(LogEvent e);

  /// Convenience for logging a failure: derives the error code and marks the
  /// result status as a failure.
  void failure(AppFailure failure, {LogStage? stage, String? sessionId});
}

/// Default [AppLogger]: serialises to the allowlist and forwards to a [LogSink].
final class StructuredAppLogger implements AppLogger {
  const StructuredAppLogger(this._sink);

  final LogSink _sink;

  @override
  void event(LogEvent e) {
    final fields = e.toLogMap();
    // Belt-and-suspenders: the event can only produce allowlisted keys, but
    // assert it so any future regression is caught in dev/test immediately.
    assert(
      fields.keys.every(kAllowedLogFields.contains),
      'AppLogger emitted a non-allowlisted field: ${fields.keys}',
    );
    _sink.write(fields);
  }

  @override
  void failure(AppFailure failure, {LogStage? stage, String? sessionId}) {
    event(
      LogEvent(
        analysisSessionId: sessionId,
        stage: stage,
        resultStatus: LogResultStatus.failure,
        failure: failure,
      ),
    );
  }
}
