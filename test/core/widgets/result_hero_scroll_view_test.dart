import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/widgets/result_hero_scroll_view.dart';

import '../../support/pump_app.dart';

const _strings = ArStrings();
const _summary = 'فاتورة كهرباء لازم تتدفع قبل 15 أبريل.';
const _heading = 'نتيجة التحليل';
const _back = 'رجوع';
const _bodyKey = Key('body');

Future<void> _pump(
  WidgetTester tester, {
  String? summary = _summary,
  VoidCallback? onBack,
  Widget? trailing,
  Locale locale = AppLocalizations.arabic,
  TextScaler? textScaler,
}) => pumpApp(
  tester,
  Scaffold(
    body: ResultHeroScrollView(
      heading: _heading,
      backTooltip: _back,
      onBack: onBack,
      trailing: trailing,
      summary: summary,
      children: [Container(key: _bodyKey, height: 2000, color: Colors.white)],
    ),
  ),
  locale: locale,
  textScaler: textScaler,
);

/// The hero's gradient block — the only gradient on the page.
Finder get _heroBody => find.byWidgetPredicate(
  (widget) =>
      widget is DecoratedBox &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).gradient != null,
);

void main() {
  group('ResultHeroScrollView', () {
    testWidgets('shows «ملخص المستند» and the summary', (tester) async {
      await _pump(tester);

      expect(find.text(_strings.resultSummaryLabel), findsOneWidget);
      expect(find.text(_summary), findsOneWidget);
    });

    testWidgets('the body starts 12 px under the hero', (tester) async {
      await _pump(tester);

      final hero = tester.getRect(_heroBody);
      final body = tester.getRect(find.byKey(_bodyKey));
      expect(body.top - hero.bottom, moreOrLessEquals(12));
    });

    testWidgets('keeps the bar pinned while the hero scrolls away', (
      tester,
    ) async {
      await _pump(tester);
      final arrow = tester.getRect(find.byTooltip(_back));
      final summary = tester.getRect(find.text(_summary));

      await tester.dragFrom(const Offset(400, 400), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byTooltip(_back)), arrow);
      expect(tester.getRect(find.text(_summary)).top, lessThan(summary.top));
    });

    testWidgets('with no summary, the bar alone is the hero', (tester) async {
      await _pump(tester, summary: null);

      expect(find.text(_strings.resultSummaryLabel), findsNothing);
      expect(_heroBody, findsNothing);
      // The body starts right under the bar, with the usual 12 px gap.
      final bar = tester.getRect(find.byTooltip(_back));
      final body = tester.getRect(find.byKey(_bodyKey));
      expect(body.top, greaterThan(bar.bottom));
      expect(body.top - bar.bottom, lessThan(24));
    });

    testWidgets('treats a blank summary as none', (tester) async {
      await _pump(tester, summary: '   ');

      expect(find.text(_strings.resultSummaryLabel), findsNothing);
    });

    testWidgets('the arrow leaves the page', (tester) async {
      var backs = 0;
      await _pump(tester, onBack: () => backs++);

      await tester.tap(find.byTooltip(_back));

      expect(backs, 1);
    });

    testWidgets('carries a trailing action in the bar', (tester) async {
      await _pump(
        tester,
        trailing: IconButton(
          tooltip: 'المزيد',
          onPressed: () {},
          icon: const Icon(Icons.more_vert),
        ),
      );
      final trailing = tester.getRect(find.byTooltip('المزيد'));
      final summaryTop = tester.getTopLeft(find.text(_summary)).dy;

      await tester.dragFrom(const Offset(400, 400), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Pinned with the arrow (the page did scroll), and on the other side
      // of it in Arabic.
      expect(tester.getTopLeft(find.text(_summary)).dy, lessThan(summaryTop));
      expect(tester.getRect(find.byTooltip('المزيد')), trailing);
      expect(
        trailing.right,
        lessThan(tester.getRect(find.byTooltip(_back)).left),
      );
    });

    testWidgets('announces the page name as a heading', (tester) async {
      await _pump(tester);

      final heading = tester.getSemantics(find.bySemanticsLabel(_heading));
      expect(heading.flagsCollection.isHeader, isTrue);
      expect(find.text(_heading), findsNothing);
    });

    testWidgets('asks for light status-bar icons over the teal', (
      tester,
    ) async {
      await _pump(tester);

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).last,
      );
      expect(region.value, SystemUiOverlayStyle.light);
    });

    testWidgets('lays out under Large Text', (tester) async {
      await _pump(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
      expect(find.text(_summary), findsOneWidget);
    });

    testWidgets('follows the locale', (tester) async {
      await _pump(tester, locale: AppLocalizations.english);

      expect(find.text(const EnStrings().resultSummaryLabel), findsOneWidget);
    });
  });
}
