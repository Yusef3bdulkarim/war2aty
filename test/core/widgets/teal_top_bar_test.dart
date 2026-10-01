import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/widgets/teal_top_bar.dart';

import '../../support/pump_app.dart';

const _back = 'رجوع';
const _heading = 'نتيجة التحليل';

Future<void> _pump(
  WidgetTester tester, {
  String? heading,
  VoidCallback? onBack,
  Widget? trailing,
  Locale locale = AppLocalizations.arabic,
}) => pumpApp(
  tester,
  Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: TealTopBar(
        backTooltip: _back,
        heading: heading,
        onBack: onBack,
        trailing: trailing,
      ),
    ),
  ),
  locale: locale,
);

Transform get _arrowFlip => find
    .descendant(of: find.byTooltip(_back), matching: find.byType(Transform))
    .evaluate()
    .map((e) => e.widget as Transform)
    .first;

void main() {
  group('TealTopBar (F23-T02)', () {
    testWidgets('the arrow calls onBack', (tester) async {
      var backs = 0;
      await _pump(tester, onBack: () => backs++);

      await tester.tap(find.byTooltip(_back));

      expect(backs, 1);
    });

    testWidgets('announces the heading only when one is given', (tester) async {
      await _pump(tester, heading: _heading);
      expect(find.bySemanticsLabel(_heading), findsOneWidget);

      await _pump(tester);
      expect(find.bySemanticsLabel(_heading), findsNothing);
    });

    testWidgets('carries a trailing widget', (tester) async {
      await _pump(tester, trailing: const Icon(Icons.more_vert));

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('mirrors the arrow in an English layout only', (tester) async {
      await _pump(tester);
      expect(_arrowFlip.transform.storage[0], 1);

      await _pump(tester, locale: AppLocalizations.english);
      expect(_arrowFlip.transform.storage[0], -1);
    });

    testWidgets('heightOf matches the drawn bar', (tester) async {
      await _pump(tester);

      final context = tester.element(find.byType(TealTopBar));
      expect(
        tester.getSize(find.byType(TealTopBar)).height,
        TealTopBar.heightOf(context),
      );
    });
  });
}
