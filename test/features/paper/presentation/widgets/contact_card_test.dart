import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/paper/presentation/widgets/contact_card.dart';

import '../../../../support/pump_app.dart';

const _strings = ArStrings();

Future<void> _pumpCard(
  WidgetTester tester, {
  String name = 'مدرسة النور',
  String groupedPhone = '045 331 2244',
  bool isHighlighted = false,
  VoidCallback? onCall,
  bool settle = true,
}) => pumpApp(
  tester,
  Scaffold(
    body: ContactCard(
      name: name,
      groupedPhone: groupedPhone,
      onCall: onCall ?? () {},
      isHighlighted: isHighlighted,
    ),
  ),
  settle: settle,
);

void main() {
  group('ContactCard', () {
    testWidgets('shows the title, the phone icon, the name and number', (
      tester,
    ) async {
      await _pumpCard(tester);

      expect(find.text(_strings.paperContactCardTitle), findsOneWidget);
      expect(find.text('مدرسة النور'), findsOneWidget);
      expect(find.text('045 331 2244'), findsOneWidget);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon).first).glyph,
        StrokeGlyph.phone,
      );
    });

    testWidgets('lays the phone number out left-to-right', (tester) async {
      await _pumpCard(tester);

      expect(
        Directionality.of(tester.element(find.text('045 331 2244'))),
        TextDirection.ltr,
      );
    });

    testWidgets('is not highlighted by default', (tester) async {
      await _pumpCard(tester);

      expect(
        find.bySemanticsLabel(_strings.paperCardSpeakingLabel),
        findsNothing,
      );
    });

    testWidgets('shows the speaking indicator when highlighted', (
      tester,
    ) async {
      await _pumpCard(tester, isHighlighted: true, settle: false);

      expect(
        find.bySemanticsLabel(_strings.paperCardSpeakingLabel),
        findsOneWidget,
      );
    });

    testWidgets('the call button is labelled with the contact name', (
      tester,
    ) async {
      await _pumpCard(tester);

      expect(
        find.bySemanticsLabel(
          _strings.paperContactCardCallLabel('مدرسة النور'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the call button calls onCall', (tester) async {
      var tapCount = 0;
      await _pumpCard(tester, onCall: () => tapCount++);

      await tester.tap(
        find.bySemanticsLabel(
          _strings.paperContactCardCallLabel('مدرسة النور'),
        ),
      );

      expect(tapCount, 1);
    });
  });
}
