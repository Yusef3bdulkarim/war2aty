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
  String get actionBack;
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

  // Capture — camera permission
  String get cameraPermissionTitle;

  /// Why the camera is needed, shown before the system prompt appears.
  String get cameraPermissionMessage;

  /// Shown instead once the OS has stopped prompting, so the button that now
  /// opens Settings is not a surprise.
  String get cameraPermissionBlockedMessage;

  String get cameraPermissionAllow;
  String get cameraPermissionOpenSettings;

  /// The way forward without the camera: pick a photo that already exists.
  String get cameraPermissionPickInstead;

  // Capture — viewfinder
  /// Announced while the camera is opening.
  String get cameraOpening;

  /// The guidance under the frame: fit the whole paper inside it.
  String get cameraViewfinderHint;

  /// Accessibility label for the shutter button.
  String get cameraShutterLabel;

  /// Accessibility label for the close button.
  String get cameraCloseLabel;

  /// Shown when the camera cannot be opened or a shot fails.
  String get cameraCaptureErrorTitle;
  String get cameraCaptureErrorMessage;

  // Capture — gallery picker
  /// Announced while the system photo picker is opening.
  String get galleryOpening;

  /// Shown when the photo picker cannot be opened.
  String get galleryErrorTitle;
  String get galleryErrorMessage;

  // Capture — crop/rotate preview
  String get previewTitle;

  /// The reassurance line above the confirm button.
  String get previewHint;

  String get previewUseImage;
  String get previewRetake;

  /// Accessibility label for the rotate button.
  String get previewRotateLabel;

  /// Announced while the confirmed image is being prepared.
  String get previewProcessing;

  /// Shown when preparing the confirmed image fails.
  String get previewErrorMessage;

  // Capture — quality alert
  /// Heading when the quality assessment says the image is poor.
  String get qualityAlertTitle;

  /// Why a clearer photo matters, with a nudge to retake.
  String get qualityAlertMessage;

  /// The primary action: retake the photo.
  String get qualityAlertRetake;

  /// The fallback action: continue despite poor quality.
  String get qualityAlertContinue;

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

  // OCR processing
  String get ocrProcessing;
  String get ocrErrorTitle;
  String get ocrErrorMessage;
  String get ocrNoTextTitle;
  String get ocrNoTextMessage;
  String get ocrRetake;
  String get ocrPickAnother;

  // OCR extracted text
  String get ocrExtractedTextTitle;
  String get ocrCopyText;
  String get ocrTextCopied;
  String get ocrContinue;

  // OCR candidate labels
  String get ocrDatesSection;
  String get ocrTimesSection;
  String get ocrAmountsSection;
  String get ocrPhonesSection;
  String get ocrReferencesSection;

  // OCR field review
  String get ocrReviewTitle;
  String get ocrReviewSubtitle;
  String get ocrReviewDone;
}
