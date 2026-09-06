/// Keys in the `app_settings` table more than one place needs to agree on.
final class AppSettingKeys {
  const AppSettingKeys._();

  /// See `DriftOnboardingRepository.settingKey` — the first-run gate, not a
  /// user preference, so «حذف كل بيانات التطبيق» (F11-T11) preserves it
  /// rather than clearing it along with every other setting.
  static const String onboardingSeen = 'onboarding_seen';
}
