import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/paper/presentation/widgets/explain_card.dart';

import '../../../../support/pump_app.dart';

const _strings = ArStrings();

Future<void> _pumpCard(
  WidgetTester tester, {
  required List<String> paragraphs,
  bool isHighlighted = false,
  bool settle = true,
}) => pumpApp(
  tester,
  Scaffold(
    body: ExplainCard(paragraphs: paragraphs, isHighlighted: isHighlighted),
  ),
  settle: settle,
);

void main() {
  group('ExplainCard', () {
    testWidgets('shows the title, the icon and every paragraph', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        paragraphs: const ['الفقرة الأولى.', 'الفقرة الثانية.'],
      );

      expect(find.text(_strings.paperExplainCardTitle), findsOneWidget);
      expect(find.text('الفقرة الأولى.'), findsOneWidget);
      expect(find.text('الفقرة الثانية.'), findsOneWidget);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon)).glyph,
        StrokeGlyph.paperExplanationSheet,
      );
    });

    testWidgets('is not highlighted by default', (tester) async {
      await _pumpCard(tester, paragraphs: const ['نص.']);

      expect(
        find.bySemanticsLabel(_strings.paperCardSpeakingLabel),
        findsNothing,
      );
    });

    testWidgets('shows the speaking indicator when highlighted', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        paragraphs: const ['نص.'],
        isHighlighted: true,
        settle: false,
      );

      expect(
        find.bySemanticsLabel(_strings.paperCardSpeakingLabel),
        findsOneWidget,
      );
    });
  });
}
