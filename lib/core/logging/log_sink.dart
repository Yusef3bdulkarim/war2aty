import 'dart:developer' as developer;

/// Destination for already-sanitised log fields.
///
/// Implementations receive only §51-allowlisted key/value pairs (see
/// [LogEvent.toLogMap]); they must not re-inspect or enrich them with content.
abstract interface class LogSink {
  void write(Map<String, Object> fields);
}

/// Writes to `dart:developer`'s structured log (dev builds). Never `print`.
final class DeveloperLogSink implements LogSink {
  const DeveloperLogSink();

  @override
  void write(Map<String, Object> fields) {
    final line = fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
    developer.log(line, name: 'war2aty');
  }
}

/// Discards everything — the default in prod builds.
final class NoopLogSink implements LogSink {
  const NoopLogSink();

  @override
  void write(Map<String, Object> fields) {}
}
