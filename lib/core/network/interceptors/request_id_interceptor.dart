import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Header the backend reads and echoes (F06-T04).
const String kRequestIdHeader = 'x-request-id';

/// Stamps every request with a fresh `x-request-id`.
///
/// The id is the backend's correlation key *and* the primary key of
/// `analysis_attempts`, which is what makes a retry idempotent: a request
/// resent under the same id collides on that key instead of consuming a second
/// slot from the user's 3-per-day quota.
///
/// ## Why a fresh id per attempt, not per analysis
///
/// The backend has no result cache, so a `duplicate` reservation cannot be
/// answered with the original analysis — it answers `ANALYSIS_FAILED` instead
/// (F06-T13). Reusing an id across a user-initiated retry would therefore turn
/// a recoverable timeout into a permanent failure for that document.
///
/// A fresh id per HTTP attempt means each retry is judged on its own: quota
/// permitting, it actually runs. The duplicate branch stays as a guard against
/// something below us replaying a request byte-for-byte, which is exactly the
/// case where not double-charging matters.
final class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor({String Function()? generateId})
    : _generateId = generateId ?? (() => const Uuid().v4());

  final String Function() _generateId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // A caller that set one explicitly wins — the auth retry path does this to
    // guarantee its replay is not seen as a duplicate.
    options.headers.putIfAbsent(kRequestIdHeader, _generateId);
    handler.next(options);
  }
}
