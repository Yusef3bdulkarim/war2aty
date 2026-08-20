import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/bootstrap/presentation/widgets/pulsing_dots.dart';

import '../../support/pump_app.dart';

void main() {
  group('PulsingDots (F12-T02)', () {
    testWidgets('dots stay evenly spaced under RTL', (tester) async {
      // pumpApp defaults to Arabic (RTL) — the launch spinner's three dots
      // must read as evenly spaced regardless of direction. A non-directional
      // `EdgeInsets.only(right:)` gap would mirror wrong under RTL: two dots
      // touching, and the missing gap stranded at the row's far edge.
      await pumpApp(
        tester,
        const Center(child: PulsingDots(color: Colors.black)),
        settle: false, // the pulse animation repeats forever
      );
      await tester.pump(const Duration(milliseconds: 50));

      final dots = find.descendant(
        of: find.byType(PulsingDots),
        matching: find.byType(Container),
      );
      final centers = [
        0,
        1,
        2,
      ].map((i) => tester.getCenter(dots.at(i)).dx).toList()..sort();

      final gap1 = centers[1] - centers[0];
      final gap2 = centers[2] - centers[1];
      expect(gap1, closeTo(gap2, 0.5));
    });
  });
}
