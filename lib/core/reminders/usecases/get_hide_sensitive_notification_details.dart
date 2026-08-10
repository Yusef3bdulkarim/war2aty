import '../notification_privacy_store.dart';

/// Reads whether reminder notifications should hide their real title/note
/// (F09-T14) — defaults **on** (hidden) whenever the user has never set it,
/// the privacy-safe default the setting itself ships with. Someone glancing
/// at a lock screen should not learn what a reminder is about unless the
/// user has explicitly chosen to reveal it.
final class GetHideSensitiveNotificationDetails {
  const GetHideSensitiveNotificationDetails(this._store);

  final NotificationPrivacyStore _store;

  Future<bool> call() async => await _store.readHideSensitiveDetails() ?? true;
}
