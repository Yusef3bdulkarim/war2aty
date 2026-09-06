import '../database/app_database.dart';

/// Persists the «إخفاء التفاصيل الحساسة» notification setting (F09-T14)
/// across launches — the same `app_settings` key/value table
/// [DriftLocaleStore] uses for the saved language.
abstract interface class NotificationPrivacyStore {
  /// `null` means the user has never touched the setting — the caller
  /// decides the privacy-safe default for that case, not this store.
  Future<bool?> readHideSensitiveDetails();

  Future<void> writeHideSensitiveDetails(bool hide);
}

/// [NotificationPrivacyStore] backed by the Drift `app_settings` table.
final class DriftNotificationPrivacyStore implements NotificationPrivacyStore {
  const DriftNotificationPrivacyStore(this._db);

  static const String _key = 'hide_sensitive_notification_details';

  final AppDatabase _db;

  @override
  Future<bool?> readHideSensitiveDetails() async {
    final value = await _db.getSetting(_key);
    return value == null ? null : value == 'true';
  }

  @override
  Future<void> writeHideSensitiveDetails(bool hide) =>
      _db.setSetting(_key, hide.toString());
}
