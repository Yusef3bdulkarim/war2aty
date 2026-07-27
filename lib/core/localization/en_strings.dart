import 'app_strings.dart';

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
      'We read the text out of the photo so we can explain it.';

  @override
  String get privacyPointTextOnly =>
      'Only the extracted text is sent — never the photo itself.';

  @override
  String get privacyPointImageOptIn =>
      'The photo is not saved unless you agree to it.';

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
      'Your photo is not saved unless you agree to it.';

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
  String get cameraViewfinderHint => 'Keep the whole paper inside the frame.';

  @override
  String get cameraShutterLabel => 'Take photo';

  @override
  String get cameraCloseLabel => 'Close';

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
  String get navHome => 'Home';

  @override
  String get navDocuments => 'My documents';

  @override
  String get navReminders => 'Reminders';

  @override
  String get navSettings => 'Settings';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

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
}
