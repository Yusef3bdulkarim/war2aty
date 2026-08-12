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

  /// Confirms a save that kept the picture too (F08-T04) — its own copy
  /// rather than a shared one, so the user is told which happened.
  String get documentSavedWithImage;

  /// A save that did not go through. No detail: the user cannot act on a
  /// database error, only try again.
  String get documentSaveFailed;

  // Save-mode sheet (F08-T04) — the explicit choice between keeping the
  // result only and keeping the page picture too.
  String get saveModeSectionLabel;
  String get saveModeResultOnlyTitle;
  String get saveModeResultOnlySubtitle;
  String get saveModeWithImageTitle;
  String get saveModeWithImageSubtitle;

  // Documents list (F08-T05) — «مستنداتي». The screen heading reuses
  // [navDocuments] itself: the design gives the tab and the page it opens
  // the exact same Arabic word.
  /// Shown when nothing has been saved yet.
  String get documentsEmptyTitle;
  String get documentsEmptySubtitle;

  /// The way out of the empty state — mirrors the scan action elsewhere.
  String get documentsEmptyCta;

  /// The list could not be read. No detail: nothing here is actionable
  /// beyond trying again later, and the stream keeps listening on its own.
  String get documentsListErrorTitle;

  // Documents search (F08-T06) — filters the list above by title.
  /// Placeholder inside the empty search field.
  String get documentsSearchHint;

  /// Shown when a search matches nothing, in place of [documentsEmptyTitle].
  String get documentsSearchNoResultsTitle;
  String get documentsSearchNoResultsSubtitle;

  // Documents category filters (F08-T07) — the chip row above the list.
  // Plural, unlike the singular [documentCategoryInvoice] and its siblings
  // above, which label one document's badge rather than a whole filter.
  String get documentsFilterAll;
  String get documentsFilterAppointment;
  String get documentsFilterInvoice;
  String get documentsFilterGovernment;
  String get documentsFilterEducation;
  String get documentsFilterOther;

  // Document details (F08-T08) — the full record behind one list row.
  String get documentDetailsTitle;

  /// The document no longer resolves — deleted (F08-T11) since the list was
  /// opened, or a stale id. Not the same wording as [documentsListErrorTitle]:
  /// that one is a read failure, this one is "it isn't there any more".
  String get documentDetailsNotFoundTitle;
  String get documentDetailsNotFoundMessage;

  String get documentDetailsErrorTitle;
  String get documentDetailsErrorMessage;

  /// The way out of both states above.
  String get documentDetailsBackToList;

  // Document notes (F08-T09) — «ملاحظتي».
  /// Section heading above the note card.
  String get documentNoteHeading;

  /// Shown when no note has been added yet.
  String get documentNoteEmpty;

  /// The action that opens the note editor to write one.
  String get documentNoteAdd;

  /// The action that opens the note editor to change an existing one.
  String get documentNoteEdit;

  /// The action that removes the note. Shown alongside [documentNoteEdit].
  String get documentNoteDelete;

  /// Hint inside the text field while the user is writing.
  String get documentNoteHint;

  /// Confirms the note in the editor.
  String get documentNoteSave;

  /// Confirmation dialog when deleting a note.
  String get documentNoteDeleteConfirmTitle;
  String get documentNoteDeleteConfirmMessage;

  /// Snackbar feedback after a note action.
  String get documentNoteSaved;
  String get documentNoteDeleted;
  String get documentNoteError;

  // Document update (F08-T10) — title and category editing.
  /// Overflow menu item that opens the title editor.
  String get documentEditTitle;

  /// Overflow menu item that opens the category picker.
  String get documentEditCategory;

  /// Title of the rename sheet.
  String get documentEditTitleHeading;

  /// Hint inside the title text field.
  String get documentEditTitleHint;

  /// Confirms the new title in the editor.
  String get documentEditTitleSave;

  /// Title of the category picker sheet.
  String get documentEditCategoryHeading;

  /// Snackbar feedback after a successful title update.
  String get documentTitleUpdated;

  /// Snackbar feedback after a successful category update.
  String get documentCategoryUpdated;

  /// Snackbar feedback when an update fails.
  String get documentUpdateError;

  // Document delete (F08-T11) — permanent removal from the device.
  /// Overflow menu item that starts the delete flow.
  String get documentDeleteAction;

  /// Confirmation dialog title.
  String get documentDeleteConfirmTitle;

  /// Confirmation dialog body — warns the action is irreversible.
  String get documentDeleteConfirmMessage;

  /// Snackbar feedback after a successful delete.
  String get documentDeleted;

  /// Snackbar feedback when the delete fails.
  String get documentDeleteError;

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

  // Reminder form (F09-T02) — shared by "create from a document date"
  // (F09-T03) and "add manually" (F09-T04).
  String get reminderFormTitleLabel;

  /// Heads the read-only card showing what the paper said — only present
  /// when the reminder was created from a document's date.
  String get reminderFromDocumentInfoHeading;

  String get reminderEventDateLabel;
  String get reminderEventTimeLabel;

  /// Said in place of a time the paper never gave (F09-T06) — never a
  /// guessed hour.
  String get reminderEventTimeMissing;

  String get reminderAlertsSectionLabel;
  String get reminderAddAnotherAlert;

  /// Read by assistive technology on the small "×" next to an alert —
  /// [reminderAddAnotherAlert] says what adding one does, this says what
  /// removing one does.
  String get reminderRemoveAlertLabel;

  String get reminderNoteLabel;
  String get reminderNoteHint;

  String get reminderLinkedDocumentSectionLabel;
  String get reminderLinkedDocumentValueLabel;

  String get reminderSaveAction;

  /// Quick offsets the alert picker offers when the event has a known time
  /// (F09-T05) — a reminder is never scheduled without the user choosing one
  /// of these or [reminderAlertOffsetCustom].
  String get reminderAlertOffsetThreeDays;
  String get reminderAlertOffsetOneDay;
  String get reminderAlertOffsetTwoHours;
  String get reminderAlertOffsetAtEventTime;

  /// Picks an exact date and time by hand — the only option offered at all
  /// when the paper gave no event time (F09-T06), since there is nothing to
  /// offset from.
  String get reminderAlertOffsetCustom;

  String get reminderAlertPickerTitle;

  /// Shown instead of an alert list when the paper gave no event time
  /// (F09-T06) — says why there is nothing to offer relative to, rather than
  /// leaving the empty state unexplained.
  String get reminderMissingEventTimeWarning;

  /// A one-tap shortcut to a sensible default alert — [time] is already
  /// formatted, read the same way anywhere else a clock time is shown.
  String reminderSuggestedAlertTime(String time);

  // Reminder create-from-document (F09-T03) and manual (F09-T04) screen
  // titles, and the success screen after either saves.
  String get reminderCreateScreenTitle;

  /// Also the manual screen's own title — the design gives the header
  /// button and the screen it opens the exact same words.
  String get reminderAddAction;

  String get reminderSuccessTitle;
  String get reminderSuccessViewAction;

  // Manual reminder form (F09-T04) — its own required date/time pickers,
  // absent from the create-from-document form (F09-T03), which reads them
  // off the paper instead.
  String get reminderManualTitleHint;
  String get reminderDateLabel;
  String get reminderDatePickHint;
  String get reminderTimeLabel;
  String get reminderTimePickHint;

  // Notification permission sheet (F09-T09) — shown once, right before the
  // first reminder that would need an OS notification is saved.
  String get reminderNotifPermTitle;
  String get reminderNotifPermMessage;
  String get reminderNotifPermAllow;
  String get reminderNotifPermSaveWithout;

  /// The OS notification's own title/channel name (F09-T10) — distinct from
  /// [homeUpcomingReminderTitle], which heads a card inside the app; this one
  /// is read by the operating system itself, outside any locale-aware
  /// widget tree.
  String get reminderNotificationChannelName;

  /// Shown on the OS notification instead of the reminder's real title when
  /// sensitive details are hidden (F09-T14, default on) — never a specific
  /// amount, account number or name, whatever the reminder is about.
  String get reminderNotificationGenericTitle;

  // Reminders list (F09-T11) — «التذكيرات», the reminders tab.
  String get reminderListTitle;
  String get reminderTabUpcoming;
  String get reminderTabMissed;
  String get reminderTabCompleted;

  String get reminderEmptyTitle;
  String get reminderEmptySubtitle;

  /// The way out of [reminderEmptyTitle] besides [reminderAddAction] —
  /// mirrors the scan action Home and the documents list offer for the
  /// same "nothing yet" moment.
  String get reminderEmptyScanCta;

  String get reminderEmptyMissedTitle;
  String get reminderEmptyCompletedTitle;

  /// The list card's own status pill — also the details screen's (F09-T12).
  String get reminderStatusUpcoming;
  String get reminderStatusMissed;
  String get reminderStatusCompleted;

  /// The list card's own quick actions — wired in F09-T12; the card widget
  /// (F09-T11) already draws them whenever a callback is given.
  String get reminderCompleteAction;
  String get reminderSnoozeAction;

  /// Mirrors [documentsListErrorTitle] for the reminders list's own failed
  /// read.
  String get reminderListErrorTitle;

  // Reminder details screen (F09-T12) — «تفاصيل التذكير».
  String get reminderDetailsTitle;

  /// Row labels on the details screen.
  String get reminderDetailsDateLabel;
  String get reminderDetailsTimeLabel;
  String get reminderDetailsAlertLabel;
  String get reminderDetailsDescriptionLabel;

  /// The linked-document button — navigates to the document's details.
  String get reminderDetailsLinkedDocumentLabel;

  /// The detail screen's own not-found / error states — mirrors the document
  /// details screen's pair.
  String get reminderDetailsNotFoundTitle;
  String get reminderDetailsNotFoundMessage;
  String get reminderDetailsErrorTitle;
  String get reminderDetailsErrorMessage;
  String get reminderDetailsBackToList;

  /// Detail screen actions.
  String get reminderDetailsCompleteAction;
  String get reminderDetailsSnoozeAction;
  String get reminderDetailsEditAction;
  String get reminderDetailsDeleteAction;

  // Snooze sheet (F09-T12) — «تأجيل التذكير».
  String get reminderSnoozeSheetTitle;
  String get reminderSnoozeSheetSubtitle;
  String get reminderSnoozeOptionOneHour;
  String get reminderSnoozeOptionTomorrow;
  String get reminderSnoozeOptionCustom;

  // Delete confirmation sheet (F09-T12) — «حذف التذكير؟».
  String get reminderDeleteSheetTitle;
  String get reminderDeleteSheetMessage;
  String get reminderDeleteSheetConfirm;
  String get reminderDeleteSheetCancel;

  /// Snackbar feedback after actions.
  String get reminderCompletedFeedback;
  String get reminderSnoozedFeedback;
  String get reminderDeletedFeedback;
  String get reminderActionFailedFeedback;

  // Audio reader mini-player (F10-T03) — «الاستماع للورقة».
  String get audioReaderSheetTitle;

  /// The three modes offered from the result page. A fourth
  /// (`ReadingMode.extractedText`) exists too, but is only reached from the
  /// OCR-only fallback screens, which read it straight away rather than
  /// asking — there is no analysis there to summarise.
  String get audioReaderModeSummary;
  String get audioReaderModeSummaryAndKeyInformation;
  String get audioReaderModeFull;

  /// The fourth mode's own label, for the mini-player's «بيقرأ: …» line when
  /// reading [ReadingMode.extractedText] from a fallback screen — never
  /// offered as a choice in the sheet above.
  String get audioReaderModeExtractedText;

  /// Reopens the sheet above to change what is being read.
  String get audioReaderOptions;

  /// The mini-player's own line — «بيقرأ: {mode}».
  String audioReaderNowReading(String mode);

  /// Accessibility labels for the mini-player's icon-only controls.
  String get audioReaderStartLabel;
  String get audioReaderPauseLabel;
  String get audioReaderResumeLabel;
  String get audioReaderStopLabel;

  /// Snackbar feedback when the engine could not start or stop speaking
  /// (F10-T04). Not spelled out further — the same reasoning
  /// [reminderActionFailedFeedback] documents for itself.
  String get audioReaderFailedFeedback;

  /// The options sheet's speed row (F10-T06) — «سرعة القراءة». The pill
  /// labels themselves (`0.75x`, `1x`, …) are not localized; see
  /// `ReadingSpeed.label`.
  String get audioReaderSpeedLabel;
}
