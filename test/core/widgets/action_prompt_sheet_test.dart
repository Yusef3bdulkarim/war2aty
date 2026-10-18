import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/widgets/action_prompt_sheet.dart';

import '../../support/pump_app.dart';

// F30-T07: the sheet that tells the user something they have to fix
// elsewhere, and offers the way there.
const _strings = ArStrings();

void main() {
  /// The sheet's own answer, which only arrives once it closes — so it is
  /// held here rather than returned by [openSheet], which returns as soon as
  /// the sheet is on screen.
  Future<bool>? answer;

  setUp(() => answer = null);

  Future<void> openSheet(
    WidgetTester tester, {
    String? actionLabel,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => answer = showActionPromptSheet(
            context,
            title: _strings.audioReaderNoArabicVoiceTitle,
            message: _strings.audioReaderNoArabicVoiceMessage,
            dismissLabel: _strings.audioReaderNoArabicVoiceDismiss,
            actionLabel: actionLabel,
          ),
          child: const Text('open'),
        ),
      ),
      locale: locale,
      textScaler: textScaler,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showActionPromptSheet', () {
    testWidgets('shows the title, the message and both buttons', (
      tester,
    ) async {
      await openSheet(
        tester,
        actionLabel: _strings.audioReaderNoArabicVoiceAction,
      );

      expect(find.text(_strings.audioReaderNoArabicVoiceTitle), findsOneWidget);
      expect(
        find.text(_strings.audioReaderNoArabicVoiceMessage),
        findsOneWidget,
      );
      expect(
        find.text(_strings.audioReaderNoArabicVoiceAction),
        findsOneWidget,
      );
      expect(
        find.text(_strings.audioReaderNoArabicVoiceDismiss),
        findsOneWidget,
      );
    });

    testWidgets('no action label means no action button at all', (
      tester,
    ) async {
      // A phone with no settings screen to reach must not be shown a button
      // that does nothing.
      await openSheet(tester);

      expect(find.text(_strings.audioReaderNoArabicVoiceAction), findsNothing);
      expect(
        find.text(_strings.audioReaderNoArabicVoiceDismiss),
        findsOneWidget,
      );
    });

    testWidgets('tapping the action answers true', (tester) async {
      await openSheet(
        tester,
        actionLabel: _strings.audioReaderNoArabicVoiceAction,
      );

      await tester.tap(find.text(_strings.audioReaderNoArabicVoiceAction));
      await tester.pumpAndSettle();

      expect(await answer, isTrue);
    });

    testWidgets('dismissing answers false, never true', (tester) async {
      await openSheet(
        tester,
        actionLabel: _strings.audioReaderNoArabicVoiceAction,
      );

      await tester.tap(find.text(_strings.audioReaderNoArabicVoiceDismiss));
      await tester.pumpAndSettle();

      expect(await answer, isFalse);
    });

    testWidgets('tapping outside the sheet answers false', (tester) async {
      await openSheet(
        tester,
        actionLabel: _strings.audioReaderNoArabicVoiceAction,
      );

      // Nothing here is destructive, but an ambiguous dismissal still must
      // not read as "yes, take me to the settings".
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(await answer, isFalse);
    });

    testWidgets('reads right-to-left in Arabic', (tester) async {
      await openSheet(
        tester,
        actionLabel: _strings.audioReaderNoArabicVoiceAction,
      );

      expect(
        Directionality.of(
          tester.element(find.text(_strings.audioReaderNoArabicVoiceTitle)),
        ),
        TextDirection.rtl,
      );
    });

    // §10: Large Text for any new screen. The message is four lines of
    // Arabic above two full-width buttons, so this is where it would break.
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('lays out at ${scale}x text with no overflow', (
        tester,
      ) async {
        await openSheet(
          tester,
          actionLabel: _strings.audioReaderNoArabicVoiceAction,
          textScaler: TextScaler.linear(scale),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.text(_strings.audioReaderNoArabicVoiceTitle),
          findsOneWidget,
        );
        expect(
          find.text(_strings.audioReaderNoArabicVoiceAction),
          findsOneWidget,
        );
      });
    }
  });
}
