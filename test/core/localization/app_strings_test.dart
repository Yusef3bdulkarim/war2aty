import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_strings.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';

/// Every key, as an accessor. Both languages run through the same list, so the
/// parity check covers the whole interface. Adding a getter to [AppStrings]
/// without adding it here leaves it untested — keep this in sync with the
/// interface (the compiler already forces both impls to define it).
final List<String Function(AppStrings)> _accessors = [
  (s) => s.appName,
  (s) => s.appTagline,
  (s) => s.bootstrapErrorTitle,
  (s) => s.bootstrapErrorMessage,
  (s) => s.bootstrapStageSession,
  (s) => s.bootstrapStageConfig,
  (s) => s.bootstrapStageCleanup,
  (s) => s.bootstrapStageReminders,
  (s) => s.bootstrapStageUsage,
  (s) => s.actionRetry,
  (s) => s.actionCancel,
  (s) => s.actionOk,
  (s) => s.actionBack,
  (s) => s.actionSave,
  (s) => s.actionShare,
  (s) => s.actionDelete,
  (s) => s.stateLoading,
  (s) => s.stateEmpty,
  (s) => s.stateErrorGeneric,
  (s) => s.onboardingTitle,
  (s) => s.onboardingSubtitle,
  (s) => s.onboardingKindAppointment,
  (s) => s.onboardingKindInvoice,
  (s) => s.onboardingKindGovernment,
  (s) => s.onboardingKindEducation,
  (s) => s.onboardingStart,
  (s) => s.privacyTitle,
  (s) => s.privacyPointExtractText,
  (s) => s.privacyPointTextOnly,
  (s) => s.privacyPointImageOptIn,
  (s) => s.privacyPointDeleteAnytime,
  (s) => s.privacyAgree,
  (s) => s.homeGreetingTitle,
  (s) => s.homeGreetingSubtitle,
  (s) => s.homeScanTitle,
  (s) => s.homeScanSubtitle,
  (s) => s.homePickImage,
  (s) => s.homeImagePrivacyNote,
  (s) => s.cameraPermissionTitle,
  (s) => s.cameraPermissionMessage,
  (s) => s.cameraPermissionBlockedMessage,
  (s) => s.cameraPermissionAllow,
  (s) => s.cameraPermissionOpenSettings,
  (s) => s.cameraPermissionPickInstead,
  (s) => s.cameraOpening,
  (s) => s.cameraViewfinderHint,
  (s) => s.cameraShutterLabel,
  (s) => s.cameraCloseLabel,
  (s) => s.cameraCaptureErrorTitle,
  (s) => s.cameraCaptureErrorMessage,
  (s) => s.galleryOpening,
  (s) => s.galleryErrorTitle,
  (s) => s.galleryErrorMessage,
  (s) => s.previewTitle,
  (s) => s.previewHint,
  (s) => s.previewUseImage,
  (s) => s.previewRetake,
  (s) => s.previewRotateLabel,
  (s) => s.previewProcessing,
  (s) => s.previewErrorMessage,
  (s) => s.qualityAlertTitle,
  (s) => s.qualityAlertMessage,
  (s) => s.qualityAlertRetake,
  (s) => s.qualityAlertContinue,
  (s) => s.homeEmptyTitle,
  (s) => s.homeUpcomingReminderTitle,
  (s) => s.homeRecentDocumentsTitle,
  (s) => s.timeAm,
  (s) => s.timePm,
  (s) => s.actionView,
  (s) => s.homeSeeAll,
  (s) => s.documentCategoryAppointment,
  (s) => s.documentCategoryInvoice,
  (s) => s.documentCategoryGovernment,
  (s) => s.documentCategoryEducation,
  (s) => s.documentCategoryOther,
  (s) => s.documentStoredResultOnly,
  (s) => s.documentStoredWithImage,
  (s) => s.navHome,
  (s) => s.navDocuments,
  (s) => s.navReminders,
  (s) => s.navSettings,
  (s) => s.languageArabic,
  (s) => s.languageEnglish,
];

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  group('AppStrings parity', () {
    test('every Arabic key is non-empty', () {
      for (final get in _accessors) {
        expect(get(ar).trim(), isNotEmpty);
      }
    });

    test('every English key is non-empty', () {
      for (final get in _accessors) {
        expect(get(en).trim(), isNotEmpty);
      }
    });

    test('Arabic and English differ (translations, not copies)', () {
      expect(ar.appName, isNot(en.appName));
      expect(ar.actionCancel, isNot(en.actionCancel));
    });
  });
}
