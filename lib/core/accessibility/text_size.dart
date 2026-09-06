import 'package:flutter/widgets.dart';

/// User-selectable text size (F11-T05): عادي / كبير / كبير جدًا.
///
/// The app wraps its root [MediaQuery] with the corresponding
/// [TextScaler.linear] so every widget that respects [MediaQuery.textScaler]
/// — which includes every [Text] — scales automatically. Screens are already
/// designed for RTL and large-text tolerance (CLAUDE.md §10), so this is safe
/// to apply globally.
///
/// The enum values double as the `app_settings` table's persisted strings —
/// [name] is written and matched on read — so they must not be renamed
/// without a migration.
enum TextSize {
  /// No scaling — the design's own Cairo sizes.
  normal,

  /// 125 % — easier to read without changing the layout fundamentally.
  large,

  /// 150 % — the ceiling before compact layouts start breaking. This is the
  /// largest the app offers deliberately rather than relying on the OS's own
  /// accessibility text scaling, because the UI is tuned for this range and
  /// has not been tested beyond it.
  veryLarge;

  /// The [TextScaler] the root [MediaQuery] should carry.
  TextScaler get scaler => switch (this) {
    TextSize.normal => TextScaler.noScaling,
    TextSize.large => const TextScaler.linear(1.25),
    TextSize.veryLarge => const TextScaler.linear(1.5),
  };
}
