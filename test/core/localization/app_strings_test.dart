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
  (s) => s.documentsSearchHint,
  (s) => s.documentsSearchNoResultsTitle,
  (s) => s.documentsSearchNoResultsSubtitle,
  (s) => s.navHome,
  (s) => s.navDocuments,
  (s) => s.navReminders,
  (s) => s.navSettings,
  (s) => s.settingsGeneralSection,
  (s) => s.settingsLanguageLabel,
  (s) => s.languageArabic,
  (s) => s.languageEnglish,
  (s) => s.settingsPrivacySection,
  (s) => s.settingsAnalysisConsentLabel,
  (s) => s.analysisConsentDeclinedTitle,
  (s) => s.analysisConsentDeclinedMessage,
  (s) => s.analysisConsentDeclinedOpenSettings,
  (s) => s.settingsDisplaySection,
  (s) => s.settingsTextSizeLabel,
  (s) => s.settingsTextSizeNormal,
  (s) => s.settingsTextSizeLarge,
  (s) => s.settingsTextSizeVeryLarge,
  (s) => s.settingsTextSizeNormalDescription,
  (s) => s.settingsTextSizeLargeDescription,
  (s) => s.settingsTextSizeVeryLargeDescription,
  (s) => s.settingsAccessibilitySection,
  (s) => s.settingsHighContrastLabel,
  (s) => s.ocrOfflineQualityWarning,
  (s) => s.ocrOnlineFallbackWarning,
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

  // ── the privacy contract (F18-T02) ──────────────────────────────────────
  //
  // The app runs its analysis on a provider free tier whose terms let the
  // provider read and human-review the API input, and the API input is the
  // OCR TEXT — the account number, the amount, the name, the court date. So
  // no user-facing string may claim that nobody sees the TEXT.
  //
  // The IMAGE promise is untouched and still true: it is never stored and
  // nobody sees it. These tests exist to keep the two apart, because the old
  // copy conflated them in one sentence and the reader took "nobody sees it"
  // as covering both.
  group('privacy copy tells the truth about the text', () {
    test('Arabic does not claim the text is unseen', () {
      // «محدش بيشوفه» is the masculine form — النص. Only the feminine
      // «محدش بيشوفها» (الصورة) is a promise the app can keep.
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

    test('the image promise survives in both languages', () {
      // What T02 must NOT erase. The image never reaches the analysis
      // provider, is not stored, and is deleted straight after reading.
      expect(ar.privacyPointTextOnly, contains('محدش بيشوفها'));
      expect(en.privacyPointTextOnly.toLowerCase(), contains('nobody sees it'));
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

      for (final get in _accessors) {
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
