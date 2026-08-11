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
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/localization/locale_cubit.dart';
import 'package:war2aty/core/localization/usecases/get_saved_locale.dart';
import 'package:war2aty/core/localization/usecases/set_locale.dart';
import 'package:war2aty/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:war2aty/features/settings/presentation/screens/settings_screen.dart';

import '../../../../support/fakes.dart';
import '../../../../support/pump_app.dart';

// F11-T01/T02/T03/T04/T05/T06: the settings scaffold, the analysis consent
// toggle, the processing-mode picker, the language switch, the text-size
// picker, and the high-contrast toggle.
void main() {
  const ar = ArStrings();

  late FakeAnalysisConsentStore consentStore;
  late FakeProcessingModeStore modeStore;
  late FakeLocaleStore localeStore;
  late FakeTextSizeStore textSizeStore;
  late FakeHighContrastStore highContrastStore;
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
    cubit = SettingsCubit(
      getAnalysisConsent: GetAnalysisConsent(consentStore),
      setAnalysisConsent: SetAnalysisConsent(consentStore),
      getProcessingMode: GetProcessingMode(modeStore),
      setProcessingMode: SetProcessingMode(modeStore),
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
        child: const SettingsScreen(),
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
}
