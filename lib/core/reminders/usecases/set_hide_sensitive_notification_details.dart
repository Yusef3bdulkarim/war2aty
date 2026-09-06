import '../notification_privacy_store.dart';

/// Persists the user's choice for «إخفاء التفاصيل الحساسة» (F09-T14).
final class SetHideSensitiveNotificationDetails {
  const SetHideSensitiveNotificationDetails(this._store);

  final NotificationPrivacyStore _store;

  Future<void> call(bool hide) => _store.writeHideSensitiveDetails(hide);
}
