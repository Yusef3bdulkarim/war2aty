import '../error/app_failure.dart';
import '../time/cairo_day.dart';
import 'api_error_dto.dart';

/// Maps a §31 error body from any endpoint to an [AppFailure].
///
/// Follows the code table in API_CONTRACT §31. `error.message` is English and
/// for debugging only — it is never read here, so it cannot reach the user;
/// presentation derives Arabic copy from the failure type instead.
///
/// [statusCode] is the fallback when the body is not a §31 envelope at all.
///
/// That is not hypothetical: the Supabase gateway enforces `verify_jwt` and
/// rejects an expired token **before** the Edge Function runs, so its 401 body
/// is GoTrue's shape, not ours. Verified against the local stack — without this
/// an expired session surfaced as a generic "الخدمة غير متاحة" instead of the
/// session error, hiding the one failure the app can silently recover from.
///
/// Only unambiguous statuses are mapped. A bare 429 is not one of them — it is
/// either the daily limit or an AI rate limit, and those are different screens,
/// so guessing would be worse than the generic answer.
///
/// [now] is injected so the [DailyLimitReachedFailure] fallback is testable.
AppFailure failureFromErrorBody(
  Object? body, {
  DateTime? now,
  int? statusCode,
}) {
  final dto = _tryParse(body);

  // Non-JSON, or a shape that isn't the documented envelope (§31 rule 4).
  if (dto == null) return _failureFromStatus(statusCode);

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

/// The status alone, for a body we could not read.
///
/// Deliberately conservative: only statuses that mean exactly one thing.
AppFailure _failureFromStatus(int? statusCode) {
  return switch (statusCode) {
    401 => const UnauthorizedFailure(),
    408 => const RequestTimeoutFailure(),
    503 => const AnalysisDisabledFailure(),
    _ => const AnalysisServiceFailure(),
  };
}

ApiErrorDto? _tryParse(Object? body) {
  if (body is! Map<String, dynamic>) return null;
  try {
    return ApiErrorDto.fromJson(body);
  } catch (_) {
    return null;
  }
}

/// When the quota resets. Falls back to the next Cairo midnight if the server
/// omitted `details.reset_at` or sent something unparseable — the user still
/// gets a truthful "try again tomorrow" rather than an error about an error.
DateTime _resetAt(ApiErrorDto dto, DateTime now) {
  final raw = dto.details?.resetAt;
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  return parsed ?? nextCairoResetAfter(now);
}
