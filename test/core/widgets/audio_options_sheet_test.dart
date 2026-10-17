import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/audio/reading_speed.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/widgets/audio_options_sheet.dart';

import '../../support/pump_app.dart';

// F10-T03: the «الاستماع للورقة» mode-picker sheet. F10-T06 adds its
// «سرعة القراءة» speed row.
const _strings = ArStrings();

void main() {
  // Opens the sheet without ever confirming it — for tests that only care
  // what is drawn, or that dismissing/never-choosing answers `null`.
  Future<AudioReadingChoice?> openSheet(
    WidgetTester tester, {
    ReadingMode initialMode = ReadingMode.summaryOnly,
    ReadingSpeed initialSpeed = ReadingSpeed.normal,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) async {
    AudioReadingChoice? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => result = await showAudioOptionsSheet(
            context,
            initialMode: initialMode,
            initialSpeed: initialSpeed,
          ),
          child: const Text('open'),
        ),
      ),
      locale: locale,
      textScaler: textScaler,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  group('AudioOptionsSheet', () {
    testWidgets('shows the title and the three offered modes', (tester) async {
      await openSheet(tester);

      expect(find.text(_strings.audioReaderSheetTitle), findsOneWidget);
      expect(find.text(_strings.audioReaderModeSummary), findsOneWidget);
      expect(
        find.text(_strings.audioReaderModeSummaryAndKeyInformation),
        findsOneWidget,
      );
      expect(find.text(_strings.audioReaderModeFull), findsOneWidget);
      // The fourth mode has no analysis to summarise — never offered here.
      expect(find.text(_strings.audioReaderModeExtractedText), findsNothing);
    });

    testWidgets('exposes which mode is selected to assistive tech (F12-T01)', (
      tester,
    ) async {
      await openSheet(tester);

      expect(
        tester.getSemantics(find.text(_strings.audioReaderModeSummary)),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.text(_strings.audioReaderModeFull)),
        isSemantics(isSelected: false),
      );
    });

    testWidgets('confirms the mode already highlighted by default', (
      tester,
    ) async {
      AudioReadingChoice? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryOnly,
              initialSpeed: ReadingSpeed.normal,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(result?.mode, ReadingMode.summaryOnly);
    });

    testWidgets('confirms whichever mode was tapped', (tester) async {
      AudioReadingChoice? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryOnly,
              initialSpeed: ReadingSpeed.normal,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(_strings.audioReaderModeFull));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(result?.mode, ReadingMode.fullExplanation);
    });

    testWidgets('highlights whichever mode is reopened', (tester) async {
      AudioReadingChoice? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryAndKeyInformation,
              initialSpeed: ReadingSpeed.normal,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Confirming without picking anything else keeps the reopened mode.
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(result?.mode, ReadingMode.summaryAndKeyInformation);
    });

    testWidgets('answers null when dismissed without choosing', (tester) async {
      final result = await openSheet(tester);
      // Tapping the scrim dismisses the sheet.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('lays out under Large Text', (tester) async {
      final result = await openSheet(
        tester,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(result, isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await openSheet(tester, locale: AppLocalizations.english);

      const english = EnStrings();
      expect(find.text(english.audioReaderSheetTitle), findsOneWidget);
      expect(find.text(english.audioReaderModeSummary), findsOneWidget);
    });
  });

  group('the playback controls stay left-to-right', () {
    // Material's bidirectionality guidance: media playback controls are not
    // mirrored, because they show the direction of the tape, not of reading.
    // The row was laid out RTL in Arabic, which put ▶▶ on the left and ◀◀ on
    // the right — each arrow pointing away from where it sat, either side of
    // a play button that still pointed right.
    double centreX(WidgetTester tester, IconData icon) =>
        tester.getCenter(find.byIcon(icon)).dx;

    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('rewind is on the left and forward on the right — $locale', (
        tester,
      ) async {
        await openSheet(tester, locale: locale);

        final rewind = centreX(tester, Icons.fast_rewind_rounded);
        final play = centreX(tester, Icons.play_arrow_rounded);
        final forward = centreX(tester, Icons.fast_forward_rounded);

        expect(rewind, lessThan(play), reason: 'rewind sits left of play');
        expect(play, lessThan(forward), reason: 'forward sits right of play');
      });
    }

    testWidgets("the play button keeps the app's own direction", (
      tester,
    ) async {
      // Only the row's order is forced left-to-right. The play button's
      // Arabic tooltip is what a screen reader announces, and it must not
      // inherit the row's direction.
      await openSheet(tester);

      expect(
        Directionality.of(
          tester.element(find.byIcon(Icons.play_arrow_rounded)),
        ),
        TextDirection.rtl,
      );
    });
  });

  group('the speed row (F10-T06)', () {
    testWidgets('shows the label and all four speeds', (tester) async {
      await openSheet(tester);

      expect(find.text(_strings.audioReaderSpeedLabel), findsOneWidget);
      for (final speed in ReadingSpeed.values) {
        expect(find.text(speed.label), findsOneWidget);
      }
    });

    testWidgets('exposes which speed is selected to assistive tech (F12-T01)', (
      tester,
    ) async {
      await openSheet(tester);

      expect(
        tester.getSemantics(find.text(ReadingSpeed.normal.label)),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.text(ReadingSpeed.fastest.label)),
        isSemantics(isSelected: false),
      );
    });

    testWidgets('confirming without picking a speed keeps the default', (
      tester,
    ) async {
      AudioReadingChoice? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryOnly,
              initialSpeed: ReadingSpeed.normal,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(result?.speed, ReadingSpeed.normal);
    });

    testWidgets('confirms whichever speed was tapped', (tester) async {
      AudioReadingChoice? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryOnly,
              initialSpeed: ReadingSpeed.normal,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ReadingSpeed.fastest.label));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(result?.speed, ReadingSpeed.fastest);
      // The mode untouched by this run stays whatever it was reopened with.
      expect(result?.mode, ReadingMode.summaryOnly);
    });

    testWidgets('highlights whichever speed is reopened', (tester) async {
      AudioReadingChoice? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryOnly,
              initialSpeed: ReadingSpeed.faster,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Confirming without picking anything else keeps the reopened speed.
      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(result?.speed, ReadingSpeed.faster);
    });
  });
}
