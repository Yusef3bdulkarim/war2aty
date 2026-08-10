import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/reading_mode.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/widgets/audio_options_sheet.dart';

import '../../support/pump_app.dart';

// F10-T03: the «الاستماع للورقة» mode-picker sheet.
const _strings = ArStrings();

void main() {
  Future<ReadingMode?> openSheet(
    WidgetTester tester, {
    ReadingMode initialMode = ReadingMode.summaryOnly,
  }) async {
    ReadingMode? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => result = await showAudioOptionsSheet(
            context,
            initialMode: initialMode,
          ),
          child: const Text('open'),
        ),
      ),
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

    testWidgets('confirms the mode already highlighted by default', (
      tester,
    ) async {
      ReadingMode? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryOnly,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(_strings.audioReaderStartLabel));
      await tester.pumpAndSettle();

      expect(result, ReadingMode.summaryOnly);
    });

    testWidgets('confirms whichever mode was tapped', (tester) async {
      ReadingMode? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryOnly,
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

      expect(result, ReadingMode.fullExplanation);
    });

    testWidgets('highlights whichever mode is reopened', (tester) async {
      ReadingMode? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryAndKeyInformation,
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

      expect(result, ReadingMode.summaryAndKeyInformation);
    });

    testWidgets('answers null when dismissed without choosing', (tester) async {
      final result = await openSheet(tester);
      // Tapping the scrim dismisses the sheet.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('lays out under Large Text', (tester) async {
      ReadingMode? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryOnly,
            ),
            child: const Text('open'),
          ),
        ),
        textScaler: const TextScaler.linear(2),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(result, isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => showAudioOptionsSheet(
              context,
              initialMode: ReadingMode.summaryOnly,
            ),
            child: const Text('open'),
          ),
        ),
        locale: AppLocalizations.english,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      const english = EnStrings();
      expect(find.text(english.audioReaderSheetTitle), findsOneWidget);
      expect(find.text(english.audioReaderModeSummary), findsOneWidget);
    });
  });
}
