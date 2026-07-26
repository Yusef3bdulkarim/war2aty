import '../../../../core/error/app_failure.dart';
import '../../../../core/time/cairo_day.dart';
import '../models/analysis_error_dto.dart';

/// Maps an error body from the analyze-document endpoint to an [AppFailure].
///
/// Follows the code table in API_CONTRACT §31. `error.message` is English and
/// for debugging only — it is never read here, so it cannot reach the user;
/// presentation derives Arabic copy from the failure type instead.
///
/// [now] is injected so the [DailyLimitReachedFailure] fallback is testable.
AppFailure failureFromErrorBody(Object? body, {DateTime? now}) {
  final dto = _tryParse(body);

  // Non-JSON, or a shape that isn't the documented envelope: the server sent
  // something we can't reason about (§31 rule 4).
  if (dto == null) return const AnalysisServiceFailure();

  return switch (dto.code) {
    'INVALID_REQUEST' || 'UNSUPPORTED_SCHEMA' => const InvalidRequestFailure(),
    'UNSUPPORTED_APP_VERSION' => const UnsupportedAppVersionFailure(),
    'UNAUTHORIZED' => const UnauthorizedFailure(),
    'TIMEOUT' => const RequestTimeoutFailure(),
    'DAILY_LIMIT_REACHED' => DailyLimitReachedFailure(
      _resetAt(dto, now ?? DateTime.now()),
    ),
    'AI_RATE_LIMITED' => const AiProviderRateLimitFailure(),
    'ANALYSIS_DISABLED' => const AnalysisDisabledFailure(),
    'ANALYSIS_FAILED' || 'INTERNAL_ERROR' => const AnalysisServiceFailure(),
    // §31 rule 3: an unrecognised code is still a server-side problem.
    _ => const AnalysisServiceFailure(),
  };
}

AnalysisErrorDto? _tryParse(Object? body) {
  if (body is! Map<String, dynamic>) return null;
  try {
    return AnalysisErrorDto.fromJson(body);
  } catch (_) {
    return null;
  }
}

/// When the quota resets. Falls back to the next Cairo midnight if the server
/// omitted `details.reset_at` or sent something unparseable — the user still
/// gets a truthful "try again tomorrow" rather than an error about an error.
DateTime _resetAt(AnalysisErrorDto dto, DateTime now) {
  final raw = dto.details?.resetAt;
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  return parsed ?? nextCairoResetAfter(now);
}
