import '../error/app_failure.dart';
import 'error_code.dart';

/// Analysis pipeline stage a log line refers to. Closed set — grown as the
/// pipeline gains stages; never free text.
enum LogStage { capture, ocr, analyze, save }

/// Outcome of an analysis attempt.
enum LogResultStatus { success, partial, failure }

/// Coarse OCR confidence band — never the raw score, never the text.
enum ConfidenceBand { high, medium, low }

/// The exact, exhaustive set of field keys allowed in a Flutter log line (§51).
///
/// Anything outside this set is document content or PII and must never be
/// logged. [LogEvent.toLogMap] produces only these keys by construction.
const Set<String> kAllowedLogFields = {
  'analysisSessionId',
  'stage',
  'durationMs',
  'ocrCharacterCount',
  'ocrConfidenceBand',
  'resultStatus',
  'errorCode',
  'appVersion',
  'schemaVersion',
};

/// An immutable, privacy-safe log record.
///
/// Its fields ARE the §51 allowlist — there is no field for a free-form
/// message, map, OCR text, amount, name, or note, so document content cannot
/// be expressed. [errorCode] is not settable directly: it is derived from an
/// [AppFailure] via [errorCodeOf], keeping it a closed, content-free code.
final class LogEvent {
  const LogEvent({
    this.analysisSessionId,
    this.stage,
    this.durationMs,
    this.ocrCharacterCount,
    this.ocrConfidenceBand,
    this.resultStatus,
    this.failure,
    this.appVersion,
    this.schemaVersion,
  });

  /// Generated UUID for one analysis session — an identifier, not content.
  final String? analysisSessionId;
  final LogStage? stage;
  final int? durationMs;
  final int? ocrCharacterCount;
  final ConfidenceBand? ocrConfidenceBand;
  final LogResultStatus? resultStatus;

  /// The failure that occurred; only its stable code is logged, never its data.
  final AppFailure? failure;

  final String? appVersion;
  final String? schemaVersion;

  /// Serializes only the §51 allowlisted fields; null fields are omitted.
  Map<String, Object> toLogMap() {
    return {
      'analysisSessionId': ?analysisSessionId,
      if (stage != null) 'stage': stage!.name,
      'durationMs': ?durationMs,
      'ocrCharacterCount': ?ocrCharacterCount,
      if (ocrConfidenceBand != null)
        'ocrConfidenceBand': ocrConfidenceBand!.name,
      if (resultStatus != null) 'resultStatus': resultStatus!.name,
      if (failure != null) 'errorCode': errorCodeOf(failure!),
      'appVersion': ?appVersion,
      'schemaVersion': ?schemaVersion,
    };
  }
}
