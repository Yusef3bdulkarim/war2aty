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

  /// Gregorian month name, 1–12. A date off a paper is written out in full
  /// («25 أغسطس 2026») rather than in digits — a numeric month reads as a
  /// puzzle to exactly the user this app is meant to spare one.
  String monthName(int month);

  /// What to call the currency [code] the analysis reported, e.g. `EGP` →
  /// «جنيه». An unrecognised code is returned unchanged rather than dropped.
  String currencyName(String code);

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

  /// Confirms a save, and says where the paper went and what was kept — the
  /// user is told the picture stayed out of it rather than left to assume.
  String get documentSaved;

  /// A save that did not go through. No detail: the user cannot act on a
  /// database error, only try again.
  String get documentSaveFailed;

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

  // Analysis — while it runs
  String get analysisRunningTitle;
  String get analysisRunningMessage;

  /// Announced to assistive technology while the analysis runs, since the
  /// progress bar itself carries no meaning.
  String get analysisRunningStatus;

  // Analysis result
  /// The result page's own name, in its top bar.
  String get analysisResultTitle;

  /// Accessibility label for the back control on the result page.
  String get analysisResultBackLabel;

  /// The analysis service could not be reached or could not answer. Covers
  /// every network and service failure that is worth one message: a timeout, a
  /// bad response, an outage. The user does not care which.
  String get analysisFailedTitle;
  String get analysisFailedMessage;

  /// The phone is offline. The analysis needs the network; the text does not.
  String get analysisNoInternetTitle;
  String get analysisNoInternetMessage;

  /// The three daily analyses are used up. No retry is offered — it would
  /// only fail again.
  String get analysisLimitReachedTitle;
  String get analysisLimitReachedMessage;

  /// Leaves a state page for the home screen.
  String get analysisBackToHome;

  /// The result page's three standing actions — read it aloud, remind me,
  /// keep it.
  String get resultListen;
  String get resultSavePaper;

  /// Heads the one-line summary card. Deliberately not a claim about how sure
  /// the analysis is — confidence belongs to individual values (UX rule §5.9).
  String get resultSummaryLabel;

  /// Heads «المطلوب منك» — what the paper asks the user to do.
  String get resultActionRequiredTitle;

  /// Marks an action the analysis worked out rather than read off the paper.
  /// Shown whatever the confidence band (API_CONTRACT §30.5).
  String get resultActionInferred;

  /// Heads the disclaimers block — «تنبيه مهم».
  String get resultWarningsTitle;

  /// Heads the labelled facts read off the paper — «أهم المعلومات».
  String get resultKeyInformationTitle;

  /// Accessibility label for the button that copies one value.
  String resultCopyValueLabel(String label);

  /// Heads the dates block — «التواريخ والمواعيد».
  String get resultDatesTitle;

  /// Said under a date the paper gives no hour for. The app never invents one
  /// (UX rule §5.6) — it says the paper is silent and leaves the choice to the
  /// user when they set a reminder.
  String get resultDateNoTime;

  /// Starts a reminder from a date on the paper. Nothing is ever scheduled
  /// without the user going through this (UX rule §5.5).
  String get resultCreateReminder;

  /// The sheet shown when the paper carries more than one date: the app does
  /// not decide which one the user meant (UX rule §5.8).
  String get resultPickDateTitle;
  String get resultPickDateMessage;

  /// Marks a date the analysis thinks is worth remembering, and one it read
  /// but does not suggest reminding about.
  String get resultDateReminderWorthy;
  String get resultDateDisplayOnly;

  /// Heads the money figures — «المبالغ».
  String get resultAmountsTitle;

  /// Heads what the user has to bring along — «المستندات المطلوبة».
  String get resultRequiredDocumentsTitle;

  /// Heads the step-by-step guidance. Distinct from
  /// [resultActionRequiredTitle], which is *what* to do rather than *how*.
  String get resultInstructionsTitle;

  /// Opens the full explanation — «عرض شرح الورقة بالتفصيل».
  String get resultShowExplanation;

  /// Opens what was actually read off the paper. Always available, whatever
  /// the analysis made of it (UX rule §5.12).
  String get resultShowExtractedText;

  /// The standing caution over that text: it is a machine reading, not the
  /// paper itself.
  String get resultExtractedTextWarning;

  /// Copies the block of text under it.
  String get actionCopy;

  /// Reads the extracted text aloud.
  String get resultListenToText;

  /// Said above a result the analysis only half understood. It names the gap
  /// rather than hiding it — a partial result is still useful, but the user
  /// has to know which parts to check.
  String get resultPartialBanner;

  /// The paper was read, but this kind of document cannot be explained
  /// responsibly. The text and the reader are still offered.
  String get analysisUnsupportedTitle;
  String get analysisUnsupportedMessage;

  /// Reads the extracted text aloud from a state screen, where there is no
  /// surrounding text to lean on.
  String get resultListenToExtractedText;

  /// Leaves a dead end by photographing a different paper.
  String get analysisCaptureAnother;

  /// The text-only fallback page: what was read, with no explanation.
  String get extractedTextOnlyTitle;
  String get extractedTextOnlyNote;

  /// What kind of paper this is — the chip above the result's title.
  ///
  /// Finer-grained than the `documentCategory*` names, which label the four
  /// filters on Home and in the documents list.
  String get documentKindInvoice;
  String get documentKindReceipt;
  String get documentKindAppointment;
  String get documentKindGovernment;
  String get documentKindExam;
  String get documentKindMedical;
  String get documentKindLegal;
  String get documentKindFinancial;
  String get documentKindEducational;
  String get documentKindOther;

  /// How an uncertain value is labelled (API_CONTRACT §30.5). Confidence is
  /// per field, so these sit on the value they are about — never on the
  /// document as a whole.
  String get confidenceReview;
  String get confidenceUncertain;
}
