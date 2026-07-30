import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/presentation/widgets/expandable_panel.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_extracted_text_panel.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();

const _text =
    'شركة توزيع الكهرباء\n'
    'فاتورة استهلاك — شهر أغسطس 2026\n'
    'رقم المشترك: 624512';

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    VoidCallback? onListen,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(
      body: ResultExtractedTextPanel(text: _text, onListen: onListen),
    ),
    locale: locale,
    textScaler: textScaler,
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text(_strings.resultShowExtractedText));
    await tester.pumpAndSettle();
  }

  group('ResultExtractedTextPanel', () {
    testWidgets('names itself before it is opened', (tester) async {
      await pumpPanel(tester);

      // Collapsed, but never hidden: the text is always reachable (§5.12).
      expect(find.text(_strings.resultShowExtractedText), findsOneWidget);
      expect(find.text(_text), findsNothing);
    });

    testWidgets('shows what was read off the paper once opened', (
      tester,
    ) async {
      await pumpPanel(tester);
      await open(tester);

      expect(find.text(_text), findsOneWidget);
    });

    testWidgets('warns that the reading may be wrong', (tester) async {
      await pumpPanel(tester);
      await open(tester);

      expect(find.text(_strings.resultExtractedTextWarning), findsOneWidget);
    });

    testWidgets('closes again', (tester) async {
      await pumpPanel(tester);
      await open(tester);
      await tester.tap(find.text(_strings.resultShowExtractedText));
      await tester.pumpAndSettle();

      expect(find.text(_text), findsNothing);
    });

    testWidgets('copies the whole text', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpPanel(tester);
      await open(tester);
      await tester.tap(find.text(_strings.actionCopy));
      await tester.pumpAndSettle();

      expect(copied, [_text]);
      expect(find.text(_strings.ocrTextCopied), findsOneWidget);
    });

    testWidgets('leaves out listening while there is no reader', (
      tester,
    ) async {
      await pumpPanel(tester);
      await open(tester);

      expect(find.text(_strings.resultListenToText), findsNothing);
    });

    testWidgets('offers to read the text aloud when it can', (tester) async {
      var listened = 0;
      await pumpPanel(tester, onListen: () => listened++);
      await open(tester);
      await tester.tap(find.text(_strings.resultListenToText));
      await tester.pumpAndSettle();

      expect(listened, 1);
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpPanel(
        tester,
        onListen: () {},
        textScaler: const TextScaler.linear(2),
      );
      await open(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpPanel(tester, locale: AppLocalizations.english);

      expect(
        find.text(const EnStrings().resultShowExtractedText),
        findsOneWidget,
      );
    });
  });

  group('ExpandablePanel', () {
    testWidgets('tells assistive technology whether it is open', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: ExpandablePanel(label: 'عنوان', child: Text('جسم')),
        ),
      );

      expect(
        tester.getSemantics(find.text('عنوان')),
        isSemantics(isButton: true, hasExpandedState: true, isExpanded: false),
      );

      await tester.tap(find.text('عنوان'));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('عنوان')),
        isSemantics(isButton: true, hasExpandedState: true, isExpanded: true),
      );
    });
  });
}
