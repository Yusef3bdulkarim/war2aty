import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/paper/presentation/widgets/todo_card.dart';

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
    body: TodoCard(text: text, isHighlighted: isHighlighted),
  ),
  settle: settle,
);

void main() {
  group('TodoCard', () {
    testWidgets('shows the title, the icon and the action text', (
      tester,
    ) async {
      await _pumpCard(tester, text: 'روح لأقرب فرع');

      expect(find.text(_strings.paperTodoCardTitle), findsOneWidget);
      expect(find.text('روح لأقرب فرع'), findsOneWidget);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon)).glyph,
        StrokeGlyph.paperChecklist,
      );
    });

    testWidgets('is not highlighted by default', (tester) async {
      await _pumpCard(tester, text: 'روح لأقرب فرع');

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
        text: 'روح لأقرب فرع',
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
