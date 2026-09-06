import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/accessibility/high_contrast_cubit.dart';
import 'package:war2aty/core/accessibility/text_size.dart';
import 'package:war2aty/core/accessibility/text_size_cubit.dart';
import 'package:war2aty/core/accessibility/usecases/get_high_contrast.dart';
import 'package:war2aty/core/accessibility/usecases/get_text_size.dart';
import 'package:war2aty/core/accessibility/usecases/set_high_contrast.dart';
import 'package:war2aty/core/accessibility/usecases/set_text_size.dart';
import 'package:war2aty/core/analysis/processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/analysis/usecases/get_processing_mode.dart';
import 'package:war2aty/core/analysis/usecases/set_analysis_consent.dart';
import 'package:war2aty/core/analysis/usecases/set_processing_mode.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/audio/usecases/get_resume_reading_enabled.dart';
import 'package:war2aty/core/audio/usecases/preview_default_voice.dart';
import 'package:war2aty/core/audio/usecases/set_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/set_resume_reading_enabled.dart';
import 'package:war2aty/core/documents/usecases/delete_all_documents.dart';
import 'package:war2aty/core/env/app_environment.dart';
import 'package:war2aty/core/env/usecases/get_app_version.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/localization/locale_cubit.dart';
import 'package:war2aty/core/localization/usecases/get_saved_locale.dart';
import 'package:war2aty/core/localization/usecases/set_locale.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/open_notification_permission_settings.dart';
import 'package:war2aty/core/reminders/usecases/delete_all_reminders.dart';
import 'package:war2aty/core/reminders/usecases/get_hide_sensitive_notification_details.dart';
import 'package:war2aty/core/reminders/usecases/set_hide_sensitive_notification_details.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/settings/usecases/delete_all_app_data.dart';
import 'package:war2aty/core/usage/usecases/get_daily_usage.dart';
import 'package:war2aty/core/widgets/skeleton.dart';
import 'package:war2aty/features/audio_reader/domain/usecases/select_voice_for_reading.dart';
import 'package:war2aty/features/capture/domain/usecases/get_camera_permission.dart';
import 'package:war2aty/features/capture/domain/usecases/open_permission_settings.dart';
import 'package:war2aty/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:war2aty/features/settings/presentation/screens/settings_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';

// F11-T01/T02/T03/T04/T05/T06/T07/T08/T09/T10: the settings scaffold, the
// analysis consent toggle, the processing-mode picker, the language switch,
// the text-size picker, the high-contrast toggle, the audio prefs, the
// camera/notification permission status rows, and the notification-privacy
// toggle.
void main() {
  const ar = ArStrings();

  late FakeAnalysisConsentStore consentStore;
  late FakeProcessingModeStore modeStore;
  late FakeLocaleStore localeStore;
  late FakeTextSizeStore textSizeStore;
  late FakeHighContrastStore highContrastStore;
  late FakeDefaultReadingSpeedStore speedStore;
  late FakeDefaultReadingVoiceStore voiceStore;
  late FakeResumeReadingEnabledStore resumeStore;
  late FakeTextToSpeechService tts;
  late FakeCameraPermissionRepository cameraPermissionRepo;
  late FakeNotificationPermissionRepository notificationPermissionRepo;
  late FakeNotificationPrivacyStore notificationPrivacyStore;
  late FakeDocumentsRepository documentsRepository;
  late FakeRemindersRepository remindersRepository;
  late FakeReminderScheduler reminderScheduler;
  late FakeAppSettingsRepository settingsRepository;
  late FakeUsageRepository usageRepository;
  late SettingsCubit cubit;
  late LocaleCubit localeCubit;
  late TextSizeCubit textSizeCubit;
  late HighContrastCubit highContrastCubit;

  setUp(() {
    consentStore = FakeAnalysisConsentStore();
    modeStore = FakeProcessingModeStore();
    localeStore = FakeLocaleStore();
    textSizeStore = FakeTextSizeStore();
    highContrastStore = FakeHighContrastStore();
    speedStore = FakeDefaultReadingSpeedStore();
    voiceStore = FakeDefaultReadingVoiceStore();
    resumeStore = FakeResumeReadingEnabledStore();
    tts = FakeTextToSpeechService();
    cameraPermissionRepo = FakeCameraPermissionRepository(
      status: PermissionOutcome.granted,
    );
    notificationPermissionRepo = FakeNotificationPermissionRepository();
    notificationPrivacyStore = FakeNotificationPrivacyStore();
    documentsRepository = FakeDocumentsRepository();
    remindersRepository = FakeRemindersRepository();
    reminderScheduler = FakeReminderScheduler();
    settingsRepository = FakeAppSettingsRepository();
    usageRepository = FakeUsageRepository();
    cubit = SettingsCubit(
      getAnalysisConsent: GetAnalysisConsent(consentStore),
      setAnalysisConsent: SetAnalysisConsent(consentStore),
      getProcessingMode: GetProcessingMode(modeStore),
      setProcessingMode: SetProcessingMode(modeStore),
      getDefaultReadingSpeed: GetDefaultReadingSpeed(speedStore),
      setDefaultReadingSpeed: SetDefaultReadingSpeed(speedStore),
      getDefaultReadingVoice: GetDefaultReadingVoice(voiceStore),
      getResumeReadingEnabled: GetResumeReadingEnabled(resumeStore),
      setResumeReadingEnabled: SetResumeReadingEnabled(resumeStore),
      previewDefaultVoice: PreviewDefaultVoice(
        tts,
        const SelectVoiceForReading(),
      ),
      getCameraPermission: GetCameraPermission(cameraPermissionRepo),
      openPermissionSettings: OpenPermissionSettings(cameraPermissionRepo),
      getNotificationPermission: GetNotificationPermission(
        notificationPermissionRepo,
      ),
      openNotificationSettings: OpenNotificationPermissionSettings(
        notificationPermissionRepo,
      ),
      getHideSensitiveNotificationDetails: GetHideSensitiveNotificationDetails(
        notificationPrivacyStore,
      ),
      setHideSensitiveNotificationDetails: SetHideSensitiveNotificationDetails(
        notificationPrivacyStore,
      ),
      deleteAllDocuments: DeleteAllDocuments(documentsRepository),
      deleteAllReminders: DeleteAllReminders(
        remindersRepository,
        reminderScheduler,
      ),
      deleteAllAppData: DeleteAllAppData(
        DeleteAllDocuments(documentsRepository),
        DeleteAllReminders(remindersRepository, reminderScheduler),
        settingsRepository,
      ),
      getDailyUsage: GetDailyUsage(usageRepository),
      getAppVersion: GetAppVersion(
        AppEnvironment.dev(isAndroid: false, appVersion: '2.3.1'),
      ),
    );
    localeCubit = LocaleCubit(
      getSavedLocale: GetSavedLocale(localeStore),
      setLocale: SetLocale(localeStore),
    );
    textSizeCubit = TextSizeCubit(
      getTextSize: GetTextSize(textSizeStore),
      setTextSize: SetTextSize(textSizeStore),
    );
    highContrastCubit = HighContrastCubit(
      getHighContrast: GetHighContrast(highContrastStore),
      setHighContrast: SetHighContrast(highContrastStore),
    );
  });

  tearDown(() {
    cubit.close();
    localeCubit.close();
    textSizeCubit.close();
    highContrastCubit.close();
    tts.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
    VoidCallback? onOpenPrivacyPolicy,
  }) async {
    await cubit.load();
    await textSizeCubit.load();
    await highContrastCubit.load();
    await pumpApp(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>.value(value: cubit),
          BlocProvider<LocaleCubit>.value(value: localeCubit),
          BlocProvider<TextSizeCubit>.value(value: textSizeCubit),
          BlocProvider<HighContrastCubit>.value(value: highContrastCubit),
        ],
        // A bare `Scaffold`, matching the real app: `SettingsScreen` itself
        // draws no `Scaffold` (unlike `AnalysisResultScreen`), relying on the
        // bottom-nav shell's own — needed here so «تجربة الصوت»'s failure
        // snackbar (F11-T07) has somewhere to attach to.
        child: Scaffold(
          body: SettingsScreen(onOpenPrivacyPolicy: onOpenPrivacyPolicy),
        ),
      ),
      locale: locale,
      textScaler: textScaler,
    );
  }

  group('the loading skeleton (perceived-hang fix)', () {
    testWidgets(
      'shows a skeleton for each SettingsCubit-backed section instead of a '
      'bare gap, without holding back the sections that load elsewhere',
      (tester) async {
        // Deliberately skips `cubit.load()` — `pumpScreen` always awaits it
        // first, which is exactly the case this regression slipped through:
        // it only ever exercised the screen *after* SettingsCubit had
        // already reached SettingsReady.
        await textSizeCubit.load();
        await highContrastCubit.load();
        await pumpApp(
          tester,
          MultiBlocProvider(
            providers: [
              BlocProvider<SettingsCubit>.value(value: cubit),
              BlocProvider<LocaleCubit>.value(value: localeCubit),
              BlocProvider<TextSizeCubit>.value(value: textSizeCubit),
              BlocProvider<HighContrastCubit>.value(value: highContrastCubit),
            ],
            child: const Scaffold(body: SettingsScreen()),
          ),
          // The skeleton's Shimmer repeats indefinitely — pumpAndSettle
          // would never return (same reasoning `upcoming_reminder_card_test`
          // already documents for its own skeleton).
          settle: false,
        );

        // The sections with their own app-wide cubit render immediately...
        expect(find.text(ar.settingsGeneralSection), findsOneWidget);
        expect(find.text(ar.settingsDisplaySection), findsOneWidget);
        expect(find.text(ar.settingsAccessibilitySection), findsOneWidget);

        // ...while the four sections still waiting on SettingsCubit show a
        // skeleton, not their real title or content yet (F11-T12 added the
        // «عن التطبيق» section as the fourth).
        expect(find.text(ar.settingsPrivacySection), findsNothing);
        expect(find.text(ar.settingsAudioSection), findsNothing);
        expect(find.text(ar.settingsPermissionsSection), findsNothing);
        expect(find.text(ar.settingsAboutSection), findsNothing);
        expect(find.byType(Shimmer), findsNWidgets(4));
        expect(find.bySemanticsLabel(ar.stateLoading), findsNWidgets(4));
      },
    );

    testWidgets('gives way to the real sections once load() settles', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.byType(Shimmer), findsNothing);
      expect(find.text(ar.settingsPrivacySection), findsOneWidget);
      expect(find.text(ar.settingsAudioSection), findsOneWidget);
      expect(find.text(ar.settingsPermissionsSection), findsOneWidget);
      expect(find.text(ar.settingsAboutSection), findsOneWidget);
    });
  });

  testWidgets('shows the page heading', (tester) async {
    await pumpScreen(tester);

    expect(find.text(ar.navSettings), findsOneWidget);
  });

  testWidgets('the heading is announced as a header', (tester) async {
    await pumpScreen(tester);

    expect(
      tester.getSemantics(find.text(ar.navSettings)),
      isSemantics(isHeader: true),
    );
  });

  testWidgets('lays out under Large Text and in English', (tester) async {
    await localeStore.writeLanguageCode('en');
    await localeCubit.load();
    await pumpScreen(
      tester,
      locale: AppLocalizations.english,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text(const EnStrings().navSettings), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the language switch (F11-T04)', () {
    testWidgets('shows the general section with Arabic selected by default', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text(ar.settingsGeneralSection), findsOneWidget);
      expect(find.text(ar.settingsLanguageLabel), findsOneWidget);
      expect(find.text(ar.languageArabic), findsOneWidget);
    });

    testWidgets('reflects a previously saved English locale', (tester) async {
      await localeStore.writeLanguageCode('en');
      await localeCubit.load();
      await pumpScreen(tester);

      // The row's value shows the English label (in Arabic strings, since the
      // app locale hasn't switched in this test harness).
      expect(find.text(ar.languageEnglish), findsOneWidget);
    });

    testWidgets('tapping the row opens the language picker sheet', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text(ar.settingsLanguageLabel));
      await tester.pumpAndSettle();

      // «العربية» appears on the row's value and in the sheet option — two.
      // «الإنجليزية» appears only in the sheet.
      expect(find.text(ar.languageArabic), findsNWidgets(2));
      expect(find.text(ar.languageEnglish), findsOneWidget);
    });

    testWidgets(
      'the sheet exposes which option is selected to assistive tech (F12-T01)',
      (tester) async {
        await pumpScreen(tester);

        await tester.tap(find.text(ar.settingsLanguageLabel));
        await tester.pumpAndSettle();

        // The last `العربية` in the tree is the sheet's own option — the
        // first is the row's value text, outside the sheet.
        expect(
          tester.getSemantics(find.text(ar.languageArabic).last),
          isSemantics(isSelected: true),
        );
        expect(
          tester.getSemantics(find.text(ar.languageEnglish)),
          isSemantics(isSelected: false),
        );
      },
    );

    testWidgets('selecting English persists and updates the row', (
      tester,
    ) async {
      await pumpScreen(tester);

      // Open picker.
      await tester.tap(find.text(ar.settingsLanguageLabel));
      await tester.pumpAndSettle();

      // Pick English.
      await tester.tap(find.text(ar.languageEnglish));
      await tester.pumpAndSettle();

      // Sheet dismissed, locale persisted.
      expect(await localeStore.readLanguageCode(), 'en');
      expect(localeCubit.state.languageCode, 'en');
    });

    testWidgets('selecting Arabic from English persists and updates', (
      tester,
    ) async {
      // Start with English.
      await localeStore.writeLanguageCode('en');
      await localeCubit.load();
      await pumpScreen(tester);

      // Open picker.
      await tester.tap(find.text(ar.settingsLanguageLabel));
      await tester.pumpAndSettle();

      // Pick Arabic.
      await tester.tap(find.text(ar.languageArabic));
      await tester.pumpAndSettle();

      expect(await localeStore.readLanguageCode(), 'ar');
      expect(localeCubit.state.languageCode, 'ar');
    });
  });

  group('the analysis consent toggle (F11-T02)', () {
    Finder consentSwitch() => find.descendant(
      of: find.byKey(settingsAnalysisConsentToggleKey),
      matching: find.byType(Switch),
    );

    testWidgets('shows the privacy section and the row, on by default', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text(ar.settingsPrivacySection), findsOneWidget);
      expect(tester.widget<Switch>(consentSwitch()).value, isTrue);
    });

    testWidgets('reflects a previously declined consent', (tester) async {
      await consentStore.writeConsent(false);
      await pumpScreen(tester);

      expect(tester.widget<Switch>(consentSwitch()).value, isFalse);
    });

    testWidgets('turning it off persists through the cubit', (tester) async {
      await pumpScreen(tester);

      await tester.tap(consentSwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(consentSwitch()).value, isFalse);
      expect(await consentStore.readConsent(), isFalse);
    });
  });

  group('the processing-mode row (F11-T03)', () {
    testWidgets('shows the row with the default smart-analysis label', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text(ar.settingsProcessingModeLabel), findsOneWidget);
      expect(find.text(ar.settingsProcessingModeSmartAnalysis), findsOneWidget);
    });

    testWidgets('reflects a persisted textOnly mode', (tester) async {
      await modeStore.writeMode(ProcessingMode.textOnly);
      await pumpScreen(tester);

      expect(find.text(ar.settingsProcessingModeTextOnly), findsOneWidget);
    });

    testWidgets('tapping the row opens the picker sheet', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text(ar.settingsProcessingModeLabel));
      await tester.pumpAndSettle();

      // Both options visible in the sheet.
      expect(
        find.text(ar.settingsProcessingModeSmartAnalysisDescription),
        findsOneWidget,
      );
      expect(
        find.text(ar.settingsProcessingModeTextOnlyDescription),
        findsOneWidget,
      );
    });

    testWidgets('selecting textOnly persists and updates the row', (
      tester,
    ) async {
      await pumpScreen(tester);

      // Open picker.
      await tester.tap(find.text(ar.settingsProcessingModeLabel));
      await tester.pumpAndSettle();

      // Pick text-only.
      await tester.tap(find.text(ar.settingsProcessingModeTextOnly).last);
      await tester.pumpAndSettle();

      // Sheet dismissed, row updated.
      expect(
        find.text(ar.settingsProcessingModeTextOnlyDescription),
        findsNothing,
      );
      expect(find.text(ar.settingsProcessingModeTextOnly), findsOneWidget);
      expect(await modeStore.readMode(), ProcessingMode.textOnly);
    });
  });

  group('the text-size row (F11-T05)', () {
    testWidgets('shows the display section with normal selected by default', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text(ar.settingsDisplaySection), findsOneWidget);
      expect(find.text(ar.settingsTextSizeLabel), findsOneWidget);
      expect(find.text(ar.settingsTextSizeNormal), findsOneWidget);
    });

    testWidgets('reflects a persisted large size', (tester) async {
      await textSizeStore.writeSize(TextSize.large);
      await textSizeCubit.load();
      await pumpScreen(tester);

      expect(find.text(ar.settingsTextSizeLarge), findsOneWidget);
    });

    testWidgets('tapping the row opens the text-size picker sheet', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text(ar.settingsTextSizeLabel));
      await tester.pumpAndSettle();

      // All three options visible in the sheet.
      expect(find.text(ar.settingsTextSizeNormalDescription), findsOneWidget);
      expect(find.text(ar.settingsTextSizeLargeDescription), findsOneWidget);
      expect(
        find.text(ar.settingsTextSizeVeryLargeDescription),
        findsOneWidget,
      );
    });

    testWidgets('selecting veryLarge persists and updates the row', (
      tester,
    ) async {
      await pumpScreen(tester);

      // Open picker.
      await tester.tap(find.text(ar.settingsTextSizeLabel));
      await tester.pumpAndSettle();

      // Pick very large.
      await tester.tap(find.text(ar.settingsTextSizeVeryLarge).last);
      await tester.pumpAndSettle();

      // Sheet dismissed, row updated.
      expect(find.text(ar.settingsTextSizeVeryLargeDescription), findsNothing);
      expect(find.text(ar.settingsTextSizeVeryLarge), findsOneWidget);
      expect(await textSizeStore.readSize(), TextSize.veryLarge);
    });
  });

  group('the high-contrast toggle (F11-T06)', () {
    Finder highContrastSwitch() => find.descendant(
      of: find.byKey(settingsHighContrastToggleKey),
      matching: find.byType(Switch),
    );

    testWidgets('shows the accessibility section and the row, off by default', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text(ar.settingsAccessibilitySection), findsOneWidget);
      expect(find.text(ar.settingsHighContrastLabel), findsOneWidget);
      expect(tester.widget<Switch>(highContrastSwitch()).value, isFalse);
    });

    testWidgets('reflects a previously enabled choice', (tester) async {
      await highContrastStore.writeEnabled(true);
      await pumpScreen(tester);

      expect(tester.widget<Switch>(highContrastSwitch()).value, isTrue);
    });

    testWidgets('turning it on persists through the cubit', (tester) async {
      await pumpScreen(tester);

      // The delete-all rows (F11-T11) added above this section can push it
      // below the fold, same reasoning every other row-tap in this file
      // already scrolls for.
      await tester.ensureVisible(highContrastSwitch());
      await tester.tap(highContrastSwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(highContrastSwitch()).value, isTrue);
      expect(await highContrastStore.readEnabled(), isTrue);
    });
  });

  group('the audio & reading defaults (F11-T07)', () {
    Finder resumeSwitch() => find.descendant(
      of: find.byKey(settingsResumeReadingToggleKey),
      matching: find.byType(Switch),
    );

    testWidgets('shows the section with 1x and resume on', (tester) async {
      await pumpScreen(tester);

      expect(find.text(ar.settingsAudioSection), findsOneWidget);
      expect(find.text(ar.settingsAudioSpeedLabel), findsOneWidget);
      expect(find.text(ReadingSpeed.normal.label), findsOneWidget);
      expect(find.text(ar.settingsAudioPreviewLabel), findsOneWidget);
      expect(tester.widget<Switch>(resumeSwitch()).value, isTrue);
    });

    testWidgets('reflects a persisted speed and resume choice', (tester) async {
      await speedStore.writeSpeed(ReadingSpeed.faster);
      await resumeStore.writeEnabled(false);
      await pumpScreen(tester);

      expect(find.text(ReadingSpeed.faster.label), findsOneWidget);
      expect(tester.widget<Switch>(resumeSwitch()).value, isFalse);
    });

    testWidgets('tapping the speed row opens the picker sheet', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsAudioSpeedLabel));
      await tester.tap(find.text(ar.settingsAudioSpeedLabel));
      await tester.pumpAndSettle();

      for (final speed in ReadingSpeed.values) {
        expect(find.text(speed.label), findsWidgets);
      }
    });

    testWidgets('selecting a new speed persists and updates the row', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsAudioSpeedLabel));
      await tester.tap(find.text(ar.settingsAudioSpeedLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ReadingSpeed.fastest.label).last);
      await tester.pumpAndSettle();

      expect(await speedStore.readSpeed(), ReadingSpeed.fastest);
      expect(find.text(ReadingSpeed.fastest.label), findsOneWidget);
    });

    testWidgets('tapping «تجربة الصوت» plays the sample text', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsAudioPreviewLabel));
      await tester.tap(find.text(ar.settingsAudioPreviewLabel));
      await tester.pumpAndSettle();

      expect(tts.spoken, [ar.settingsAudioPreviewSample]);
    });

    testWidgets(
      'a failed preview shows a snackbar rather than staying silent',
      (tester) async {
        tts.speakFails = true;
        await pumpScreen(tester);

        await tester.ensureVisible(find.text(ar.settingsAudioPreviewLabel));
        await tester.tap(find.text(ar.settingsAudioPreviewLabel));
        await tester.pumpAndSettle();

        expect(
          find.text(ar.settingsAudioPreviewFailedFeedback),
          findsOneWidget,
        );
      },
    );

    testWidgets('turning resume off persists through the cubit', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.ensureVisible(resumeSwitch());
      await tester.tap(resumeSwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(resumeSwitch()).value, isFalse);
      expect(await resumeStore.readEnabled(), isFalse);
    });
  });

  group('camera permission status (F11-T08)', () {
    testWidgets('shows the section with the granted pill by default', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsPermissionsSection));
      expect(find.text(ar.settingsPermissionsSection), findsOneWidget);
      expect(find.text(ar.settingsCameraPermissionLabel), findsOneWidget);
      // Both rows default to granted (F11-T09 added the notification row
      // alongside this one), so the pill text appears twice.
      expect(find.text(ar.settingsPermissionGranted), findsNWidgets(2));
      expect(find.text(ar.settingsOpenCameraSettingsLabel), findsOneWidget);
    });

    testWidgets('reflects a denied status', (tester) async {
      cameraPermissionRepo.status = PermissionOutcome.denied;
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsCameraPermissionLabel));
      expect(find.text(ar.settingsPermissionDenied), findsOneWidget);
    });

    testWidgets('reflects a permanently-denied status', (tester) async {
      cameraPermissionRepo.status = PermissionOutcome.permanentlyDenied;
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsCameraPermissionLabel));
      expect(find.text(ar.settingsPermissionBlocked), findsOneWidget);
    });

    testWidgets(
      'tapping «فتح إعدادات الكاميرا» calls through to the repository',
      (tester) async {
        await pumpScreen(tester);

        await tester.ensureVisible(
          find.byKey(settingsOpenCameraSettingsButtonKey),
        );
        await tester.tap(find.byKey(settingsOpenCameraSettingsButtonKey));
        await tester.pumpAndSettle();

        expect(cameraPermissionRepo.openSettingsCount, 1);
      },
    );
  });

  group('notification permission status (F11-T09)', () {
    testWidgets('shows the section with the granted pill by default', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.ensureVisible(
        find.text(ar.settingsNotificationPermissionLabel),
      );
      expect(find.text(ar.settingsNotificationPermissionLabel), findsOneWidget);
      // Both rows default to granted (the camera row alongside this one), so
      // the pill text appears twice.
      expect(find.text(ar.settingsPermissionGranted), findsNWidgets(2));
      expect(
        find.text(ar.settingsOpenNotificationSettingsLabel),
        findsOneWidget,
      );
    });

    testWidgets('reflects a denied status', (tester) async {
      notificationPermissionRepo.status = PermissionOutcome.denied;
      await pumpScreen(tester);

      await tester.ensureVisible(
        find.text(ar.settingsNotificationPermissionLabel),
      );
      expect(find.text(ar.settingsPermissionDenied), findsOneWidget);
    });

    testWidgets('reflects a permanently-denied status', (tester) async {
      notificationPermissionRepo.status = PermissionOutcome.permanentlyDenied;
      await pumpScreen(tester);

      await tester.ensureVisible(
        find.text(ar.settingsNotificationPermissionLabel),
      );
      expect(find.text(ar.settingsPermissionBlocked), findsOneWidget);
    });

    testWidgets(
      'tapping «فتح إعدادات الإشعارات» calls through to the repository',
      (tester) async {
        await pumpScreen(tester);

        await tester.ensureVisible(
          find.byKey(settingsOpenNotificationSettingsButtonKey),
        );
        await tester.tap(find.byKey(settingsOpenNotificationSettingsButtonKey));
        await tester.pumpAndSettle();

        expect(notificationPermissionRepo.openSettingsCount, 1);
      },
    );
  });

  group('the notification-privacy toggle (F11-T10)', () {
    Finder privacySwitch() => find.descendant(
      of: find.byKey(settingsNotificationPrivacyToggleKey),
      matching: find.byType(Switch),
    );

    testWidgets('shows the row, hidden (on) by default', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(
        find.text(ar.settingsNotificationPrivacyLabel),
      );
      expect(find.text(ar.settingsNotificationPrivacyLabel), findsOneWidget);
      expect(
        find.text(ar.settingsNotificationPrivacyDescription),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(privacySwitch()).value, isTrue);
    });

    testWidgets('reflects a previously revealed choice', (tester) async {
      await notificationPrivacyStore.writeHideSensitiveDetails(false);
      await pumpScreen(tester);

      await tester.ensureVisible(privacySwitch());
      expect(tester.widget<Switch>(privacySwitch()).value, isFalse);
    });

    testWidgets('turning it off persists through the cubit', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(privacySwitch());
      await tester.tap(privacySwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(privacySwitch()).value, isFalse);
      expect(
        await notificationPrivacyStore.readHideSensitiveDetails(),
        isFalse,
      );
    });
  });

  group('delete all documents (F11-T11)', () {
    testWidgets('shows the row', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsDeleteAllDocumentsLabel));
      expect(find.text(ar.settingsDeleteAllDocumentsLabel), findsOneWidget);
    });

    testWidgets('cancel dismisses without deleting anything', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsDeleteAllDocumentsLabel));
      await tester.tap(find.text(ar.settingsDeleteAllDocumentsLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.actionCancel));
      await tester.pumpAndSettle();

      expect(documentsRepository.deleteAllCalled, isFalse);
    });

    testWidgets('confirming deletes and shows a success snackbar', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsDeleteAllDocumentsLabel));
      await tester.tap(find.text(ar.settingsDeleteAllDocumentsLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.settingsDeleteAllConfirmAction));
      await tester.pumpAndSettle();

      expect(documentsRepository.deleteAllCalled, isTrue);
      expect(find.text(ar.settingsDeleteAllDocumentsSuccess), findsOneWidget);
    });

    testWidgets('a failure shows an error snackbar', (tester) async {
      documentsRepository.deleteAllOutcome = const Err(LocalDatabaseFailure());
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsDeleteAllDocumentsLabel));
      await tester.tap(find.text(ar.settingsDeleteAllDocumentsLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.settingsDeleteAllConfirmAction));
      await tester.pumpAndSettle();

      expect(find.text(ar.settingsDeleteAllDocumentsError), findsOneWidget);
    });
  });

  group('delete all reminders (F11-T11)', () {
    testWidgets('confirming deletes and reconciles', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsDeleteAllRemindersLabel));
      await tester.tap(find.text(ar.settingsDeleteAllRemindersLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.settingsDeleteAllConfirmAction));
      await tester.pumpAndSettle();

      expect(remindersRepository.deleteAllCalled, isTrue);
      expect(reminderScheduler.reconcileCount, 1);
      expect(find.text(ar.settingsDeleteAllRemindersSuccess), findsOneWidget);
    });

    testWidgets('cancel dismisses without deleting anything', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsDeleteAllRemindersLabel));
      await tester.tap(find.text(ar.settingsDeleteAllRemindersLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.actionCancel));
      await tester.pumpAndSettle();

      expect(remindersRepository.deleteAllCalled, isFalse);
    });
  });

  group('delete all app data (F11-T11)', () {
    testWidgets('confirming clears everything and shows a snackbar', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsDeleteAllAppDataLabel));
      await tester.tap(find.text(ar.settingsDeleteAllAppDataLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.settingsDeleteAllConfirmAction));
      await tester.pumpAndSettle();

      expect(documentsRepository.deleteAllCalled, isTrue);
      expect(remindersRepository.deleteAllCalled, isTrue);
      expect(settingsRepository.clearCalled, isTrue);
      expect(find.text(ar.settingsDeleteAllAppDataSuccess), findsOneWidget);
    });

    testWidgets('cancel dismisses without clearing anything', (tester) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsDeleteAllAppDataLabel));
      await tester.tap(find.text(ar.settingsDeleteAllAppDataLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.actionCancel));
      await tester.pumpAndSettle();

      expect(settingsRepository.clearCalled, isFalse);
    });
  });

  group('the about section (F11-T12)', () {
    testWidgets('shows the section, the two nav rows, and the version line', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsAboutSection));
      expect(find.text(ar.settingsAboutSection), findsOneWidget);
      expect(find.text(ar.settingsPrivacyPolicyLabel), findsOneWidget);
      expect(find.text(ar.settingsSupportedDocumentTypesLabel), findsOneWidget);
      expect(find.text(ar.settingsUsageLimitLabel), findsOneWidget);
      expect(find.text(ar.settingsVersionLabel('2.3.1')), findsOneWidget);
    });

    testWidgets('tapping «سياسة الخصوصية» calls the router callback', (
      tester,
    ) async {
      var opened = false;
      await pumpScreen(tester, onOpenPrivacyPolicy: () => opened = true);

      await tester.ensureVisible(find.text(ar.settingsPrivacyPolicyLabel));
      await tester.tap(find.text(ar.settingsPrivacyPolicyLabel));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });

    testWidgets(
      'tapping «أنواع الأوراق المدعومة» opens a sheet listing every category',
      (tester) async {
        await pumpScreen(tester);

        await tester.ensureVisible(
          find.text(ar.settingsSupportedDocumentTypesLabel),
        );
        await tester.tap(find.text(ar.settingsSupportedDocumentTypesLabel));
        await tester.pumpAndSettle();

        // The row's own label doubles as the sheet's title — two now.
        expect(
          find.text(ar.settingsSupportedDocumentTypesLabel),
          findsNWidgets(2),
        );
        expect(find.text(ar.documentCategoryAppointment), findsOneWidget);
        expect(find.text(ar.documentCategoryInvoice), findsOneWidget);
        expect(find.text(ar.documentCategoryGovernment), findsOneWidget);
        expect(find.text(ar.documentCategoryEducation), findsOneWidget);
        expect(find.text(ar.documentCategoryOther), findsOneWidget);
      },
    );

    testWidgets('shows «غير متاح دلوقتي» when nothing is cached yet', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsUsageLimitLabel));
      expect(find.text(ar.settingsUsageLimitUnavailable), findsOneWidget);
    });

    testWidgets('shows the cached quota as a pill', (tester) async {
      usageRepository.emit(usageWith(limit: 3, remaining: 1));
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsUsageLimitLabel));
      expect(find.text(ar.settingsUsageLimitValue(2, 3)), findsOneWidget);
    });
  });
}
