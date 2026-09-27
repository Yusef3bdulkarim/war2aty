import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/error/app_failure.dart';

/// Turns a GoTrue [supabase.AuthException] into an [AppFailure].
///
/// The counterpart of `failureFromDioException` for the auth client, and it
/// exists for the same reason: the distinction the user actually feels is "you
/// are offline" versus "the service is having a problem", because the two
/// suggest different actions — check your connection, or wait and retry.
///
/// ## Why a type check is not enough
///
/// GoTrue does not have a transport-error type. Its `fetch.dart` wraps **every**
/// socket-level failure — no connectivity, DNS, connection refused, TLS — in
/// `AuthRetryableFetchException`, and that class `extends AuthException`. A
/// `catch (AuthException)` therefore swallows a no-internet sign-in and reports
/// it as a credential problem, which is what this mapper exists to prevent.
///
/// The same type is *also* thrown for an HTTP 5xx, and those two cases must not
/// collapse together: telling a user with full signal to check their wifi during
/// an auth outage sends them to the wrong place entirely. The SDK sets
/// `statusCode` **only** in its `statusCode >= 500` branch, leaving it null for
/// the transport catch-all — so the exception carries its own discriminator, and
/// that is what this reads.
///
/// Everything else keeps the behaviour it has always had: `AuthApiException`
/// (every 4xx, a rate-limited sign-in included), `AuthUnknownException` (an
/// undecodable body — a captive portal's HTML answer lands here) and
/// `AuthSessionMissingException` are all credential/service problems, not
/// connectivity.
///
/// PRIVACY: [supabase.AuthException.message] is never read. It is built from the
/// response body and can quote internal auth configuration (§7/§51); only the
/// runtime type and [supabase.AuthException.statusCode] are inspected.
AppFailure failureFromAuthException(supabase.AuthException exception) {
  if (exception is! supabase.AuthRetryableFetchException) {
    return const UnauthorizedFailure();
  }

  return exception.statusCode == null
      ? const NoInternetFailure()
      : const AnalysisServiceFailure();
}
