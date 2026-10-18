/// Sends the user to the operating system's own text-to-speech settings
/// (F30-T07), where a reading voice can be installed or switched.
///
/// The seam exists for the same reason [ExternalLinkService]'s does: exactly
/// one file talks to the platform, and everything above it speaks a bool.
/// Unlike that one there is no plugin behind this — it is a single Android
/// intent, so the app carries its own method channel rather than a dependency
/// for one call (F30, the owner's choice; the same reasoning `MainActivity`
/// already records for using the platform splash API instead of
/// `androidx.core:core-splashscreen`).
abstract interface class SystemTtsSettings {
  /// Whether this device has a settings screen to send the user to at all.
  ///
  /// Asked before offering the way out, so «افتح إعدادات الموبايل» never
  /// appears on a phone where it would do nothing — iOS has no such screen,
  /// and not every Android build registers the text-to-speech one.
  Future<bool> isAvailable();

  /// Opens the system's text-to-speech settings.
  ///
  /// Answers false when there is nothing to open — iOS has no such screen,
  /// and an Android build could in principle have the activity disabled —
  /// rather than throwing. "Nothing to open" is an ordinary outcome, and the
  /// caller has to be able to keep the message on screen without offering a
  /// button that does nothing.
  Future<bool> open();
}
