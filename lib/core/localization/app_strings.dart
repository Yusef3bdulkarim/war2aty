/// Abstract localization contract.
///
/// Every user-facing string is a getter here. Each concrete locale
/// ([ArStrings], [EnStrings]) `implements` this interface, so the compiler
/// forces every key to be defined in every language — a missing translation
/// is a compile error, not a runtime surprise. No code generation.
abstract interface class AppStrings {
  String get appName;

  // Actions
  String get actionRetry;
  String get actionCancel;
  String get actionOk;
  String get actionSave;
  String get actionShare;
  String get actionDelete;

  // Generic states
  String get stateLoading;
  String get stateEmpty;
  String get stateErrorGeneric;

  // Bottom navigation
  String get navHome;
  String get navSaved;
  String get navReminders;
  String get navSettings;

  // Settings
  String get languageArabic;
  String get languageEnglish;
}
