/// The error-report request body (F27-T12, Q13).
///
/// Built from the fields a [LogEvent] already produced, which are §51
/// allowlisted by construction — so why filter again here? Because this is the
/// only place in the app that puts a log field on the network. The in-app
/// allowlist can grow for a local-only reason; this one may not grow by
/// accident. Every field is named explicitly below, and anything else in the
/// incoming map is dropped rather than forwarded.
///
/// There is no field for a message, an exception, a stack trace, or any value
/// read off a document. The server rejects unknown fields outright, so adding
/// one here without the matching change there fails loudly rather than
/// quietly shipping content.
final class ErrorReportDto {
  const ErrorReportDto({
    required this.errorCode,
    this.stage,
    this.resultStatus,
    this.requestId,
    this.analysisSessionId,
    this.httpStatus,
    this.durationMs,
    this.appVersion,
    this.schemaVersion,
  });

  /// Reads the report out of [LogEvent.toLogMap]'s output.
  ///
  /// Returns `null` when the record carries no `errorCode` — a success line, a
  /// timing line, an OCR character count. Those are local telemetry and have
  /// no business leaving the device: this endpoint exists for things that went
  /// wrong, and that filter is what keeps its volume proportional to defects
  /// rather than to use.
  static ErrorReportDto? fromLogFields(Map<String, Object> fields) {
    final errorCode = fields['errorCode'];
    if (errorCode is! String || errorCode.isEmpty) return null;

    return ErrorReportDto(
      errorCode: errorCode,
      stage: _stringOrNull(fields['stage']),
      resultStatus: _stringOrNull(fields['resultStatus']),
      requestId: _stringOrNull(fields['requestId']),
      analysisSessionId: _stringOrNull(fields['analysisSessionId']),
      httpStatus: _intOrNull(fields['httpStatus']),
      durationMs: _intOrNull(fields['durationMs']),
      appVersion: _stringOrNull(fields['appVersion']),
      schemaVersion: _stringOrNull(fields['schemaVersion']),
    );
  }

  /// A closed code: an [AppFailure]'s code or a [LogCrashKind]'s.
  final String errorCode;
  final String? stage;
  final String? resultStatus;
  final String? requestId;
  final String? analysisSessionId;
  final int? httpStatus;
  final int? durationMs;
  final String? appVersion;
  final String? schemaVersion;

  /// Snake_case, matching the Edge Function contract. Null fields are omitted
  /// rather than sent as `null`, so an absent value never reads as a measured
  /// one.
  Map<String, Object> toJson() => {
    'error_code': errorCode,
    'stage': ?stage,
    'result_status': ?resultStatus,
    'request_id': ?requestId,
    'analysis_session_id': ?analysisSessionId,
    'http_status': ?httpStatus,
    'duration_ms': ?durationMs,
    'app_version': ?appVersion,
    'schema_version': ?schemaVersion,
  };

  static String? _stringOrNull(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _intOrNull(Object? value) => value is int ? value : null;
}
