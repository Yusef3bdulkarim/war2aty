import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/widgets/top_bar_icon_button.dart';

import '../../support/pump_app.dart';

void main() {
  group('TopBarIconButton (F12-T01)', () {
    testWidgets('renders at the 48dp minimum tap target', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: TopBarIconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {},
          ),
        ),
      );

      final size = tester.getSize(find.byType(TopBarIconButton));
      expect(size.width, TopBarIconButton.dimension);
      expect(size.height, TopBarIconButton.dimension);
      expect(TopBarIconButton.dimension, greaterThanOrEqualTo(48));
    });

    testWidgets('exposes the tooltip as a button label to assistive tech', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: TopBarIconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byTooltip('رجوع')),
        isSemantics(tooltip: 'رجوع', isButton: true, hasTapAction: true),
      );
    });

    testWidgets('a null onPressed disables the button', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: TopBarIconButton(tooltip: 'رجوع', icon: Icon(Icons.arrow_back)),
        ),
      );

      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    });

    testWidgets('tapping fires onPressed', (tester) async {
      var tapped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: TopBarIconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(TopBarIconButton));

      expect(tapped, isTrue);
    });
  });
}
