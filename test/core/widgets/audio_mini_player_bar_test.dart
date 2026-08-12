import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/widgets/audio_mini_player_bar.dart';

import '../../support/pump_app.dart';

// F10-T03: the result page's «بيقرأ: …» mini-player bar.
const _strings = ArStrings();

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    String modeLabel = 'الخلاصة فقط',
    bool isPlaying = true,
    double progress = 0.42,
    VoidCallback? onTogglePlayPause,
    VoidCallback? onOptions,
    VoidCallback? onStop,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: AudioMiniPlayerBar(
          modeLabel: modeLabel,
          isPlaying: isPlaying,
          progress: progress,
          onTogglePlayPause: onTogglePlayPause ?? () {},
          onOptions: onOptions ?? () {},
          onStop: onStop ?? () {},
        ),
      ),
    ),
    locale: locale,
    textScaler: textScaler,
  );

  group('AudioMiniPlayerBar', () {
    testWidgets('names the mode it is reading', (tester) async {
      await pumpBar(tester, modeLabel: 'الشرح كامل');

      expect(
        find.text(_strings.audioReaderNowReading('الشرح كامل')),
        findsOneWidget,
      );
    });

    testWidgets('shows pause while playing and offers to resume when not', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(find.byTooltip(_strings.audioReaderPauseLabel), findsOneWidget);
      expect(find.byTooltip(_strings.audioReaderResumeLabel), findsNothing);

      await pumpBar(tester, isPlaying: false);
      expect(find.byTooltip(_strings.audioReaderResumeLabel), findsOneWidget);
      expect(find.byTooltip(_strings.audioReaderPauseLabel), findsNothing);
    });

    testWidgets('toggling play/pause runs the callback', (tester) async {
      var toggled = 0;
      await pumpBar(tester, onTogglePlayPause: () => toggled++);

      await tester.tap(find.byTooltip(_strings.audioReaderPauseLabel));
      await tester.pumpAndSettle();

      expect(toggled, 1);
    });

    testWidgets('«خيارات» reopens the mode-picker', (tester) async {
      var opened = 0;
      await pumpBar(tester, onOptions: () => opened++);

      await tester.tap(find.text(_strings.audioReaderOptions));
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('stopping runs the callback', (tester) async {
      var stopped = 0;
      await pumpBar(tester, onStop: () => stopped++);

      await tester.tap(find.byTooltip(_strings.audioReaderStopLabel));
      await tester.pumpAndSettle();

      expect(stopped, 1);
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpBar(
        tester,
        modeLabel: 'الخلاصة وأهم المعلومات',
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpBar(
        tester,
        modeLabel: 'Summary only',
        locale: AppLocalizations.english,
      );

      const english = EnStrings();
      expect(
        find.text(english.audioReaderNowReading('Summary only')),
        findsOneWidget,
      );
      expect(find.text(english.audioReaderOptions), findsOneWidget);
    });
  });
}
