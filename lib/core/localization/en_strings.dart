import 'app_strings.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// English strings. Drafted by the agent for review (CLAUDE.md locked decision).
final class EnStrings implements AppStrings {
  const EnStrings();

  @override
  String get appName => 'What Does My Paper Say?';

  @override
  String get appTagline => 'Snap the paper and see what matters.';

  @override
  String get bootstrapErrorTitle => 'We couldn\'t start';

  @override
  String get bootstrapErrorMessage =>
      'Something went wrong while getting things ready. Please try again.';

  @override
  String get bootstrapStageSession => 'Getting things ready';

  @override
  String get bootstrapStageConfig => 'Loading settings';

  @override
  String get bootstrapStageCleanup => 'Clearing temporary files';

  @override
  String get bootstrapStageReminders => 'Checking reminders';

  @override
  String get bootstrapStageUsage => 'Updating today\'s balance';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionOk => 'OK';

  @override
  String get actionBack => 'Back';

  @override
  String get actionSave => 'Save';

  @override
  String get actionShare => 'Share';

  @override
  String get actionDelete => 'Delete';

  @override
  String get stateLoading => 'One moment…';

  @override
  String get stateEmpty => 'Nothing here yet';

  @override
  String get stateErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get onboardingTitle => 'Understand your paper in simple steps';

  @override
  String get onboardingSubtitle =>
      'Photograph the everyday printed papers you get — an appointment, a '
      'bill, a government or school letter — and we will help you understand '
      'what matters in them.';

  @override
  String get onboardingKindAppointment => 'Appointment or booking';

  @override
  String get onboardingKindInvoice => 'Bill';

  @override
  String get onboardingKindGovernment => 'Government paper';

  @override
  String get onboardingKindEducation => 'School paper';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get privacyTitle => 'Your privacy matters';

  @override
  String get privacyPointExtractText =>
      "When you're online, we send the photo of your paper to an outside "
      "service that reads the text from it. We don't keep the photo, but "
      'that service may keep it for a while, and its staff may review it to '
      'improve their service. Without internet, the photo is read only on '
      'your phone.';

  @override
  String get privacyPointTextOnly =>
      'We send your paper\'s text encrypted to an analysis service so we can '
      'understand it, and we do not keep the text.';

  @override
  String get privacyPointImageOptIn =>
      'The photo is saved on your phone only if you agree to it.';

  @override
  String get privacyPointDeleteAnytime =>
      'You can delete your data at any time.';

  @override
  String get privacyAgree => 'Agree and start';

  @override
  String get homeGreetingTitle => 'Hello — got a paper you need explained?';

  @override
  String get homeGreetingSubtitle =>
      'Photograph it or pick it from your phone, and we will walk you through '
      'what matters.';

  @override
  String get homeScanTitle => 'Photograph your paper';

  @override
  String get homeScanSubtitle => 'Tap to open the camera';

  @override
  String get homePickImage => 'Choose a photo from your phone';

  @override
  String get homeImagePrivacyNote =>
      'Your photo is saved on your phone only if you agree.';

  @override
  String homeUsageRemaining(int remaining) => switch (remaining) {
    <= 0 => 'You have used up today\'s analyses.',
    1 => 'You have 1 analysis left today.',
    _ => 'You have $remaining analyses left today.',
  };

  @override
  String get cameraPermissionTitle => 'Allow camera access';

  @override
  String get cameraPermissionMessage =>
      'We need the camera so you can photograph the paper and understand what '
      'it says.';

  @override
  String get cameraPermissionBlockedMessage =>
      'The camera is turned off in your phone settings. Open settings and '
      'allow the camera to photograph your paper.';

  @override
  String get cameraPermissionAllow => 'Allow camera';

  @override
  String get cameraPermissionOpenSettings => 'Open settings';

  @override
  String get cameraPermissionPickInstead => 'Choose a photo instead';

  @override
  String get cameraOpening => 'Opening the camera…';

  @override
  String get cameraFlashOff => 'Flash: off';

  @override
  String get cameraFlashAuto => 'Flash: auto';

  @override
  String get cameraFlashOn => 'Flash: on';

  @override
  String get cameraFocusHint => 'Tap the paper to bring it into focus';

  @override
  String get cameraPickFromPhone => 'Choose a photo from your phone';

  @override
  String get cameraShutterLabel => 'Take photo';

  @override
  String get cameraCaptureErrorTitle => 'We could not open the camera';

  @override
  String get cameraCaptureErrorMessage =>
      'Something went wrong with the camera. Try again, or go back and choose '
      'a photo from your phone.';

  @override
  String get galleryOpening => 'Opening your photos…';

  @override
  String get galleryErrorTitle => 'We could not open your photos';

  @override
  String get galleryErrorMessage =>
      'Something went wrong opening your photos. Try again.';

  @override
  String get previewTitle => 'Crop the photo';

  @override
  String get previewHint => 'Make sure all the text shows before you continue.';

  @override
  String get previewUseImage => 'Use this photo';

  @override
  String get previewRetake => 'Retake';

  @override
  String get previewRotateLabel => 'Rotate the photo';

  @override
  String get previewProcessing => 'Preparing the photo…';

  @override
  String get previewErrorMessage =>
      'We could not prepare the photo. Try again.';

  @override
  String get qualityAlertTitle => 'The photo could be clearer';

  @override
  String get qualityAlertMessage =>
      'A clearer photo helps us read the text correctly. Try again in better '
      'light, or continue if the text is visible.';

  @override
  String get qualityAlertRetake => 'Retake the photo';

  @override
  String get qualityAlertContinue => 'Continue anyway';

  @override
  String get homeEmptyTitle => 'Start by photographing your first paper.';

  @override
  String get homeUpcomingReminderTitle => 'Coming up';

  @override
  String get homeRecentDocumentsTitle => 'Recent documents';

  @override
  String get timeAm => 'AM';

  @override
  String get timePm => 'PM';

  @override
  String monthName(int month) => _monthNames[month - 1];

  // English keeps the ISO code: "750 EGP" is how the figure is written here,
  // and spelling out "Egyptian pounds" beside every amount reads as noise.
  @override
  String currencyName(String code) => code;

  @override
  String reminderDueToday(String time) => 'Today at $time';

  @override
  String reminderDueTomorrow(String time) => 'Tomorrow at $time';

  @override
  String reminderDueOn(String date, String time) => 'On $date at $time';

  @override
  String get actionView => 'View';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get documentCategoryAppointment => 'Appointment';

  @override
  String get documentCategoryInvoice => 'Bill';

  @override
  String get documentCategoryGovernment => 'Government';

  @override
  String get documentCategoryEducation => 'School';

  @override
  String get documentCategoryOther => 'Other';

  @override
  String get documentStoredResultOnly => 'Result only';

  @override
  String get documentStoredWithImage => 'Result and photo';

  @override
  String get documentSaved => 'Saved to your documents — without the photo';

  @override
  String get documentSavedWithImage =>
      'Saved to your documents — with the photo';

  @override
  String get documentSaveFailed => "Couldn't save this paper. Try again.";

  @override
  String get saveModeSectionLabel => 'What do you want to save?';

  @override
  String get saveModeResultOnlyTitle => 'Result only';

  @override
  String get saveModeResultOnlySubtitle =>
      'We save the summary and details, without the photo.';

  @override
  String get saveModeWithImageTitle => 'Result and photo';

  @override
  String get saveModeWithImageSubtitle =>
      'We save the summary, details and an encrypted copy of the photo on your device.';

  @override
  @override
  String get documentsEmptyTitle => "You haven't saved any documents yet";

  @override
  String get documentsEmptySubtitle =>
      "A paper's result shows up here once you save it.";

  @override
  String get documentsEmptyCta => 'Photograph your first paper';

  @override
  String get documentsListErrorTitle =>
      "Couldn't load your documents right now.";

  @override
  String get documentsSearchHint => 'Search by document name';

  @override
  String get documentsSearchNoResultsTitle => 'No matches for your search';

  @override
  String get documentsSearchNoResultsSubtitle =>
      'Try a different word or check the spelling.';

  @override
  String get documentsFilterAll => 'All';

  @override
  String get documentsFilterAppointment => 'Appointments';

  @override
  String get documentsFilterInvoice => 'Bills';

  @override
  String get documentsFilterGovernment => 'Government';

  @override
  String get documentsFilterEducation => 'Education';

  @override
  String get documentsFilterOther => 'Other';

  @override
  String get documentDetailsTitle => 'Document details';

  @override
  String get documentDetailsNotFoundTitle => "This document isn't there";

  @override
  String get documentDetailsNotFoundMessage => 'It may have been deleted.';

  @override
  String get documentDetailsErrorTitle => "Couldn't open the document";

  @override
  String get documentDetailsErrorMessage =>
      'Something went wrong loading it. Try again.';

  @override
  String get documentDetailsBackToList => 'Back to documents';

  @override
  String get documentImageLabel => 'Document image';

  // Document notes (F08-T09)
  @override
  String get documentNoteHeading => 'My note';
  @override
  String get documentNoteEmpty => 'No note added yet.';
  @override
  String get documentNoteAdd => 'Add a note';
  @override
  String get documentNoteEdit => 'Edit';
  @override
  String get documentNoteDelete => 'Delete note';
  @override
  String get documentNoteHint => 'Add a note to help you remember this paper.';
  @override
  String get documentNoteSave => 'Save note';
  @override
  String get documentNoteDeleteConfirmTitle => 'Delete note?';
  @override
  String get documentNoteDeleteConfirmMessage =>
      "Once deleted, the note can't be recovered.";
  @override
  String get documentNoteSaved => 'Note saved.';
  @override
  String get documentNoteDeleted => 'Note deleted.';
  @override
  String get documentNoteError => "Couldn't save the note. Try again.";

  @override
  String get documentEditTitle => 'Edit title';
  @override
  String get documentEditCategory => 'Edit category';
  @override
  String get documentEditTitleHeading => 'Edit title';
  @override
  String get documentEditTitleHint => 'Enter a new title for the document.';
  @override
  String get documentEditTitleSave => 'Save title';
  @override
  String get documentEditCategoryHeading => 'Edit category';
  @override
  String get documentTitleUpdated => 'Title updated.';
  @override
  String get documentCategoryUpdated => 'Category updated.';
  @override
  String get documentUpdateError => "Couldn't update the document. Try again.";

  // Document delete (F08-T11)
  @override
  String get documentDeleteAction => 'Delete document';
  @override
  String get documentDeleteConfirmTitle => 'Delete document?';
  @override
  String get documentDeleteConfirmMessage =>
      "Once deleted, the document can't be recovered.";
  @override
  String get documentDeleted => 'Document deleted.';
  @override
  String get documentDeleteError => "Couldn't delete the document. Try again.";

  @override
  String get navHome => 'Home';

  @override
  String get navDocuments => 'My documents';

  @override
  String get navReminders => 'Reminders';

  @override
  String get navSettings => 'Settings';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsLanguageLabel => 'App language';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsPrivacySection => 'Privacy';

  @override
  String get settingsAnalysisConsentLabel =>
      'Allow sending the text for analysis';

  @override
  String get settingsProcessingModeLabel => 'Paper processing method';

  @override
  String get settingsProcessingModeSmartAnalysis => 'Smart analysis';

  @override
  String get settingsProcessingModeTextOnly => 'Text extraction only';

  @override
  String get settingsProcessingModeSmartAnalysisDescription =>
      'The paper is read and analysed to highlight what matters';

  @override
  String get settingsProcessingModeTextOnlyDescription =>
      'Only extract the text — nothing leaves your phone';

  // Display / Accessibility (F11-T05)
  @override
  String get settingsDisplaySection => 'Display';

  @override
  String get settingsTextSizeLabel => 'Text size';

  @override
  String get settingsTextSizeNormal => 'Normal';

  @override
  String get settingsTextSizeLarge => 'Large';

  @override
  String get settingsTextSizeVeryLarge => 'Very large';

  @override
  String get settingsTextSizeNormalDescription => "The app's default text size";

  @override
  String get settingsTextSizeLargeDescription =>
      'A bit bigger — easier to read';

  @override
  String get settingsTextSizeVeryLargeDescription =>
      'The largest size — for when you need the clearest text';

  // Accessibility (F11-T06)
  @override
  String get settingsAccessibilitySection => 'Accessibility';

  @override
  String get settingsHighContrastLabel => 'High contrast';

  // Audio & reading defaults (F11-T07)
  @override
  String get settingsAudioSection => 'Audio & reading';

  @override
  String get settingsAudioSpeedLabel => 'Default reading speed';

  @override
  String get settingsAudioVoiceLabel => 'Reading voice';

  @override
  String get settingsAudioVoiceDescription =>
      'Available voices depend on your phone\'s own settings.';

  @override
  String get settingsAudioVoiceDefault => 'Default voice';

  @override
  String get settingsAudioPreviewLabel => 'Preview voice';

  @override
  String get settingsAudioPreviewSample =>
      'Hi, this is the War2aty app speaking.';

  @override
  String get settingsAudioPreviewFailedFeedback =>
      'Could not play the voice sample right now.';

  @override
  String get settingsAudioResumeLabel => 'Resume reading from last position';

  // Permissions (F11-T08)
  @override
  String get settingsPermissionsSection => 'Permissions & notifications';
  @override
  String get settingsCameraPermissionLabel => 'Camera permission';
  @override
  String get settingsPermissionGranted => 'Allowed';
  @override
  String get settingsPermissionDenied => 'Not allowed';
  @override
  String get settingsPermissionBlocked => 'Blocked';
  @override
  String get settingsOpenCameraSettingsLabel => 'Open camera settings';

  // Permissions (F11-T09)
  @override
  String get settingsNotificationPermissionLabel => 'Notification permission';
  @override
  String get settingsOpenNotificationSettingsLabel =>
      'Open notification settings';

  // Notification privacy (F11-T10)
  @override
  String get settingsNotificationPrivacyLabel =>
      'Hide sensitive details on the lock screen';
  @override
  String get settingsNotificationPrivacyDescription =>
      "Only the reminder's name and time will show, not your note.";

  @override
  String get settingsDeleteAllDocumentsLabel => 'Delete all documents';
  @override
  String get settingsDeleteAllAppDataLabel => 'Delete all app data';
  @override
  String get settingsDeleteAllRemindersLabel => 'Delete all reminders';

  @override
  String get settingsDeleteAllConfirmAction => 'Delete all';

  @override
  String get settingsDeleteAllDocumentsConfirmTitle => 'Delete all documents?';
  @override
  String get settingsDeleteAllDocumentsConfirmMessage =>
      'This will permanently delete every saved document and its picture — '
      "you won't be able to get them back.";
  @override
  String get settingsDeleteAllDocumentsSuccess => 'All documents deleted.';
  @override
  String get settingsDeleteAllDocumentsError =>
      "Couldn't delete the documents. Try again.";

  @override
  String get settingsDeleteAllAppDataConfirmTitle => 'Delete all app data?';
  @override
  String get settingsDeleteAllAppDataConfirmMessage =>
      'This will permanently delete every document and reminder, and reset '
      'every app setting to its default.';
  @override
  String get settingsDeleteAllAppDataSuccess => 'All app data deleted.';
  @override
  String get settingsDeleteAllAppDataError =>
      "Couldn't delete the app data. Try again.";

  @override
  String get settingsDeleteAllRemindersConfirmTitle => 'Delete all reminders?';
  @override
  String get settingsDeleteAllRemindersConfirmMessage =>
      'This will permanently delete upcoming, missed, and completed '
      'reminders.';
  @override
  String get settingsDeleteAllRemindersSuccess => 'All reminders deleted.';
  @override
  String get settingsDeleteAllRemindersError =>
      "Couldn't delete the reminders. Try again.";

  @override
  String get settingsAboutSection => 'About';

  @override
  String get settingsPrivacyPolicyLabel => 'Privacy policy';

  @override
  String get settingsSupportedDocumentTypesLabel => 'Supported paper types';

  @override
  String get settingsUsageLimitLabel => 'Usage limit';

  @override
  String settingsUsageLimitValue(int used, int limit) => '$used / $limit';

  @override
  String get settingsUsageLimitUnavailable => 'Not available right now';

  @override
  String settingsVersionLabel(String version) => 'Version $version';

  // OCR processing
  @override
  String get ocrProcessing => 'Reading the document...';
  @override
  String get ocrErrorTitle => 'Something went wrong';
  @override
  String get ocrErrorMessage =>
      'Could not read the document. Try again or pick another image.';
  @override
  String get ocrNoTextTitle => 'No text found';
  @override
  String get ocrNoTextMessage =>
      'The image does not contain readable text. Try taking a clearer photo.';
  @override
  String get ocrRetake => 'Retake';
  @override
  String get ocrPickAnother => 'Pick another';

  // OCR extracted text
  @override
  String get ocrExtractedTextTitle => 'Extracted text';
  @override
  String get ocrCopyText => 'Copy text';
  @override
  String get ocrTextCopied => 'Copied';
  @override
  String get ocrContinue => 'Continue';

  // OCR candidate labels
  @override
  String get ocrDatesSection => 'Dates';
  @override
  String get ocrTimesSection => 'Times';
  @override
  String get ocrAmountsSection => 'Amounts';
  @override
  String get ocrPhonesSection => 'Phone numbers';
  @override
  String get ocrReferencesSection => 'Reference numbers';

  // OCR field review
  @override
  String get ocrReviewTitle => 'Review information';
  @override
  String get ocrReviewSubtitle =>
      'These fields need verification — make sure they are correct.';
  @override
  String get ocrReviewDone => 'Done';

  @override
  String get ocrOnlineReviewTitle => 'Text read from the document';
  @override
  String get ocrOnlineReviewSubtitle =>
      'Review the text and fix anything wrong before analysis';
  @override
  String get ocrOnlineLoading => 'Reading the document...';
  @override
  String get ocrOnlineAnalyze => 'Analyze document';
  @override
  String get ocrOnlinePoorQuality =>
      "We couldn't read clear text from the document. Try photographing it "
      'again with better lighting.';
  @override
  String get ocrOnlineShowImage => 'Show original image';
  @override
  String get ocrOnlineHideImage => 'Hide image';
  @override
  String get ocrOnlineAmbiguityNotice => 'Some information may need review';

  @override
  String get ocrOfflineQualityWarning =>
      'Results may be less accurate because the scan was done offline';
  @override
  String get ocrOnlineFallbackWarning =>
      "Online reading isn't available right now, so we read the paper on "
      'your phone. Results may be less accurate — check the text before '
      'continuing.';
  @override
  String get ocrListenToText => 'Listen to text';

  // Analysis — while it runs
  @override
  String get analysisRunningStatus =>
      'Preparing your explanation, just a few seconds';
  @override
  String get analysisWaitStepType => 'Checking the type of paper';
  @override
  String get analysisWaitStepActions => 'Checking what you need to do';
  @override
  String get analysisWaitStepDates => 'Looking for any dates';
  @override
  String get analysisWaitStillSeconds =>
      'A few more seconds, this paper has a lot of detail';
  @override
  String get analysisWaitReviewing => 'Checking everything carefully for you';
  @override
  String get analysisWaitTakingLonger =>
      'Taking longer than usual, still working on it';
  @override
  String get analysisWaitReady => 'Ready!';
  @override
  String get analysisWaitHint => 'Stay with us, this takes a few seconds';
  @override
  String get analysisWaitHintLong => 'Nothing for you to do, we will carry on';
  @override
  String get analysisWaitHintReady => 'Opening your explanation now';
  @override
  String get analysisWaitLongAnnouncement =>
      'This paper is taking longer than usual, still working on it';
  @override
  String get analysisWaitReadyAnnouncement => 'Your explanation is ready';

  // Analysis result
  @override
  String get analysisResultTitle => 'Analysis result';
  @override
  String get analysisResultBackLabel => 'Back';
  @override
  String get analysisFailedTitle => 'Something went wrong while explaining';
  @override
  String get analysisFailedMessage =>
      'We could not finish explaining this paper right now. We still have the '
      'text we read, so you can try again without photographing it again.';
  @override
  String get analysisFailedTipsTitle => 'If it keeps happening';
  @override
  String get analysisFailedTipWait => 'Wait a minute and try again';
  @override
  String get analysisFailedTipConnection =>
      'Make sure your internet is working well';
  @override
  String get analysisFailedTipReadText =>
      'Meanwhile, you can read the text on the paper';
  @override
  String get analysisNoInternetTitle => 'You are offline right now';
  @override
  String get analysisNoInternetMessage =>
      'We need the internet to explain this paper. Its text has already been '
      'read, so you will not need to photograph it again.';
  @override
  String get analysisNoInternetTipsTitle => 'Try these';
  @override
  String get analysisNoInternetTipWifi => 'Turn on Wi-Fi or mobile data';
  @override
  String get analysisNoInternetTipAirplane => 'Make sure airplane mode is off';
  @override
  String get analysisNoInternetTipSignal =>
      'If the signal is weak, move closer to the router or try another spot';
  @override
  String get analysisStepPhoto => 'Photo';
  @override
  String get analysisStepReading => 'Reading';
  @override
  String get analysisStepExplanation => 'Explanation';
  @override
  String get analysisStepDone => 'Done';
  @override
  String get analysisStepWaitingForInternet => 'Waiting for internet';
  @override
  String get analysisStepNotFinished => 'Not finished';
  @override
  String analysisStepsSemantics(String explanation) =>
      'Photo done, reading done, explanation: $explanation';
  @override
  String get analysisLimitReachedTitle => "You have used today's analyses";
  @override
  String get analysisLimitReachedMessage =>
      "You have used all of today's analyses. $_limitTextStillThere";
  @override
  String analysisLimitReachedMessageWithLimit(int limit) => limit == 1
      ? 'You get 1 smart analysis a day, and you have used it. '
            '$_limitTextStillThere'
      : 'You get $limit smart analyses a day, and you have used them all. '
            '$_limitTextStillThere';
  static const _limitTextStillThere =
      "The paper's text is still here for you to read now.";
  @override
  String get analysisLimitResetsInLabel => 'Your analyses renew in';
  @override
  String analysisLimitResetsIn(int hours, int minutes) => [
    if (hours > 0) hours == 1 ? '1 hour' : '$hours hours',
    if (minutes > 0) minutes == 1 ? '1 minute' : '$minutes minutes',
  ].join(' and ');
  @override
  String get analysisLimitResetTime => 'At midnight, Egypt time';
  @override
  String get analysisLimitRenewed => 'Your analyses have renewed';
  @override
  String analysisLimitUsedOf(int limit) => 'Used $limit of $limit today';
  @override
  String get analysisLimitTipsTitle => 'What you can do now';
  @override
  String get analysisLimitTipReadText =>
      "Read and copy the paper's text. It does not use an analysis";
  @override
  String get analysisLimitTipTomorrow =>
      'Keep the paper and photograph it again tomorrow, once your analyses '
      'renew';
  @override
  String get analysisBackToHome => 'Back to home';
  @override
  String get resultListen => 'Listen';
  @override
  String get resultSavePaper => 'Save paper';
  @override
  String get resultSummaryLabel => 'Document summary';
  @override
  String get resultActionRequiredTitle => 'What you need to do';
  @override
  String get resultActionInferred => 'Worked out from the paper';
  @override
  String get resultWarningsTitle => 'Important';
  @override
  String get resultKeyInformationTitle => 'Key information';
  @override
  String resultCopyValueLabel(String label) => 'Copy $label';
  @override
  String get resultDatesTitle => 'Dates and appointments';
  @override
  String get resultDateNoTime => 'The paper gives no time.';
  @override
  String get resultCreateReminder => 'Create a reminder';
  @override
  String get resultPickDateTitle => 'Which date do you want to remember?';
  @override
  String get resultPickDateMessage =>
      'This paper has more than one date. Pick the one to be reminded about.';
  @override
  String get resultDateReminderWorthy => 'Worth a reminder';
  @override
  String get resultDateDisplayOnly => 'For reference only';
  @override
  String get resultAmountsTitle => 'Amounts';
  @override
  String get resultRequiredDocumentsTitle => 'What to bring';
  @override
  String get resultInstructionsTitle => 'Step by step';
  @override
  String get resultShowExplanation => 'Explain this paper in full';
  @override
  String get resultShowExtractedText => 'Show the text we read';
  @override
  String get resultExtractedTextWarning =>
      'The text we read may contain mistakes.';
  @override
  String get actionCopy => 'Copy';
  @override
  String get resultListenToText => 'Listen';
  @override
  String get resultPartialBanner =>
      'We understood part of this paper. Some details need your review.';
  @override
  String get analysisUnsupportedTitle => 'We could not explain this paper';
  @override
  String get analysisUnsupportedMessage =>
      'Its text may not be clear enough, or it may be a kind of paper we do '
      'not explain yet. Try photographing it again in good light, or '
      'photograph one of the kinds below.';
  @override
  String get analysisAttemptNotCounted =>
      "This attempt did not count toward today's analyses";
  @override
  String get analysisExtractedTextCardSubtitle =>
      'The text we read from the paper, ready to copy';
  @override
  String get analysisSupportedDocumentsTitle => 'Papers we explain';
  @override
  String get analysisSupportedInvoices => 'Bills and receipts';
  @override
  String get analysisSupportedInvoicesExamples =>
      'Electricity, water, gas, phone';
  @override
  String get analysisSupportedAppointments => 'Appointments';
  @override
  String get analysisSupportedAppointmentsExamples =>
      'Doctor, booking, interview';
  @override
  String get analysisSupportedGovernment => 'Government papers';
  @override
  String get analysisSupportedGovernmentExamples => 'Notices, official letters';
  @override
  String get analysisSupportedEducation => 'School papers';
  @override
  String get analysisSupportedEducationExamples =>
      'Exam results, school letters';
  @override
  String get analysisSupportedOther => 'Other papers';
  @override
  String get analysisSupportedOtherExamples =>
      'Medical reports, legal papers, bank letters';
  @override
  String get analysisPickFromGallery => 'Pick from photos';
  @override
  String get analysisConsentDeclinedTitle => 'Smart explanation is off';
  @override
  String get analysisConsentDeclinedMessage =>
      'You turned off "Allow sending the text for analysis" in Settings, and '
      'that is your choice. So we could not explain this paper, but its text '
      'is here for you to read.';
  @override
  String get analysisConsentValueTitle => "Turn it on and we'll tell you:";
  @override
  String get analysisConsentValueType => 'What the paper is';
  @override
  String get analysisConsentValueKeyPoints => 'What matters in it';
  @override
  String get analysisConsentValueRequired => 'What you need to do';
  @override
  String get analysisConsentValueDates => 'Dates worth a reminder';
  @override
  String get analysisConsentDeclinedOpenSettings => 'Open Settings';
  @override
  String get analysisCaptureAnother => 'Photograph another';
  @override
  String get extractedTextOnlyTitle => 'The text we read';
  @override
  String get extractedTextOnlyNote =>
      'The text we read may contain mistakes, and no explanation is available '
      'in this mode.';

  // Document kinds
  @override
  String get documentTypeLabel => 'Document type';
  @override
  String get documentKindInvoice => 'Invoice';
  @override
  String get documentKindReceipt => 'Receipt';
  @override
  String get documentKindAppointment => 'Appointment';
  @override
  String get documentKindGovernment => 'Government';
  @override
  String get documentKindExam => 'Exam result';
  @override
  String get documentKindMedical => 'Medical report';
  @override
  String get documentKindLegal => 'Legal document';
  @override
  String get documentKindFinancial => 'Financial document';
  @override
  String get documentKindEducational => 'Educational';
  @override
  String get documentKindOther => 'Other';

  // Confidence
  @override
  String get confidenceReview => 'Please double-check';
  @override
  String get confidenceUncertain => 'Uncertain reading';

  // Reminder form (F09-T02)
  @override
  String get reminderFormTitleLabel => 'Reminder title';
  @override
  String get reminderFromDocumentInfoHeading => 'From the document';
  @override
  String get reminderEventDateLabel => 'Event date';
  @override
  String get reminderEventTimeLabel => 'Event time';
  @override
  String get reminderEventTimeMissing => 'Not on the document';
  @override
  String get reminderAlertsSectionLabel => 'Alert times';
  @override
  String get reminderAddAnotherAlert => 'Add another alert';
  @override
  String get reminderRemoveAlertLabel => 'Remove this alert';
  @override
  String get reminderNoteLabel => 'Note';
  @override
  String get reminderNoteHint => 'Add anything you need to remember.';
  @override
  String get reminderLinkedDocumentSectionLabel => 'Link a saved document';
  @override
  String get reminderLinkedDocumentValueLabel => 'Linked to';
  @override
  String get reminderSaveAction => 'Save reminder';
  @override
  String get reminderAlertOffsetThreeDays => '3 days before';
  @override
  String get reminderAlertOffsetOneDay => '1 day before';
  @override
  String get reminderAlertOffsetTwoHours => '2 hours before';
  @override
  String get reminderAlertOffsetAtEventTime => 'At the event time';
  @override
  String get reminderAlertOffsetCustom => 'Custom time';
  @override
  String get reminderAlertPickerTitle => 'Choose an alert time';
  @override
  String get reminderMissingEventTimeWarning =>
      'The document did not give a time. Choose the right time for the alert.';
  @override
  String reminderSuggestedAlertTime(String time) =>
      'Suggested: remind me at $time';
  @override
  String get reminderCreateScreenTitle => 'Create reminder';
  @override
  String get reminderAddAction => 'Add reminder';
  @override
  String get reminderSuccessTitle => 'Reminder created.';
  @override
  String get reminderSuccessViewAction => 'View reminder';
  @override
  String get reminderManualTitleHint => 'e.g. Pay the electricity bill';
  @override
  String get reminderDateLabel => 'Date';
  @override
  String get reminderDatePickHint => 'Choose a date';
  @override
  String get reminderTimeLabel => 'Time';
  @override
  String get reminderTimePickHint => 'Choose a time';
  @override
  String get reminderNotifPermTitle => 'Allow notifications';
  @override
  String get reminderNotifPermMessage =>
      'So we can remind you at the time you chose.';
  @override
  String get reminderNotifPermAllow => 'Allow notifications';
  @override
  String get reminderNotifPermSaveWithout => 'Save without a notification';
  @override
  String get reminderNotificationChannelName => 'Reminders';
  @override
  String reminderNotificationDays(int days) =>
      days == 1 ? '1 day' : '$days days';
  @override
  String reminderNotificationHours(int hours) =>
      hours == 1 ? 'an hour' : '$hours hours';
  @override
  String reminderNotificationMinutes(int minutes) =>
      minutes == 1 ? 'a minute' : '$minutes minutes';
  @override
  String reminderNotificationTitleDaysLeft(String days, String title) =>
      'In $days: $title';
  @override
  String reminderNotificationTitleTomorrow(String title) =>
      'Due tomorrow: $title';
  @override
  String reminderNotificationTitleIn(String span, String title) =>
      'In $span: $title';
  @override
  String reminderNotificationTitleToday(String title) => 'Today: $title';
  @override
  String reminderNotificationTitleNow(String title) => 'Now: $title';
  @override
  String reminderNotificationBodyTimeAndNote(String time, String note) =>
      '$time • $note';
  @override
  String reminderNotificationBodyAt(String time) => 'At $time';
  @override
  String get reminderNotificationTapToContinue => 'Tap to continue';
  @override
  String get reminderListTitle => 'Reminders';
  @override
  String get reminderTabUpcoming => 'Upcoming';
  @override
  String get reminderTabMissed => 'Missed';
  @override
  String get reminderTabCompleted => 'Completed';
  @override
  String get reminderEmptyTitle => 'No reminders yet';
  @override
  String get reminderEmptySubtitle =>
      'Add one by hand, or create one from a date already on a document.';
  @override
  String get reminderEmptyScanCta => 'Photograph a paper';
  @override
  String get reminderEmptyMissedTitle => 'No missed reminders.';
  @override
  String get reminderEmptyCompletedTitle =>
      'Reminders you complete will show up here.';
  @override
  String get reminderStatusUpcoming => 'Upcoming';
  @override
  String get reminderStatusMissed => 'Missed';
  @override
  String get reminderStatusCompleted => 'Done';
  @override
  String get reminderCompleteAction => 'Mark done';
  @override
  String get reminderSnoozeAction => 'Snooze';
  @override
  String get reminderListErrorTitle =>
      "We couldn't load your reminders right now.";

  // Reminder details (F09-T12)
  @override
  String get reminderDetailsTitle => 'Reminder details';
  @override
  String get reminderDetailsDateLabel => 'Date';
  @override
  String get reminderDetailsTimeLabel => 'Time';
  @override
  String get reminderDetailsAlertLabel => 'Alert time';
  @override
  String get reminderDetailsDescriptionLabel => 'Note';
  @override
  String get reminderDetailsLinkedDocumentLabel => 'View linked document';
  @override
  String get reminderDetailsNotFoundTitle => 'Reminder not found';
  @override
  String get reminderDetailsNotFoundMessage =>
      'This reminder may have been deleted, or the link is invalid.';
  @override
  String get reminderDetailsErrorTitle => 'Something went wrong';
  @override
  String get reminderDetailsErrorMessage =>
      "We couldn't show this reminder right now. Please try again.";
  @override
  String get reminderDetailsBackToList => 'Back to reminders';
  @override
  String get reminderDetailsCompleteAction => 'Mark done';
  @override
  String get reminderDetailsSnoozeAction => 'Snooze';
  @override
  String get reminderDetailsEditAction => 'Edit';
  @override
  String get reminderDetailsDeleteAction => 'Delete';

  // Snooze sheet (F09-T12)
  @override
  String get reminderSnoozeSheetTitle => 'Snooze reminder';
  @override
  String get reminderSnoozeSheetSubtitle =>
      'Snoozing changes the alert time only, not the original event date.';
  @override
  String get reminderSnoozeOptionOneHour => 'In 1 hour';
  @override
  String get reminderSnoozeOptionTomorrow => 'Tomorrow at the same time';
  @override
  String get reminderSnoozeOptionCustom => 'Choose a new time';

  // Delete confirmation sheet (F09-T12)
  @override
  String get reminderDeleteSheetTitle => 'Delete reminder?';
  @override
  String get reminderDeleteSheetMessage =>
      'This is permanent — you will not be able to get this reminder back.';
  @override
  String get reminderDeleteSheetConfirm => 'Delete';
  @override
  String get reminderDeleteSheetCancel => 'Cancel';

  // Action feedback (F09-T12)
  @override
  String get reminderCompletedFeedback => 'Marked as done.';
  @override
  String get reminderSnoozedFeedback => 'Reminder snoozed.';
  @override
  String get reminderDeletedFeedback => 'Reminder deleted.';
  @override
  String get reminderActionFailedFeedback =>
      'Something went wrong. Please try again.';

  // Audio reader mini-player (F10-T03)
  @override
  String get audioReaderSheetTitle => 'Listen to this paper';
  @override
  String get audioReaderModeSummary => 'Summary only';
  @override
  String get audioReaderModeSummaryAndKeyInformation =>
      'Summary and key information';
  @override
  String get audioReaderModeFull => 'Full explanation';
  @override
  String get audioReaderModeReadAll => 'Read entire screen';
  @override
  String get audioReaderModeExtractedText => 'Extracted text';
  @override
  String get audioReaderOptions => 'Options';
  @override
  String audioReaderNowReading(String mode) => 'Reading: $mode';
  @override
  String get audioReaderStartLabel => 'Start listening';
  @override
  String get audioReaderPauseLabel => 'Pause';
  @override
  String get audioReaderResumeLabel => 'Resume reading';
  @override
  String get audioReaderStopLabel => 'Stop reading';
  @override
  String get audioReaderFailedFeedback => 'Something went wrong. Try again.';
  @override
  String get audioReaderSpeedLabel => 'Reading speed';
}
