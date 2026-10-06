import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/theme/app_colors.dart';
import 'package:war2aty/core/widgets/teal_top_bar.dart';

import '../../support/pump_app.dart';
import '../../support/ui_audit.dart';

const _back = 'رجوع';
const _heading = 'نتيجة التحليل';
const _title = 'تفاصيل التذكير';

Future<void> _pump(
  WidgetTester tester, {
  String? heading,
  String? title,
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
        title: title,
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

    testWidgets('draws no title unless one is given (F26-T01)', (tester) async {
      await _pump(tester);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('draws a given title in white as the page heading', (
      tester,
    ) async {
      await _pump(tester, title: _title);

      final text = tester.widget<Text>(find.text(_title));
      final context = tester.element(find.text(_title));
      expect(text.style?.color, AppColors.of(context).onBrand);
      expect(
        tester.getSemantics(find.text(_title)),
        matchesSemantics(label: _title, isHeader: true),
      );
    });

    testWidgets('centres the title between the arrow and its balance', (
      tester,
    ) async {
      await _pump(tester, title: _title);

      final bar = tester.getRect(find.byType(TealTopBar));
      final title = tester.getRect(
        find.ancestor(of: find.text(_title), matching: find.byType(Expanded)),
      );
      expect(title.center.dx, moreOrLessEquals(bar.center.dx));
    });

    testWidgets('a title grows the bar at a large text scale', (tester) async {
      // A phone's width is what makes a long title wrap at ×2; the test
      // window's 800 dp does not, now that Cairo's real metrics apply
      // (F27-T15).
      setAuditSurface(tester);
      await pumpApp(
        tester,
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: TealTopBar(
                backTooltip: _back,
                title: 'سياسة الخصوصية والاستخدام الطويلة جدًا',
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(TealTopBar));
      expect(
        tester.getSize(find.byType(TealTopBar)).height,
        greaterThan(TealTopBar.heightOf(context)),
      );
      expect(tester.takeException(), isNull);
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
