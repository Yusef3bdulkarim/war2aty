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
import 'package:war2aty/core/audio/tts_voice.dart';
import 'package:war2aty/core/audio/usecases/get_available_voices.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/get_default_reading_voice.dart';
import 'package:war2aty/core/audio/usecases/get_resume_reading_enabled.dart';
import 'package:war2aty/core/audio/usecases/preview_default_voice.dart';
import 'package:war2aty/core/audio/usecases/set_default_reading_speed.dart';
import 'package:war2aty/core/audio/usecases/set_default_reading_voice.dart';
import 'package:war2aty/core/audio/usecases/set_resume_reading_enabled.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/localization/locale_cubit.dart';
import 'package:war2aty/core/localization/usecases/get_saved_locale.dart';
import 'package:war2aty/core/localization/usecases/set_locale.dart';
import 'package:war2aty/core/permissions/permission_service.dart';
import 'package:war2aty/core/permissions/usecases/get_notification_permission.dart';
import 'package:war2aty/core/permissions/usecases/open_notification_permission_settings.dart';
import 'package:war2aty/core/reminders/usecases/get_hide_sensitive_notification_details.dart';
import 'package:war2aty/core/reminders/usecases/set_hide_sensitive_notification_details.dart';
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
    cubit = SettingsCubit(
      getAnalysisConsent: GetAnalysisConsent(consentStore),
      setAnalysisConsent: SetAnalysisConsent(consentStore),
      getProcessingMode: GetProcessingMode(modeStore),
      setProcessingMode: SetProcessingMode(modeStore),
      getDefaultReadingSpeed: GetDefaultReadingSpeed(speedStore),
      setDefaultReadingSpeed: SetDefaultReadingSpeed(speedStore),
      getDefaultReadingVoice: GetDefaultReadingVoice(voiceStore),
      setDefaultReadingVoice: SetDefaultReadingVoice(voiceStore),
      getResumeReadingEnabled: GetResumeReadingEnabled(resumeStore),
      setResumeReadingEnabled: SetResumeReadingEnabled(resumeStore),
      getAvailableVoices: GetAvailableVoices(tts),
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
        child: const Scaffold(body: SettingsScreen()),
      ),
      locale: locale,
      textScaler: textScaler,
    );
  }

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

    testWidgets('shows the section with 1x, the default voice and resume on', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text(ar.settingsAudioSection), findsOneWidget);
      expect(find.text(ar.settingsAudioSpeedLabel), findsOneWidget);
      expect(find.text(ReadingSpeed.normal.label), findsOneWidget);
      expect(find.text(ar.settingsAudioVoiceLabel), findsOneWidget);
      expect(find.text(ar.settingsAudioVoiceDefault), findsOneWidget);
      expect(find.text(ar.settingsAudioPreviewLabel), findsOneWidget);
      expect(tester.widget<Switch>(resumeSwitch()).value, isTrue);
    });

    testWidgets('reflects a persisted speed, voice and resume choice', (
      tester,
    ) async {
      const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
      await speedStore.writeSpeed(ReadingSpeed.faster);
      await voiceStore.writeVoice(voice);
      await resumeStore.writeEnabled(false);
      tts.voices = const [voice];
      await pumpScreen(tester);

      expect(find.text(ReadingSpeed.faster.label), findsOneWidget);
      expect(find.text(voice.name), findsOneWidget);
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

    testWidgets('tapping the voice row lists the device voices', (
      tester,
    ) async {
      const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
      tts.voices = const [voice];
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsAudioVoiceLabel));
      await tester.tap(find.text(ar.settingsAudioVoiceLabel));
      await tester.pumpAndSettle();

      expect(find.text(ar.settingsAudioVoiceDefault), findsWidgets);
      expect(find.text(voice.name), findsOneWidget);
    });

    testWidgets('selecting a device voice persists and updates the row', (
      tester,
    ) async {
      const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
      tts.voices = const [voice];
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(ar.settingsAudioVoiceLabel));
      await tester.tap(find.text(ar.settingsAudioVoiceLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(voice.name));
      await tester.pumpAndSettle();

      expect(await voiceStore.readVoice(), voice);
      expect(find.text(voice.name), findsOneWidget);
    });

    testWidgets('selecting «الصوت الافتراضي» again resets a picked voice', (
      tester,
    ) async {
      const voice = TtsVoice(name: 'Maged', locale: 'ar-EG');
      await voiceStore.writeVoice(voice);
      tts.voices = const [voice];
      await pumpScreen(tester);

      await tester.ensureVisible(find.text(voice.name));
      await tester.tap(find.text(voice.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.settingsAudioVoiceDefault).last);
      await tester.pumpAndSettle();

      expect(await voiceStore.readVoice(), isNull);
      expect(find.text(ar.settingsAudioVoiceDefault), findsOneWidget);
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
}
