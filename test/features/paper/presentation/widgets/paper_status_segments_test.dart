import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/paper/presentation/widgets/paper_status_segments.dart';

import '../../../../support/pump_app.dart';

const _colors = AppColors.light;

Future<void> _pumpSegments(
  WidgetTester tester, {
  required List<String> cardIds,
  String? activeId,
  double fillFraction = 0,
}) => pumpApp(
  tester,
  Scaffold(
    body: PaperStatusSegments(
      cardIds: cardIds,
      activeId: activeId,
      fillFraction: fillFraction,
    ),
  ),
);

double _fillOf(WidgetTester tester, String id) => tester
    .widget<FractionallySizedBox>(
      find.descendant(
        of: find.byKey(ValueKey('paper-status-segment-$id')),
        matching: find.byType(FractionallySizedBox),
      ),
    )
    .widthFactor!;

Color _trackColorOf(WidgetTester tester, String id) =>
    (tester
                .widget<Container>(
                  find.byKey(ValueKey('paper-status-segment-$id')),
                )
                .decoration!
            as BoxDecoration)
        .color!;

void main() {
  group('PaperStatusSegments', () {
    testWidgets('renders one equal-width segment per present card', (
      tester,
    ) async {
      await _pumpSegments(
        tester,
        cardIds: const ['explain', 'todo', 'date', 'caution', 'contact'],
      );

      final flexes = tester
          .widgetList<Expanded>(find.byType(Expanded))
          .map((widget) => widget.flex)
          .toSet();

      expect(flexes, {1});
      expect(find.byType(FractionallySizedBox), findsNWidgets(5));
    });

    testWidgets('a single card (the unsupported paper) gets one segment', (
      tester,
    ) async {
      await _pumpSegments(
        tester,
        cardIds: const ['explain'],
        activeId: 'explain',
        fillFraction: 0.4,
      );

      expect(find.byType(FractionallySizedBox), findsOneWidget);
      expect(_fillOf(tester, 'explain'), 0.4);
    });

    testWidgets('segments before the spoken card are full', (tester) async {
      await _pumpSegments(
        tester,
        cardIds: const ['explain', 'todo', 'date', 'caution'],
        activeId: 'date',
        fillFraction: 0.5,
      );

      expect(_fillOf(tester, 'explain'), 1.0);
      expect(_fillOf(tester, 'todo'), 1.0);
      expect(_fillOf(tester, 'date'), 0.5);
      expect(_fillOf(tester, 'caution'), 0.0);
    });

    testWidgets('fills with the voice within the spoken segment', (
      tester,
    ) async {
      await _pumpSegments(
        tester,
        cardIds: const ['explain', 'todo'],
        activeId: 'explain',
        fillFraction: 0.1,
      );
      expect(_fillOf(tester, 'explain'), 0.1);

      await _pumpSegments(
        tester,
        cardIds: const ['explain', 'todo'],
        activeId: 'explain',
        fillFraction: 0.9,
      );
      expect(_fillOf(tester, 'explain'), 0.9);
    });

    testWidgets('no active card leaves every segment empty', (tester) async {
      await _pumpSegments(
        tester,
        cardIds: const ['explain', 'todo', 'date', 'caution', 'contact'],
      );

      for (final id in ['explain', 'todo', 'date', 'caution', 'contact']) {
        expect(_fillOf(tester, id), 0.0);
      }
    });

    testWidgets('every card present fills all six segments', (tester) async {
      await _pumpSegments(
        tester,
        cardIds: const [
          'explain',
          'todo',
          'date',
          'caution',
          'contact',
          'place',
        ],
        activeId: 'place',
        fillFraction: 0.7,
      );

      for (final id in ['explain', 'todo', 'date', 'caution', 'contact']) {
        expect(_fillOf(tester, id), 1.0);
      }
      expect(_fillOf(tester, 'place'), 0.7);
    });

    testWidgets('clamps a fill fraction outside 0 to 1', (tester) async {
      await _pumpSegments(
        tester,
        cardIds: const ['explain', 'todo'],
        activeId: 'explain',
        fillFraction: 1.5,
      );
      expect(_fillOf(tester, 'explain'), 1.0);

      await _pumpSegments(
        tester,
        cardIds: const ['explain', 'todo'],
        activeId: 'explain',
        fillFraction: -0.3,
      );
      expect(_fillOf(tester, 'explain'), 0.0);
    });

    testWidgets('uses the brand colour for the fill and a soft track', (
      tester,
    ) async {
      await _pumpSegments(
        tester,
        cardIds: const ['explain', 'todo'],
        activeId: 'explain',
        fillFraction: 0.6,
      );

      expect(_trackColorOf(tester, 'explain'), _colors.borderSoft);
      final fractionBox = find.descendant(
        of: find.byKey(const ValueKey('paper-status-segment-explain')),
        matching: find.byType(FractionallySizedBox),
      );
      final fillDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: fractionBox,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(fillDecoration.color, _colors.brandPrimary);
    });

    testWidgets('is excluded from the semantics tree', (tester) async {
      await _pumpSegments(
        tester,
        cardIds: const ['explain', 'todo'],
        activeId: 'explain',
        fillFraction: 0.6,
      );

      expect(
        find.descendant(
          of: find.byType(PaperStatusSegments),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });
}
