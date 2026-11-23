import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/paper/presentation/widgets/place_card.dart';

import '../../../../support/pump_app.dart';

const _strings = ArStrings();

Future<void> _pumpCard(
  WidgetTester tester, {
  String address = 'مدرسة النور، شارع الجمهورية، دمنهور',
  bool isHighlighted = false,
  VoidCallback? onEnlarge,
  bool settle = true,
}) => pumpApp(
  tester,
  Scaffold(
    body: PlaceCard(
      address: address,
      onEnlarge: onEnlarge ?? () {},
      isHighlighted: isHighlighted,
    ),
  ),
  settle: settle,
);

void main() {
  group('PlaceCard', () {
    testWidgets('shows the title, the location icon and the address', (
      tester,
    ) async {
      await _pumpCard(tester);

      expect(find.text(_strings.paperPlaceCardTitle), findsOneWidget);
      expect(find.text('مدرسة النور، شارع الجمهورية، دمنهور'), findsOneWidget);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon).first).glyph,
        StrokeGlyph.locationPin,
      );
    });

    testWidgets('shows the enlarge button labelled for the driver', (
      tester,
    ) async {
      await _pumpCard(tester);

      expect(
        find.bySemanticsLabel(_strings.paperPlaceCardEnlargeLabel),
        findsOneWidget,
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

    testWidgets('tapping the enlarge button calls onEnlarge', (tester) async {
      var tapCount = 0;
      await _pumpCard(tester, onEnlarge: () => tapCount++);

      await tester.tap(
        find.bySemanticsLabel(_strings.paperPlaceCardEnlargeLabel),
      );

      expect(tapCount, 1);
    });
  });
}
