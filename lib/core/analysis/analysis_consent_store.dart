import '../database/app_database.dart';

/// Persists the user's «السماح بإرسال النص للتحليل» choice (F11-T02) — whether
/// the extracted text may be sent for smart analysis at all. Text extraction
/// (OCR) itself always stays on-device regardless of this setting.
abstract interface class AnalysisConsentStore {
  /// `null` means the user has never touched the setting — the caller
  /// decides the default for that case, not this store.
  Future<bool?> readConsent();

  Future<void> writeConsent(bool consent);
}

/// [AnalysisConsentStore] backed by the Drift `app_settings` table — the same
/// key/value table [DriftLocaleStore] and [DriftNotificationPrivacyStore] use.
final class DriftAnalysisConsentStore implements AnalysisConsentStore {
  const DriftAnalysisConsentStore(this._db);

  static const String _key = 'analysis_consent';

  final AppDatabase _db;

  @override
  Future<bool?> readConsent() async {
    final value = await _db.getSetting(_key);
    return value == null ? null : value == 'true';
  }

  @override
  Future<void> writeConsent(bool consent) =>
      _db.setSetting(_key, consent.toString());
}
