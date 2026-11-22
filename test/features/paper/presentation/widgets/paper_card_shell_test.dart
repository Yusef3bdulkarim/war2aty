import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/features/paper/presentation/widgets/paper_card_shell.dart';

import '../../../../support/pump_app.dart';

const _strings = ArStrings();
const _colors = AppColors.light;

BoxDecoration _cardDecoration(WidgetTester tester) =>
    tester
            .widget<Container>(find.byKey(const ValueKey('paper-card-shell')))
            .decoration!
        as BoxDecoration;

BoxDecoration _iconDecoration(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.byKey(const ValueKey('paper-card-icon-box')),
            )
            .decoration!
        as BoxDecoration;

Future<void> _pumpShell(
  WidgetTester tester, {
  bool isHighlighted = false,
  bool settle = true,
}) => pumpApp(
  tester,
  Scaffold(
    body: PaperCardShell(
      icon: StrokeGlyph.check,
      title: 'عنوان الكارت',
      titleColor: _colors.textBody,
      background: _colors.card,
      borderColor: _colors.borderSoft,
      iconBackground: _colors.surfaceTealAlt,
      iconColor: _colors.brandPrimary,
      isHighlighted: isHighlighted,
      child: const Text('Child content'),
    ),
  ),
  settle: settle,
);

void main() {
  group('PaperCardShell', () {
    testWidgets('shows the title as a header and the child', (tester) async {
      await _pumpShell(tester);

      expect(
        tester.getSemantics(find.text('عنوان الكارت')),
        isSemantics(isHeader: true),
      );
      expect(find.text('Child content'), findsOneWidget);
    });

    testWidgets('uses the given colors when not highlighted', (tester) async {
      await _pumpShell(tester);

      final card = _cardDecoration(tester);
      expect(card.color, _colors.card);
      expect(card.border!.top.color, _colors.borderSoft);
      expect(card.border!.top.width, 1);

      final icon = _iconDecoration(tester);
      expect(icon.color, _colors.surfaceTealAlt);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon)).color,
        _colors.brandPrimary,
      );

      expect(
        find.bySemanticsLabel(_strings.paperCardSpeakingLabel),
        findsNothing,
      );
    });

    testWidgets('switches to the highlight treatment when isHighlighted', (
      tester,
    ) async {
      await _pumpShell(tester, isHighlighted: true, settle: false);

      final card = _cardDecoration(tester);
      expect(card.color, _colors.surfaceTeal);
      expect(card.border!.top.color, _colors.brandPrimary);
      expect(card.border!.top.width, 2);

      final icon = _iconDecoration(tester);
      expect(icon.color, _colors.brandPrimary);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon)).color,
        _colors.onBrand,
      );

      expect(
        find.bySemanticsLabel(_strings.paperCardSpeakingLabel),
        findsOneWidget,
      );
    });
  });
}
