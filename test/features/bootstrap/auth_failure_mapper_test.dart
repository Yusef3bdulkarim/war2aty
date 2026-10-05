import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/bootstrap/data/mappers/auth_failure_mapper.dart';

void main() {
  group('failureFromAuthException', () {
    test('a dead socket reads as no internet, not as unauthorized', () {
      // The bug this mapper exists for (F19). GoTrue has no transport-error
      // type: `fetch.dart` wraps every socket failure in this class, which
      // extends AuthException — so an offline sign-in used to be reported as a
      // credential problem, and the offline copy could never be reached.
      // `statusCode` is null for the transport catch-all.
      expect(
        failureFromAuthException(supabase.AuthRetryableFetchException()),
        isA<NoInternetFailure>(),
      );
    });

    test('a 5xx is the service being down, not the user being offline', () {
      // The same exception type, and this is the only branch where the SDK sets
      // `statusCode`. Telling someone with full signal to check their wifi
      // during an auth outage sends them to the wrong place, so the two must
      // not collapse together.
      for (final status in ['500', '502', '503']) {
        expect(
          failureFromAuthException(
            supabase.AuthRetryableFetchException(statusCode: status),
          ),
          isA<AnalysisServiceFailure>(),
          reason: 'status $status is the server answering badly, not silence',
        );
      }
    });

    test('a refused credential stays unauthorized', () {
      expect(
        failureFromAuthException(
          const supabase.AuthApiException('bad grant', statusCode: '400'),
        ),
        isA<UnauthorizedFailure>(),
      );
      expect(
        failureFromAuthException(supabase.AuthSessionMissingException()),
        isA<UnauthorizedFailure>(),
      );
    });

    test('a rate-limited sign-in is not mistaken for connectivity', () {
      // 429 arrives as an AuthApiException, never as the retryable type, so it
      // must not read as "no internet" — the user is connected and being
      // throttled.
      expect(
        failureFromAuthException(
          const supabase.AuthApiException('too many', statusCode: '429'),
        ),
        isA<UnauthorizedFailure>(),
      );
    });

    test('an undecodable body stays a service problem', () {
      // A captive portal answering a sign-in POST with an HTML page lands here.
      expect(
        failureFromAuthException(
          supabase.AuthUnknownException(
            message: 'Failed to decode error response',
            originalError: StateError('boom'),
          ),
        ),
        isA<UnauthorizedFailure>(),
      );
    });

    test('the exception message is never read', () {
      // GoTrue builds `message` from the response body, which can quote
      // internal auth configuration (§7/§51). A failure carries no text at all,
      // so this is structural — but assert it, because a future leaf that
      // started carrying a message would pass silently otherwise.
      final failure = failureFromAuthException(
        supabase.AuthRetryableFetchException(message: 'رقم الحساب 12345678'),
      );

      expect(failure.toString(), isNot(contains('12345678')));
    });
  });
}
