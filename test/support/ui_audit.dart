/// The shared large-text / LTR layout sweep (F27-T15).
///
/// Every screen test calls [auditScreenLayout] once, handing over its own
/// pump closure. The sweep then renders that screen across the full matrix of
/// [kAuditLocales] × [kAuditTextScales] on a **phone-sized** surface and fails
/// if that frame reports anything at all. What it is hunting is the
/// `RenderFlex overflowed by …` family, but it does not filter: a screen that
/// threw for some other reason did not actually get laid out, so that is a
/// failure of this sweep too. [recordReportedErrors] collects the reports
/// itself rather than letting the binding keep them for `takeException`,
/// which is what preserves the error-causing widget.
///
/// Why a phone surface is the point: `flutter_test`'s default window is
/// 800 × 600 logical pixels — wider and shorter than any phone the app ships
/// on. A row that overflows at 360 dp has room to spare at 800 dp, so the
/// large-text tests written per feature before this audit could not see
/// horizontal overflow at all. [kAuditPhoneSize] is the low-end floor the
/// audit holds the app to.
///
/// What it cannot see: text that is *clipped* rather than overflowing
/// (`maxLines` + `TextOverflow.ellipsis`) and content a scroll view absorbs
/// are silent by design — Flutter reports no error for either. Those were
/// read by hand in the audit; see `docs/features/F27-T15-ui-audits.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';

/// A low-end portrait phone, in logical pixels.
///
/// 360 × 640 is the 720 × 1280 budget Android screen at device-pixel-ratio 2 —
/// narrower than the owner's RMX2001 (360 × 800) and much shorter, so it
/// stresses both axes at once. Chosen as a floor, not as a specific device.
const Size kAuditPhoneSize = Size(360, 640);

/// Both shipped languages (Q6): Arabic drives RTL, English drives LTR.
const List<Locale> kAuditLocales = [
  AppLocalizations.arabic,
  AppLocalizations.english,
];

/// 1.0 is the design size, 1.5 is the app's own `TextSize.veryLarge` ceiling
/// (`core/accessibility/text_size.dart`), and 2.0 is deliberately past it —
/// the margin the per-feature tests already used.
const List<double> kAuditTextScales = [1.0, 1.5, 2.0];

/// Renders [screen] through [pump] across the whole audit matrix, asserting
/// that no frame reports a layout error.
///
/// [pump] receives the locale and text scaler to apply and must mount the
/// screen with them — normally by forwarding both to `pumpApp`. A screen with
/// a continuously repeating animation forwards `settle: false` as well;
/// `pumpAndSettle` never returns while one is running.
///
/// Call it at group level, not inside a `testWidgets`: it declares one test
/// per combination so a failure names the exact locale, scale and screen.
/// [name] must be the screen's widget class name — `ui_audit_coverage_test`
/// matches it against the screens on disk, so a new screen cannot quietly
/// skip the sweep.
void auditScreenLayout(
  String name,
  Future<void> Function(WidgetTester tester, Locale locale, TextScaler scaler)
  pump, {
  Size size = kAuditPhoneSize,
  List<Locale> locales = kAuditLocales,
  List<double> textScales = kAuditTextScales,
}) {
  group('$name · layout audit (F27-T15)', () {
    for (final locale in locales) {
      for (final scale in textScales) {
        final label =
            '${locale.languageCode} · text ×$scale · '
            '${size.width.toInt()}×${size.height.toInt()}';
        testWidgets('lays out with no overflow — $label', (tester) async {
          setAuditSurface(tester, size);
          final reported = await recordReportedErrors(
            () => pump(tester, locale, TextScaler.linear(scale)),
          );
          expectNoLayoutError(reported, '$name — $label');
        });
      }
    }
  });
}

/// Sizes the test window to [size] logical pixels and restores it afterwards.
///
/// Device-pixel-ratio 1 makes `physicalSize` and the logical size the same
/// number, so the surface reads as what it is.
void setAuditSurface(WidgetTester tester, [Size size = kAuditPhoneSize]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Runs [body] with everything the framework reports collected, instead of
/// letting the test binding bank it for `takeException`.
///
/// `takeException` hands back the thrown object alone, and a `RenderFlex`
/// overflow's object is just the message — "overflowed by 17 pixels on the
/// right" with nothing to say *which* row. The full [FlutterErrorDetails],
/// printed, carries the error-causing widget and its creator chain, which is
/// the part an audit needs.
///
/// The handler is restored in a `finally`, before the caller asserts anything:
/// the binding asserts hard if a test is still holding `FlutterError.onError`
/// when an `expect` fails.
Future<List<FlutterErrorDetails>> recordReportedErrors(
  Future<void> Function() body,
) async {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return reported;
}

/// Fails if anything was [reported] while the screen was laid out, naming
/// [context] and dumping the first error in full.
void expectNoLayoutError(List<FlutterErrorDetails> reported, String context) {
  if (reported.isEmpty) return;
  final extra = reported.length > 1
      ? '\n\n(${reported.length - 1} further error(s) suppressed)'
      : '';
  fail(
    '$context reported an exception while laying out:\n'
    '${reported.first}$extra',
  );
}
