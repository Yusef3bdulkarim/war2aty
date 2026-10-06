import 'package:flutter/widgets.dart';

/// User-selectable text size (F11-T05): عادي / كبير / كبير جدًا.
///
/// The app wraps its root [MediaQuery] with a [TextScaler.linear] so every
/// widget that respects [MediaQuery.textScaler] — which includes every [Text]
/// — scales automatically. Screens are already designed for RTL and large-text
/// tolerance (CLAUDE.md §10), so this is safe to apply globally.
///
/// This choice is not the whole answer, though: [resolveTextScaler] combines it
/// with the OS's own text size, so a phone already set larger than the user
/// picked here is not scaled back down (F27-T15).
///
/// The enum values double as the `app_settings` table's persisted strings —
/// [name] is written and matched on read — so they must not be renamed
/// without a migration.
enum TextSize {
  /// No scaling — the design's own Cairo sizes.
  normal,

  /// 125 % — easier to read without changing the layout fundamentally.
  large,

  /// 150 % — the largest this control offers, and no longer a ceiling on what
  /// the app will render: a bigger OS text size wins, up to [kMaxTextScale].
  /// See [resolveTextScaler].
  veryLarge;

  /// The multiplier this choice asks for.
  double get factor => switch (this) {
    TextSize.normal => 1,
    TextSize.large => 1.25,
    TextSize.veryLarge => 1.5,
  };

  /// The [TextScaler] for this choice on its own, ignoring the OS.
  TextScaler get scaler => switch (this) {
    TextSize.normal => TextScaler.noScaling,
    TextSize.large => const TextScaler.linear(1.25),
    TextSize.veryLarge => const TextScaler.linear(1.5),
  };
}

/// The largest scale the app will render at.
///
/// Not a guess: the F27-T15 layout sweep renders every screen at x2.0, in both
/// languages, on a 360x640 phone, and its coverage guard stops a new screen
/// joining the app without being held to the same thing. So this is the number
/// the test suite actually underwrites. Raising it means extending
/// `kAuditTextScales` in `test/support/ui_audit.dart` first, and fixing
/// whatever that turns up.
const double kMaxTextScale = 2;

/// The scaler the root [MediaQuery] should carry: whichever of the OS's own
/// text size and the user's in-app [TextSize] is **larger**, capped at
/// [kMaxTextScale].
///
/// Until F27-T15 the app simply replaced [MediaQuery.textScaler] with
/// [TextSize.scaler], so a user who had set 200 % in Android's accessibility
/// settings got 100 % here until they found this app's own control: the system
/// setting they rely on everywhere else did nothing. The audit's sweep then
/// proved every screen survives x2.0, which is what makes honouring it safe.
///
/// Taking the larger of the two, rather than simply deferring to the OS, keeps
/// the in-app control honest in the other direction too: the largest in-app
/// choice must not quietly *shrink* text for someone whose phone is already
/// set above 150 %.
TextScaler resolveTextScaler(TextScaler osScaler, TextSize choice) {
  // Measured at a real body size rather than at 1: a platform scaler can be
  // non-linear (Android 14 onward), and `scale(1)` of a non-linear curve says
  // little about what body text will do.
  const reference = 14.0;
  final osFactor = osScaler.scale(reference) / reference;
  final factor = (osFactor > choice.factor ? osFactor : choice.factor).clamp(
    1.0,
    kMaxTextScale,
  );
  return TextScaler.linear(factor);
}
