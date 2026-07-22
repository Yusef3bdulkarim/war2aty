/// Abstract localization contract.
///
/// Every user-facing string is a getter here. Each concrete locale
/// ([ArStrings], [EnStrings]) `implements` this interface, so the compiler
/// forces every key to be defined in every language — a missing translation
/// is a compile error, not a runtime surprise. No code generation.
abstract interface class AppStrings {
  String get appName;

  /// One-line promise shown under the app name on the splash screen.
  String get appTagline;

  // Launch failure
  String get bootstrapErrorTitle;
  String get bootstrapErrorMessage;

  /// Launch progress, announced to assistive technology. Discrete getters
  /// (rather than a method taking a stage) keep this interface free of any
  /// feature-layer type.
  String get bootstrapStageSession;
  String get bootstrapStageConfig;
  String get bootstrapStageCleanup;
  String get bootstrapStageReminders;
  String get bootstrapStageUsage;

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

  // Onboarding (first run)
  String get onboardingTitle;
  String get onboardingSubtitle;

  /// The four document kinds shown as cards on the intro page.
  String get onboardingKindAppointment;
  String get onboardingKindInvoice;
  String get onboardingKindGovernment;
  String get onboardingKindEducation;

  String get onboardingStart;
  String get privacyTitle;

  /// The four promises listed on the privacy page, in display order.
  String get privacyPointExtractText;
  String get privacyPointTextOnly;
  String get privacyPointImageOptIn;
  String get privacyPointDeleteAnytime;

  String get privacyAgree;

  // Home
  String get homeGreetingTitle;
  String get homeGreetingSubtitle;
  String get homeScanTitle;
  String get homeScanSubtitle;
  String get homePickImage;
  String get homeImagePrivacyNote;

  /// "You have N analyses left today."
  ///
  /// A method, not a getter, because Arabic inflects the noun by count:
  /// singular, dual, then plural. [remaining] is never negative.
  String homeUsageRemaining(int remaining);

  String get homeEmptyTitle;
  String get homeUpcomingReminderTitle;
  String get homeRecentDocumentsTitle;
  String get homeSeeAll;

  /// Category names, also used by the documents list filters (F08).
  String get documentCategoryAppointment;
  String get documentCategoryInvoice;
  String get documentCategoryGovernment;
  String get documentCategoryEducation;
  String get documentCategoryOther;

  /// Morning / afternoon marker on a clock time.
  String get timeAm;
  String get timePm;

  /// When a reminder is due. [time] is already formatted; [date] is a short
  /// numeric day for anything past tomorrow.
  String reminderDueToday(String time);
  String reminderDueTomorrow(String time);
  String reminderDueOn(String date, String time);

  /// Opens the item the row is about.
  String get actionView;

  /// What was kept on the device for a saved document.
  String get documentStoredResultOnly;
  String get documentStoredWithImage;

  // Bottom navigation
  String get navHome;
  String get navDocuments;
  String get navReminders;
  String get navSettings;

  // Settings
  String get languageArabic;
  String get languageEnglish;
}
