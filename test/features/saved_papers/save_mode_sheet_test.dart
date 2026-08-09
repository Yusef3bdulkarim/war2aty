import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/saved_papers/presentation/widgets/save_mode_sheet.dart';

import '../../support/pump_app.dart';

const _strings = ArStrings();

void main() {
  group('showSaveModeSheet', () {
    // Opens the sheet over a plain trigger button and hands back a box the
    // test can read after interacting with it — `showSaveModeSheet` only
    // resolves once the sheet closes, so the answer isn't available sooner.
    Future<List<DocumentStorageMode?>> pumpOpenSheet(
      WidgetTester tester,
    ) async {
      final answer = <DocumentStorageMode?>[];
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                answer.add(await showSaveModeSheet(context));
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('defaults to result-only and confirms it', (tester) async {
      final answer = await pumpOpenSheet(tester);

      await tester.tap(find.text(_strings.actionSave));
      await tester.pumpAndSettle();

      expect(answer, [DocumentStorageMode.resultOnly]);
    });

    testWidgets('confirms withImage once that option is picked', (
      tester,
    ) async {
      final answer = await pumpOpenSheet(tester);

      await tester.tap(find.text(_strings.saveModeWithImageTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_strings.actionSave));
      await tester.pumpAndSettle();

      expect(answer, [DocumentStorageMode.withImage]);
    });

    testWidgets('answers null when dismissed without confirming', (
      tester,
    ) async {
      final answer = await pumpOpenSheet(tester);

      // Tapping the scrim dismisses the sheet.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(answer, [null]);
    });
  });

  group('SaveModeSheet', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      Locale locale = AppLocalizations.arabic,
      TextScaler? textScaler,
    }) => pumpApp(
      tester,
      const Scaffold(body: SaveModeSheet()),
      locale: locale,
      textScaler: textScaler,
    );

    testWidgets('shows both choices, result-only highlighted by default', (
      tester,
    ) async {
      await pumpSheet(tester);

      expect(find.text(_strings.saveModeResultOnlyTitle), findsOneWidget);
      expect(find.text(_strings.saveModeWithImageTitle), findsOneWidget);
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpSheet(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpSheet(tester, locale: AppLocalizations.english);

      const english = EnStrings();
      expect(find.text(english.saveModeResultOnlyTitle), findsOneWidget);
      expect(find.text(english.saveModeWithImageTitle), findsOneWidget);
      expect(find.text(english.actionSave), findsOneWidget);
    });
  });
}
