import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/paper/presentation/widgets/caution_card.dart';

import '../../../../support/pump_app.dart';

const _strings = ArStrings();

Future<void> _pumpCard(
  WidgetTester tester, {
  required String text,
  bool isHighlighted = false,
  bool settle = true,
}) => pumpApp(
  tester,
  Scaffold(
    body: CautionCard(text: text, isHighlighted: isHighlighted),
  ),
  settle: settle,
);

void main() {
  group('CautionCard', () {
    testWidgets('shows the title, the warning icon and the caution text', (
      tester,
    ) async {
      await _pumpCard(tester, text: 'لازم تبلّغ المدرسة قبل الميعاد');

      expect(find.text(_strings.paperCautionCardTitle), findsOneWidget);
      expect(find.text('لازم تبلّغ المدرسة قبل الميعاد'), findsOneWidget);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon)).glyph,
        StrokeGlyph.warningTriangle,
      );
    });

    testWidgets('is not highlighted by default', (tester) async {
      await _pumpCard(tester, text: 'لازم تبلّغ المدرسة قبل الميعاد');

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
        text: 'لازم تبلّغ المدرسة قبل الميعاد',
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
