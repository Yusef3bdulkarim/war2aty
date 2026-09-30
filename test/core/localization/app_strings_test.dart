import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_strings.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';

/// Every member of [AppStrings], by name — each parameterised one called with
/// a representative argument. Both languages run through the same map, so
/// the parity and no-provider-name checks cover the whole interface.
///
/// 'covers every AppStrings member' below fails when a member is added to
/// the interface without an entry here (F20-T24: the old hand-kept list had
/// drifted to 104 of 385 members, leaving most copy unchecked).
final Map<String, String Function(AppStrings)> _accessors = {
  'appName': (s) => s.appName,
  'appTagline': (s) => s.appTagline,
  'bootstrapErrorTitle': (s) => s.bootstrapErrorTitle,
  'bootstrapErrorMessage': (s) => s.bootstrapErrorMessage,
  'bootstrapStageSession': (s) => s.bootstrapStageSession,
  'bootstrapStageConfig': (s) => s.bootstrapStageConfig,
  'bootstrapStageCleanup': (s) => s.bootstrapStageCleanup,
  'bootstrapStageReminders': (s) => s.bootstrapStageReminders,
  'bootstrapStageUsage': (s) => s.bootstrapStageUsage,
  'actionRetry': (s) => s.actionRetry,
  'actionCancel': (s) => s.actionCancel,
  'actionOk': (s) => s.actionOk,
  'actionBack': (s) => s.actionBack,
  'actionSave': (s) => s.actionSave,
  'actionShare': (s) => s.actionShare,
  'actionDelete': (s) => s.actionDelete,
  'stateLoading': (s) => s.stateLoading,
  'stateEmpty': (s) => s.stateEmpty,
  'stateErrorGeneric': (s) => s.stateErrorGeneric,
  'onboardingTitle': (s) => s.onboardingTitle,
  'onboardingSubtitle': (s) => s.onboardingSubtitle,
  'onboardingKindAppointment': (s) => s.onboardingKindAppointment,
  'onboardingKindInvoice': (s) => s.onboardingKindInvoice,
  'onboardingKindGovernment': (s) => s.onboardingKindGovernment,
  'onboardingKindEducation': (s) => s.onboardingKindEducation,
  'onboardingStart': (s) => s.onboardingStart,
  'privacyTitle': (s) => s.privacyTitle,
  'privacyPointExtractText': (s) => s.privacyPointExtractText,
  'privacyPointTextOnly': (s) => s.privacyPointTextOnly,
  'privacyPointImageOptIn': (s) => s.privacyPointImageOptIn,
  'privacyPointDeleteAnytime': (s) => s.privacyPointDeleteAnytime,
  'privacyAgree': (s) => s.privacyAgree,
  'homeGreetingTitle': (s) => s.homeGreetingTitle,
  'homeGreetingSubtitle': (s) => s.homeGreetingSubtitle,
  'homeScanTitle': (s) => s.homeScanTitle,
  'homeScanSubtitle': (s) => s.homeScanSubtitle,
  'homePickImage': (s) => s.homePickImage,
  'homeImagePrivacyNote': (s) => s.homeImagePrivacyNote,
  'homeUsageRemaining': (s) => s.homeUsageRemaining(2),
  'cameraPermissionTitle': (s) => s.cameraPermissionTitle,
  'cameraPermissionMessage': (s) => s.cameraPermissionMessage,
  'cameraPermissionBlockedMessage': (s) => s.cameraPermissionBlockedMessage,
  'cameraPermissionAllow': (s) => s.cameraPermissionAllow,
  'cameraPermissionOpenSettings': (s) => s.cameraPermissionOpenSettings,
  'cameraPermissionPickInstead': (s) => s.cameraPermissionPickInstead,
  'cameraOpening': (s) => s.cameraOpening,
  'cameraViewfinderHint': (s) => s.cameraViewfinderHint,
  'cameraShutterLabel': (s) => s.cameraShutterLabel,
  'cameraCloseLabel': (s) => s.cameraCloseLabel,
  'cameraCaptureErrorTitle': (s) => s.cameraCaptureErrorTitle,
  'cameraCaptureErrorMessage': (s) => s.cameraCaptureErrorMessage,
  'galleryOpening': (s) => s.galleryOpening,
  'galleryErrorTitle': (s) => s.galleryErrorTitle,
  'galleryErrorMessage': (s) => s.galleryErrorMessage,
  'previewTitle': (s) => s.previewTitle,
  'previewHint': (s) => s.previewHint,
  'previewUseImage': (s) => s.previewUseImage,
  'previewRetake': (s) => s.previewRetake,
  'previewRotateLabel': (s) => s.previewRotateLabel,
  'previewProcessing': (s) => s.previewProcessing,
  'previewErrorMessage': (s) => s.previewErrorMessage,
  'qualityAlertTitle': (s) => s.qualityAlertTitle,
  'qualityAlertMessage': (s) => s.qualityAlertMessage,
  'qualityAlertRetake': (s) => s.qualityAlertRetake,
  'qualityAlertContinue': (s) => s.qualityAlertContinue,
  'homeEmptyTitle': (s) => s.homeEmptyTitle,
  'homeUpcomingReminderTitle': (s) => s.homeUpcomingReminderTitle,
  'homeRecentDocumentsTitle': (s) => s.homeRecentDocumentsTitle,
  'homeSeeAll': (s) => s.homeSeeAll,
  'documentCategoryAppointment': (s) => s.documentCategoryAppointment,
  'documentCategoryInvoice': (s) => s.documentCategoryInvoice,
  'documentCategoryGovernment': (s) => s.documentCategoryGovernment,
  'documentCategoryEducation': (s) => s.documentCategoryEducation,
  'documentCategoryOther': (s) => s.documentCategoryOther,
  'timeAm': (s) => s.timeAm,
  'timePm': (s) => s.timePm,
  'monthName': (s) => s.monthName(1),
  'currencyName': (s) => s.currencyName('EGP'),
  'reminderDueToday': (s) => s.reminderDueToday('9:00'),
  'reminderDueTomorrow': (s) => s.reminderDueTomorrow('9:00'),
  'reminderDueOn': (s) => s.reminderDueOn('1/9', '9:00'),
  'actionView': (s) => s.actionView,
  'documentStoredResultOnly': (s) => s.documentStoredResultOnly,
  'documentStoredWithImage': (s) => s.documentStoredWithImage,
  'documentSaved': (s) => s.documentSaved,
  'documentSavedWithImage': (s) => s.documentSavedWithImage,
  'documentSaveFailed': (s) => s.documentSaveFailed,
  'saveModeSectionLabel': (s) => s.saveModeSectionLabel,
  'saveModeResultOnlyTitle': (s) => s.saveModeResultOnlyTitle,
  'saveModeResultOnlySubtitle': (s) => s.saveModeResultOnlySubtitle,
  'saveModeWithImageTitle': (s) => s.saveModeWithImageTitle,
  'saveModeWithImageSubtitle': (s) => s.saveModeWithImageSubtitle,
  'documentsEmptyTitle': (s) => s.documentsEmptyTitle,
  'documentsEmptySubtitle': (s) => s.documentsEmptySubtitle,
  'documentsEmptyCta': (s) => s.documentsEmptyCta,
  'documentsListErrorTitle': (s) => s.documentsListErrorTitle,
  'documentsSearchHint': (s) => s.documentsSearchHint,
  'documentsSearchNoResultsTitle': (s) => s.documentsSearchNoResultsTitle,
  'documentsSearchNoResultsSubtitle': (s) => s.documentsSearchNoResultsSubtitle,
  'documentsFilterAll': (s) => s.documentsFilterAll,
  'documentsFilterAppointment': (s) => s.documentsFilterAppointment,
  'documentsFilterInvoice': (s) => s.documentsFilterInvoice,
  'documentsFilterGovernment': (s) => s.documentsFilterGovernment,
  'documentsFilterEducation': (s) => s.documentsFilterEducation,
  'documentsFilterOther': (s) => s.documentsFilterOther,
  'documentDetailsTitle': (s) => s.documentDetailsTitle,
  'documentDetailsNotFoundTitle': (s) => s.documentDetailsNotFoundTitle,
  'documentDetailsNotFoundMessage': (s) => s.documentDetailsNotFoundMessage,
  'documentDetailsErrorTitle': (s) => s.documentDetailsErrorTitle,
  'documentDetailsErrorMessage': (s) => s.documentDetailsErrorMessage,
  'documentDetailsBackToList': (s) => s.documentDetailsBackToList,
  'documentImageLabel': (s) => s.documentImageLabel,
  'documentNoteHeading': (s) => s.documentNoteHeading,
  'documentNoteEmpty': (s) => s.documentNoteEmpty,
  'documentNoteAdd': (s) => s.documentNoteAdd,
  'documentNoteEdit': (s) => s.documentNoteEdit,
  'documentNoteDelete': (s) => s.documentNoteDelete,
  'documentNoteHint': (s) => s.documentNoteHint,
  'documentNoteSave': (s) => s.documentNoteSave,
  'documentNoteDeleteConfirmTitle': (s) => s.documentNoteDeleteConfirmTitle,
  'documentNoteDeleteConfirmMessage': (s) => s.documentNoteDeleteConfirmMessage,
  'documentNoteSaved': (s) => s.documentNoteSaved,
  'documentNoteDeleted': (s) => s.documentNoteDeleted,
  'documentNoteError': (s) => s.documentNoteError,
  'documentEditTitle': (s) => s.documentEditTitle,
  'documentEditCategory': (s) => s.documentEditCategory,
  'documentEditTitleHeading': (s) => s.documentEditTitleHeading,
  'documentEditTitleHint': (s) => s.documentEditTitleHint,
  'documentEditTitleSave': (s) => s.documentEditTitleSave,
  'documentEditCategoryHeading': (s) => s.documentEditCategoryHeading,
  'documentTitleUpdated': (s) => s.documentTitleUpdated,
  'documentCategoryUpdated': (s) => s.documentCategoryUpdated,
  'documentUpdateError': (s) => s.documentUpdateError,
  'documentDeleteAction': (s) => s.documentDeleteAction,
  'documentDeleteConfirmTitle': (s) => s.documentDeleteConfirmTitle,
  'documentDeleteConfirmMessage': (s) => s.documentDeleteConfirmMessage,
  'documentDeleted': (s) => s.documentDeleted,
  'documentDeleteError': (s) => s.documentDeleteError,
  'navHome': (s) => s.navHome,
  'navDocuments': (s) => s.navDocuments,
  'navReminders': (s) => s.navReminders,
  'navSettings': (s) => s.navSettings,
  'settingsGeneralSection': (s) => s.settingsGeneralSection,
  'settingsLanguageLabel': (s) => s.settingsLanguageLabel,
  'languageArabic': (s) => s.languageArabic,
  'languageEnglish': (s) => s.languageEnglish,
  'settingsPrivacySection': (s) => s.settingsPrivacySection,
  'settingsAnalysisConsentLabel': (s) => s.settingsAnalysisConsentLabel,
  'settingsProcessingModeLabel': (s) => s.settingsProcessingModeLabel,
  'settingsProcessingModeSmartAnalysis': (s) =>
      s.settingsProcessingModeSmartAnalysis,
  'settingsProcessingModeTextOnly': (s) => s.settingsProcessingModeTextOnly,
  'settingsProcessingModeSmartAnalysisDescription': (s) =>
      s.settingsProcessingModeSmartAnalysisDescription,
  'settingsProcessingModeTextOnlyDescription': (s) =>
      s.settingsProcessingModeTextOnlyDescription,
  'settingsDisplaySection': (s) => s.settingsDisplaySection,
  'settingsTextSizeLabel': (s) => s.settingsTextSizeLabel,
  'settingsTextSizeNormal': (s) => s.settingsTextSizeNormal,
  'settingsTextSizeLarge': (s) => s.settingsTextSizeLarge,
  'settingsTextSizeVeryLarge': (s) => s.settingsTextSizeVeryLarge,
  'settingsTextSizeNormalDescription': (s) =>
      s.settingsTextSizeNormalDescription,
  'settingsTextSizeLargeDescription': (s) => s.settingsTextSizeLargeDescription,
  'settingsTextSizeVeryLargeDescription': (s) =>
      s.settingsTextSizeVeryLargeDescription,
  'settingsAccessibilitySection': (s) => s.settingsAccessibilitySection,
  'settingsHighContrastLabel': (s) => s.settingsHighContrastLabel,
  'settingsAudioSection': (s) => s.settingsAudioSection,
  'settingsAudioSpeedLabel': (s) => s.settingsAudioSpeedLabel,
  'settingsAudioVoiceLabel': (s) => s.settingsAudioVoiceLabel,
  'settingsAudioVoiceDescription': (s) => s.settingsAudioVoiceDescription,
  'settingsAudioVoiceDefault': (s) => s.settingsAudioVoiceDefault,
  'settingsAudioPreviewLabel': (s) => s.settingsAudioPreviewLabel,
  'settingsAudioPreviewSample': (s) => s.settingsAudioPreviewSample,
  'settingsAudioPreviewFailedFeedback': (s) =>
      s.settingsAudioPreviewFailedFeedback,
  'settingsAudioResumeLabel': (s) => s.settingsAudioResumeLabel,
  'settingsPermissionsSection': (s) => s.settingsPermissionsSection,
  'settingsCameraPermissionLabel': (s) => s.settingsCameraPermissionLabel,
  'settingsPermissionGranted': (s) => s.settingsPermissionGranted,
  'settingsPermissionDenied': (s) => s.settingsPermissionDenied,
  'settingsPermissionBlocked': (s) => s.settingsPermissionBlocked,
  'settingsOpenCameraSettingsLabel': (s) => s.settingsOpenCameraSettingsLabel,
  'settingsNotificationPermissionLabel': (s) =>
      s.settingsNotificationPermissionLabel,
  'settingsOpenNotificationSettingsLabel': (s) =>
      s.settingsOpenNotificationSettingsLabel,
  'settingsNotificationPrivacyLabel': (s) => s.settingsNotificationPrivacyLabel,
  'settingsNotificationPrivacyDescription': (s) =>
      s.settingsNotificationPrivacyDescription,
  'settingsDeleteAllDocumentsLabel': (s) => s.settingsDeleteAllDocumentsLabel,
  'settingsDeleteAllAppDataLabel': (s) => s.settingsDeleteAllAppDataLabel,
  'settingsDeleteAllRemindersLabel': (s) => s.settingsDeleteAllRemindersLabel,
  'settingsDeleteAllConfirmAction': (s) => s.settingsDeleteAllConfirmAction,
  'settingsDeleteAllDocumentsConfirmTitle': (s) =>
      s.settingsDeleteAllDocumentsConfirmTitle,
  'settingsDeleteAllDocumentsConfirmMessage': (s) =>
      s.settingsDeleteAllDocumentsConfirmMessage,
  'settingsDeleteAllDocumentsSuccess': (s) =>
      s.settingsDeleteAllDocumentsSuccess,
  'settingsDeleteAllDocumentsError': (s) => s.settingsDeleteAllDocumentsError,
  'settingsDeleteAllAppDataConfirmTitle': (s) =>
      s.settingsDeleteAllAppDataConfirmTitle,
  'settingsDeleteAllAppDataConfirmMessage': (s) =>
      s.settingsDeleteAllAppDataConfirmMessage,
  'settingsDeleteAllAppDataSuccess': (s) => s.settingsDeleteAllAppDataSuccess,
  'settingsDeleteAllAppDataError': (s) => s.settingsDeleteAllAppDataError,
  'settingsDeleteAllRemindersConfirmTitle': (s) =>
      s.settingsDeleteAllRemindersConfirmTitle,
  'settingsDeleteAllRemindersConfirmMessage': (s) =>
      s.settingsDeleteAllRemindersConfirmMessage,
  'settingsDeleteAllRemindersSuccess': (s) =>
      s.settingsDeleteAllRemindersSuccess,
  'settingsDeleteAllRemindersError': (s) => s.settingsDeleteAllRemindersError,
  'settingsAboutSection': (s) => s.settingsAboutSection,
  'settingsPrivacyPolicyLabel': (s) => s.settingsPrivacyPolicyLabel,
  'settingsSupportedDocumentTypesLabel': (s) =>
      s.settingsSupportedDocumentTypesLabel,
  'settingsUsageLimitLabel': (s) => s.settingsUsageLimitLabel,
  'settingsUsageLimitValue': (s) => s.settingsUsageLimitValue(1, 3),
  'settingsUsageLimitUnavailable': (s) => s.settingsUsageLimitUnavailable,
  'settingsVersionLabel': (s) => s.settingsVersionLabel('1.0.0'),
  'ocrProcessing': (s) => s.ocrProcessing,
  'ocrErrorTitle': (s) => s.ocrErrorTitle,
  'ocrErrorMessage': (s) => s.ocrErrorMessage,
  'ocrNoTextTitle': (s) => s.ocrNoTextTitle,
  'ocrNoTextMessage': (s) => s.ocrNoTextMessage,
  'ocrRetake': (s) => s.ocrRetake,
  'ocrPickAnother': (s) => s.ocrPickAnother,
  'ocrExtractedTextTitle': (s) => s.ocrExtractedTextTitle,
  'ocrCopyText': (s) => s.ocrCopyText,
  'ocrTextCopied': (s) => s.ocrTextCopied,
  'ocrContinue': (s) => s.ocrContinue,
  'ocrDatesSection': (s) => s.ocrDatesSection,
  'ocrTimesSection': (s) => s.ocrTimesSection,
  'ocrAmountsSection': (s) => s.ocrAmountsSection,
  'ocrPhonesSection': (s) => s.ocrPhonesSection,
  'ocrReferencesSection': (s) => s.ocrReferencesSection,
  'ocrReviewTitle': (s) => s.ocrReviewTitle,
  'ocrReviewSubtitle': (s) => s.ocrReviewSubtitle,
  'ocrReviewDone': (s) => s.ocrReviewDone,
  'ocrOnlineReviewTitle': (s) => s.ocrOnlineReviewTitle,
  'ocrOnlineReviewSubtitle': (s) => s.ocrOnlineReviewSubtitle,
  'ocrOnlineLoading': (s) => s.ocrOnlineLoading,
  'ocrOnlineAnalyze': (s) => s.ocrOnlineAnalyze,
  'ocrOnlinePoorQuality': (s) => s.ocrOnlinePoorQuality,
  'ocrOnlineShowImage': (s) => s.ocrOnlineShowImage,
  'ocrOnlineHideImage': (s) => s.ocrOnlineHideImage,
  'ocrOnlineAmbiguityNotice': (s) => s.ocrOnlineAmbiguityNotice,
  'ocrOfflineQualityWarning': (s) => s.ocrOfflineQualityWarning,
  'ocrOnlineFallbackWarning': (s) => s.ocrOnlineFallbackWarning,
  'ocrListenToText': (s) => s.ocrListenToText,
  'analysisRunningTitle': (s) => s.analysisRunningTitle,
  'analysisRunningMessage': (s) => s.analysisRunningMessage,
  'analysisRunningStatus': (s) => s.analysisRunningStatus,
  'analysisResultTitle': (s) => s.analysisResultTitle,
  'analysisResultBackLabel': (s) => s.analysisResultBackLabel,
  'analysisFailedTitle': (s) => s.analysisFailedTitle,
  'analysisFailedMessage': (s) => s.analysisFailedMessage,
  'analysisNoInternetTitle': (s) => s.analysisNoInternetTitle,
  'analysisNoInternetMessage': (s) => s.analysisNoInternetMessage,
  'analysisLimitReachedTitle': (s) => s.analysisLimitReachedTitle,
  'analysisLimitReachedMessage': (s) => s.analysisLimitReachedMessage,
  'analysisBackToHome': (s) => s.analysisBackToHome,
  'resultListen': (s) => s.resultListen,
  'resultSavePaper': (s) => s.resultSavePaper,
  'resultSummaryLabel': (s) => s.resultSummaryLabel,
  'resultActionRequiredTitle': (s) => s.resultActionRequiredTitle,
  'resultActionInferred': (s) => s.resultActionInferred,
  'resultWarningsTitle': (s) => s.resultWarningsTitle,
  'resultKeyInformationTitle': (s) => s.resultKeyInformationTitle,
  'resultCopyValueLabel': (s) => s.resultCopyValueLabel('label'),
  'resultDatesTitle': (s) => s.resultDatesTitle,
  'resultDateNoTime': (s) => s.resultDateNoTime,
  'resultCreateReminder': (s) => s.resultCreateReminder,
  'resultPickDateTitle': (s) => s.resultPickDateTitle,
  'resultPickDateMessage': (s) => s.resultPickDateMessage,
  'resultDateReminderWorthy': (s) => s.resultDateReminderWorthy,
  'resultDateDisplayOnly': (s) => s.resultDateDisplayOnly,
  'resultAmountsTitle': (s) => s.resultAmountsTitle,
  'resultRequiredDocumentsTitle': (s) => s.resultRequiredDocumentsTitle,
  'resultInstructionsTitle': (s) => s.resultInstructionsTitle,
  'resultShowExplanation': (s) => s.resultShowExplanation,
  'resultShowExtractedText': (s) => s.resultShowExtractedText,
  'resultExtractedTextWarning': (s) => s.resultExtractedTextWarning,
  'actionCopy': (s) => s.actionCopy,
  'resultListenToText': (s) => s.resultListenToText,
  'resultPartialBanner': (s) => s.resultPartialBanner,
  'analysisUnsupportedTitle': (s) => s.analysisUnsupportedTitle,
  'analysisUnsupportedMessage': (s) => s.analysisUnsupportedMessage,
  'analysisConsentDeclinedTitle': (s) => s.analysisConsentDeclinedTitle,
  'analysisConsentDeclinedMessage': (s) => s.analysisConsentDeclinedMessage,
  'analysisConsentDeclinedOpenSettings': (s) =>
      s.analysisConsentDeclinedOpenSettings,
  'resultListenToExtractedText': (s) => s.resultListenToExtractedText,
  'analysisCaptureAnother': (s) => s.analysisCaptureAnother,
  'extractedTextOnlyTitle': (s) => s.extractedTextOnlyTitle,
  'extractedTextOnlyNote': (s) => s.extractedTextOnlyNote,
  'documentKindInvoice': (s) => s.documentKindInvoice,
  'documentKindReceipt': (s) => s.documentKindReceipt,
  'documentKindAppointment': (s) => s.documentKindAppointment,
  'documentKindGovernment': (s) => s.documentKindGovernment,
  'documentKindExam': (s) => s.documentKindExam,
  'documentKindMedical': (s) => s.documentKindMedical,
  'documentKindLegal': (s) => s.documentKindLegal,
  'documentKindFinancial': (s) => s.documentKindFinancial,
  'documentKindEducational': (s) => s.documentKindEducational,
  'documentKindOther': (s) => s.documentKindOther,
  'confidenceReview': (s) => s.confidenceReview,
  'confidenceUncertain': (s) => s.confidenceUncertain,
  'reminderFormTitleLabel': (s) => s.reminderFormTitleLabel,
  'reminderFromDocumentInfoHeading': (s) => s.reminderFromDocumentInfoHeading,
  'reminderEventDateLabel': (s) => s.reminderEventDateLabel,
  'reminderEventTimeLabel': (s) => s.reminderEventTimeLabel,
  'reminderEventTimeMissing': (s) => s.reminderEventTimeMissing,
  'reminderAlertsSectionLabel': (s) => s.reminderAlertsSectionLabel,
  'reminderAddAnotherAlert': (s) => s.reminderAddAnotherAlert,
  'reminderRemoveAlertLabel': (s) => s.reminderRemoveAlertLabel,
  'reminderNoteLabel': (s) => s.reminderNoteLabel,
  'reminderNoteHint': (s) => s.reminderNoteHint,
  'reminderLinkedDocumentSectionLabel': (s) =>
      s.reminderLinkedDocumentSectionLabel,
  'reminderLinkedDocumentValueLabel': (s) => s.reminderLinkedDocumentValueLabel,
  'reminderSaveAction': (s) => s.reminderSaveAction,
  'reminderAlertOffsetThreeDays': (s) => s.reminderAlertOffsetThreeDays,
  'reminderAlertOffsetOneDay': (s) => s.reminderAlertOffsetOneDay,
  'reminderAlertOffsetTwoHours': (s) => s.reminderAlertOffsetTwoHours,
  'reminderAlertOffsetAtEventTime': (s) => s.reminderAlertOffsetAtEventTime,
  'reminderAlertOffsetCustom': (s) => s.reminderAlertOffsetCustom,
  'reminderAlertPickerTitle': (s) => s.reminderAlertPickerTitle,
  'reminderMissingEventTimeWarning': (s) => s.reminderMissingEventTimeWarning,
  'reminderSuggestedAlertTime': (s) => s.reminderSuggestedAlertTime('9:00'),
  'reminderCreateScreenTitle': (s) => s.reminderCreateScreenTitle,
  'reminderAddAction': (s) => s.reminderAddAction,
  'reminderSuccessTitle': (s) => s.reminderSuccessTitle,
  'reminderSuccessViewAction': (s) => s.reminderSuccessViewAction,
  'reminderManualTitleHint': (s) => s.reminderManualTitleHint,
  'reminderDateLabel': (s) => s.reminderDateLabel,
  'reminderDatePickHint': (s) => s.reminderDatePickHint,
  'reminderTimeLabel': (s) => s.reminderTimeLabel,
  'reminderTimePickHint': (s) => s.reminderTimePickHint,
  'reminderNotifPermTitle': (s) => s.reminderNotifPermTitle,
  'reminderNotifPermMessage': (s) => s.reminderNotifPermMessage,
  'reminderNotifPermAllow': (s) => s.reminderNotifPermAllow,
  'reminderNotifPermSaveWithout': (s) => s.reminderNotifPermSaveWithout,
  'reminderNotificationChannelName': (s) => s.reminderNotificationChannelName,
  'reminderNotificationGenericTitle': (s) => s.reminderNotificationGenericTitle,
  'reminderListTitle': (s) => s.reminderListTitle,
  'reminderTabUpcoming': (s) => s.reminderTabUpcoming,
  'reminderTabMissed': (s) => s.reminderTabMissed,
  'reminderTabCompleted': (s) => s.reminderTabCompleted,
  'reminderEmptyTitle': (s) => s.reminderEmptyTitle,
  'reminderEmptySubtitle': (s) => s.reminderEmptySubtitle,
  'reminderEmptyScanCta': (s) => s.reminderEmptyScanCta,
  'reminderEmptyMissedTitle': (s) => s.reminderEmptyMissedTitle,
  'reminderEmptyCompletedTitle': (s) => s.reminderEmptyCompletedTitle,
  'reminderStatusUpcoming': (s) => s.reminderStatusUpcoming,
  'reminderStatusMissed': (s) => s.reminderStatusMissed,
  'reminderStatusCompleted': (s) => s.reminderStatusCompleted,
  'reminderCompleteAction': (s) => s.reminderCompleteAction,
  'reminderSnoozeAction': (s) => s.reminderSnoozeAction,
  'reminderListErrorTitle': (s) => s.reminderListErrorTitle,
  'reminderDetailsTitle': (s) => s.reminderDetailsTitle,
  'reminderDetailsDateLabel': (s) => s.reminderDetailsDateLabel,
  'reminderDetailsTimeLabel': (s) => s.reminderDetailsTimeLabel,
  'reminderDetailsAlertLabel': (s) => s.reminderDetailsAlertLabel,
  'reminderDetailsDescriptionLabel': (s) => s.reminderDetailsDescriptionLabel,
  'reminderDetailsLinkedDocumentLabel': (s) =>
      s.reminderDetailsLinkedDocumentLabel,
  'reminderDetailsNotFoundTitle': (s) => s.reminderDetailsNotFoundTitle,
  'reminderDetailsNotFoundMessage': (s) => s.reminderDetailsNotFoundMessage,
  'reminderDetailsErrorTitle': (s) => s.reminderDetailsErrorTitle,
  'reminderDetailsErrorMessage': (s) => s.reminderDetailsErrorMessage,
  'reminderDetailsBackToList': (s) => s.reminderDetailsBackToList,
  'reminderDetailsCompleteAction': (s) => s.reminderDetailsCompleteAction,
  'reminderDetailsSnoozeAction': (s) => s.reminderDetailsSnoozeAction,
  'reminderDetailsEditAction': (s) => s.reminderDetailsEditAction,
  'reminderDetailsDeleteAction': (s) => s.reminderDetailsDeleteAction,
  'reminderSnoozeSheetTitle': (s) => s.reminderSnoozeSheetTitle,
  'reminderSnoozeSheetSubtitle': (s) => s.reminderSnoozeSheetSubtitle,
  'reminderSnoozeOptionOneHour': (s) => s.reminderSnoozeOptionOneHour,
  'reminderSnoozeOptionTomorrow': (s) => s.reminderSnoozeOptionTomorrow,
  'reminderSnoozeOptionCustom': (s) => s.reminderSnoozeOptionCustom,
  'reminderDeleteSheetTitle': (s) => s.reminderDeleteSheetTitle,
  'reminderDeleteSheetMessage': (s) => s.reminderDeleteSheetMessage,
  'reminderDeleteSheetConfirm': (s) => s.reminderDeleteSheetConfirm,
  'reminderDeleteSheetCancel': (s) => s.reminderDeleteSheetCancel,
  'reminderCompletedFeedback': (s) => s.reminderCompletedFeedback,
  'reminderSnoozedFeedback': (s) => s.reminderSnoozedFeedback,
  'reminderDeletedFeedback': (s) => s.reminderDeletedFeedback,
  'reminderActionFailedFeedback': (s) => s.reminderActionFailedFeedback,
  'audioReaderSheetTitle': (s) => s.audioReaderSheetTitle,
  'audioReaderModeSummary': (s) => s.audioReaderModeSummary,
  'audioReaderModeSummaryAndKeyInformation': (s) =>
      s.audioReaderModeSummaryAndKeyInformation,
  'audioReaderModeFull': (s) => s.audioReaderModeFull,
  'audioReaderModeReadAll': (s) => s.audioReaderModeReadAll,
  'audioReaderModeExtractedText': (s) => s.audioReaderModeExtractedText,
  'audioReaderOptions': (s) => s.audioReaderOptions,
  'audioReaderNowReading': (s) => s.audioReaderNowReading('mode'),
  'audioReaderStartLabel': (s) => s.audioReaderStartLabel,
  'audioReaderPauseLabel': (s) => s.audioReaderPauseLabel,
  'audioReaderResumeLabel': (s) => s.audioReaderResumeLabel,
  'audioReaderStopLabel': (s) => s.audioReaderStopLabel,
  'audioReaderFailedFeedback': (s) => s.audioReaderFailedFeedback,
  'audioReaderSpeedLabel': (s) => s.audioReaderSpeedLabel,
};

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  group('AppStrings parity', () {
    test('every Arabic key is non-empty', () {
      for (final get in _accessors.values) {
        expect(get(ar).trim(), isNotEmpty);
      }
    });

    test('every English key is non-empty', () {
      for (final get in _accessors.values) {
        expect(get(en).trim(), isNotEmpty);
      }
    });

    test('Arabic and English differ (translations, not copies)', () {
      expect(ar.appName, isNot(en.appName));
      expect(ar.actionCancel, isNot(en.actionCancel));
    });

    test('covers every AppStrings member', () {
      // Read from the interface's source, so a new string cannot slip past
      // the checks in this file by being left out of [_accessors].
      final source = File(
        'lib/core/localization/app_strings.dart',
      ).readAsStringSync();
      final declared = RegExp(
        r'^  String (?:get )?(\w+)[;(]',
        multiLine: true,
      ).allMatches(source).map((m) => m.group(1)!).toSet();

      expect(declared, isNotEmpty);
      expect(_accessors.keys.toSet(), declared);
    });
  });

  // ── the privacy contract (F18-T02) ──────────────────────────────────────
  //
  // The app runs its analysis on a provider free tier whose terms let the
  // provider read and human-review the API input, and the API input is the
  // OCR TEXT — the account number, the amount, the name, the court date. So
  // no user-facing string may claim that nobody sees the TEXT.
  //
  // F20-T24 extends the same honesty to the IMAGE. When the user is online,
  // the photo itself goes to an outside reader on a free tier that may keep
  // it for a while and let its staff review it; offline, it is read only on
  // the phone. So no user-facing string may claim that nobody sees the IMAGE
  // either, and an unscoped "not saved" is false too — only "we don't save
  // it" and "not saved ON YOUR PHONE without consent" are promises the app
  // can keep.
  group('privacy copy tells the truth about the text', () {
    test('Arabic does not claim the text is unseen', () {
      // «محدش بيشوفه» is the masculine form — النص.
      expect(
        ar.privacyPointTextOnly,
        isNot(contains('محدش بيشوفه ')),
        reason: 'free-tier terms permit the provider to read the text',
      );
      expect(
        ar.privacyPointTextOnly,
        isNot(contains('محدش بيقرا')),
        reason: 'the app cannot promise the text goes unread',
      );
    });

    test('English does not claim the text is unseen', () {
      final lower = en.privacyPointTextOnly.toLowerCase();

      expect(
        lower,
        isNot(contains('no person ever sees')),
        reason: 'the retired claim — false for the text on a free tier',
      );
      expect(
        lower,
        isNot(contains('nobody sees the text')),
        reason: 'the app cannot promise the text goes unseen',
      );
    });

    test('no copy claims the image goes unseen (F20-T24)', () {
      // The retired promise, in both languages and in any string: the online
      // reader's free tier may keep the photo and let its staff review it.
      for (final MapEntry(key: name, value: get) in _accessors.entries) {
        expect(
          get(ar),
          isNot(contains('محدش بيشوفها')),
          reason: '$name: the online reader may review the photo',
        );
        expect(
          get(en).toLowerCase(),
          isNot(contains('nobody sees it')),
          reason: '$name: the online reader may review the photo',
        );
      }
    });

    test('the image copy says what really happens to the photo', () {
      // Online: sent out, may be kept for a while and reviewed by staff.
      // Offline: read only on the phone. Both halves must be stated.
      expect(ar.privacyPointExtractText, contains('بنبعت صورة الورقة'));
      expect(ar.privacyPointExtractText, contains('ممكن تحتفظ بيها فترة'));
      expect(ar.privacyPointExtractText, contains('يراجعها موظفين'));
      expect(ar.privacyPointExtractText, contains('على موبايلك بس'));

      final enCopy = en.privacyPointExtractText.toLowerCase();
      expect(enCopy, contains('we send the photo'));
      expect(enCopy, contains('may keep it for a while'));
      expect(enCopy, contains('staff may review it'));
      expect(enCopy, contains('read only on your phone'));
    });

    test('what the app does promise about the image is still stated', () {
      // We don't keep it; and it is only saved on the phone with consent.
      expect(ar.privacyPointExtractText, contains('مابنحفظش الصورة'));
      expect(
        en.privacyPointExtractText.toLowerCase(),
        contains("we don't keep the photo"),
      );
      for (final copy in [ar.privacyPointImageOptIn, ar.homeImagePrivacyNote]) {
        expect(copy, contains('على موبايلك'));
      }
      for (final copy in [en.privacyPointImageOptIn, en.homeImagePrivacyNote]) {
        expect(copy, contains('on your phone'));
      }
    });

    test('what the app does promise about the text is still stated', () {
      // Honest without being frightening: not kept, not logged, sent
      // encrypted. Anything weaker and the copy says nothing at all.
      expect(ar.privacyPointTextOnly, contains('مانحفظش النص'));
      expect(en.privacyPointTextOnly, contains('do not keep the text'));
    });

    test('no user-facing privacy copy names a provider', () {
      // §7, unchanged since F13-T18 and binding on every string here.
      const providers = [
        'Azure',
        'Google',
        'Gemini',
        'Mistral',
        'Groq',
        'OpenAI',
      ];

      for (final get in _accessors.values) {
        for (final name in providers) {
          expect(
            get(ar).toLowerCase(),
            isNot(contains(name.toLowerCase())),
            reason: '$name must never appear in Arabic user-facing copy',
          );
          expect(
            get(en).toLowerCase(),
            isNot(contains(name.toLowerCase())),
            reason: '$name must never appear in English user-facing copy',
          );
        }
      }
    });
  });
}
