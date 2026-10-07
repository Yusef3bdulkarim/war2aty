import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F27-T12 · The two halves of the error-code allowlist must agree.
///
/// The app decides a code in Dart (`errorCodeOf`, plus `LogCrashKind`); the
/// Edge Function decides whether to accept it in TypeScript
/// (`error-report-codes.ts`). Nothing at compile time connects the two, and a
/// disagreement is invisible in exactly the way that matters: a new
/// `AppFailure` would be reported by the app and refused by the server with a
/// 400 the sink swallows on purpose. The report would simply never arrive, and
/// the monitoring built to tell us things are broken would quietly stop
/// covering the newest failure.
///
/// So this test reads both files and compares the sets. It is the same
/// technique as the native-config guard in `native_permission_copy_test`: the
/// cheapest way to hold a contract that spans two languages in one repo.
void main() {
  /// Source with every comment line removed.
  ///
  /// Without this the extractors read comments as code: a doc comment that
  /// mentions a code in the same quoting style — `// unlike 'INTERNAL_ERROR',
  /// which is a server code` — would be extracted as if the app could report
  /// it, and this guard would start demanding entries for codes that do not
  /// exist. It would fail loudly rather than silently, but it would be failing
  /// about the wrong thing, and a test nobody trusts is a test nobody keeps.
  String withoutComments(String source) => source
      .split('\n')
      .where((line) {
        final trimmed = line.trimLeft();
        return !trimmed.startsWith('//') && !trimmed.startsWith('*');
      })
      .join('\n');

  /// Every code `errorCodeOf` can return, read from its source.
  Set<String> dartFailureCodes() {
    final source = withoutComments(
      File('lib/core/logging/error_code.dart').readAsStringSync(),
    );

    return RegExp(
      r"=>\s*'([A-Z][A-Z0-9_]*)'",
    ).allMatches(source).map((m) => m.group(1)!).toSet();
  }

  /// Every code `LogCrashKind` can produce.
  Set<String> dartCrashCodes() {
    final source = withoutComments(
      File('lib/core/logging/log_event.dart').readAsStringSync(),
    );
    final enumBody = RegExp(
      r'enum LogCrashKind \{(.*?)\n\}',
      dotAll: true,
    ).firstMatch(source);

    expect(enumBody, isNotNull, reason: 'LogCrashKind was renamed or removed');

    return RegExp(
      r"'([A-Z][A-Z0-9_]*)'",
    ).allMatches(enumBody!.group(1)!).map((m) => m.group(1)!).toSet();
  }

  /// Every code the Edge Function accepts.
  Set<String> serverAcceptedCodes() {
    final source = withoutComments(
      File(
        'supabase/functions/_shared/reports/error-report-codes.ts',
      ).readAsStringSync(),
    );
    final listBody = RegExp(
      r'REPORTABLE_ERROR_CODES = \[(.*?)\] as const',
      dotAll: true,
    ).firstMatch(source);

    expect(listBody, isNotNull, reason: 'the allowlist was renamed or removed');

    return RegExp(
      r'"([A-Z][A-Z0-9_]*)"',
    ).allMatches(listBody!.group(1)!).map((m) => m.group(1)!).toSet();
  }

  test('every code the app can report is one the server accepts', () {
    final client = {...dartFailureCodes(), ...dartCrashCodes()};
    final server = serverAcceptedCodes();

    expect(client, isNotEmpty);
    expect(
      client.difference(server),
      isEmpty,
      reason:
          'add these to supabase/functions/_shared/reports/'
          'error-report-codes.ts — the server would refuse them with a 400 '
          'the sink swallows, so the reports would vanish silently',
    );
  });

  test('the server accepts nothing the app cannot produce', () {
    // The other direction matters less but is still a contract: a code here
    // that no `AppFailure` maps to is dead vocabulary, and dead entries are
    // how an allowlist stops being read as a closed set.
    final client = {...dartFailureCodes(), ...dartCrashCodes()};

    expect(
      serverAcceptedCodes().difference(client),
      isEmpty,
      reason: 'these server codes match no AppFailure or LogCrashKind',
    );
  });

  test('a code-shaped comment is not read as a code', () {
    // Guards the guard: this is the fragility the comment stripping removes.
    const sample = """
// unlike 'INTERNAL_ERROR', which is a server code
/// see 'ANALYSIS_FAILED' for the server-side name
 * "LEGACY_CODE" was retired
  OcrFailure() => 'OCR',
""";

    final codes = RegExp(
      r"=>\s*'([A-Z][A-Z0-9_]*)'",
    ).allMatches(withoutComments(sample)).map((m) => m.group(1)!).toSet();

    expect(codes, {'OCR'});
  });

  test('both crash kinds are covered', () {
    // Named explicitly, because these two are what H1 was about: before
    // F27-T12 an uncaught error had no code at all.
    expect(
      dartCrashCodes(),
      containsAll(const ['UNCAUGHT_FLUTTER_ERROR', 'UNCAUGHT_PLATFORM_ERROR']),
    );
  });
}
