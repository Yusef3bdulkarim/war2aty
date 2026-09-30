import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/widgets/expandable_panel.dart';

import '../../support/pump_app.dart';

const _label = 'عرض الشرح التفصيلي';
const _bodyKey = Key('body');

Future<void> _pump(WidgetTester tester, {bool reducedMotion = false}) {
  final panel = Scaffold(
    body: SingleChildScrollView(
      child: ExpandablePanel(
        label: _label,
        child: Container(key: _bodyKey, height: 300, color: Colors.teal),
      ),
    ),
  );
  return pumpApp(
    tester,
    reducedMotion
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: panel,
            ),
          )
        : panel,
  );
}

double _panelHeight(WidgetTester tester) =>
    tester.getSize(find.byType(ExpandablePanel)).height;

void main() {
  group('ExpandablePanel', () {
    testWidgets('starts shut, with the body not built at all', (tester) async {
      await _pump(tester);

      expect(find.text(_label), findsOneWidget);
      expect(find.byKey(_bodyKey), findsNothing);
    });

    testWidgets('slides open in place', (tester) async {
      await _pump(tester);
      final shut = _panelHeight(tester);

      await tester.tap(find.text(_label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      // Halfway: the body is there and the panel is growing, not jumped open.
      final halfway = _panelHeight(tester);
      expect(find.byKey(_bodyKey), findsOneWidget);
      expect(halfway, greaterThan(shut));

      await tester.pumpAndSettle();
      expect(_panelHeight(tester), greaterThan(halfway));
    });

    testWidgets('slides shut, then drops the body', (tester) async {
      await _pump(tester);
      await tester.tap(find.text(_label));
      await tester.pumpAndSettle();
      final open = _panelHeight(tester);

      await tester.tap(find.text(_label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      // Still sliding: shrinking, with the body on its way out.
      expect(find.byKey(_bodyKey), findsOneWidget);
      expect(_panelHeight(tester), lessThan(open));

      await tester.pumpAndSettle();
      expect(find.byKey(_bodyKey), findsNothing);
    });

    testWidgets('under reduced motion it opens and shuts at once', (
      tester,
    ) async {
      await _pump(tester, reducedMotion: true);

      await tester.tap(find.text(_label));
      await tester.pump();
      expect(find.byKey(_bodyKey), findsOneWidget);
      // Full height after one frame — no slide. (The tap ripple still runs,
      // so `hasRunningAnimations` would not tell the two apart.)
      expect(tester.getSize(find.byKey(_bodyKey)).height, 300);

      await tester.tap(find.text(_label));
      await tester.pump();
      expect(find.byKey(_bodyKey), findsNothing);
    });

    testWidgets('tells a screen reader whether it is open', (tester) async {
      await _pump(tester);

      final header = find.ancestor(
        of: find.text(_label),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.expanded != null,
        ),
      );
      expect(tester.widget<Semantics>(header).properties.expanded, isFalse);

      await tester.tap(find.text(_label));
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(header).properties.expanded, isTrue);
    });
  });
}
