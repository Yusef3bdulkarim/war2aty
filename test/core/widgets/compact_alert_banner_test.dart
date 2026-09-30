import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/widgets/compact_alert_banner.dart';

import '../../support/pump_app.dart';

const _short = 'استشر محامي قبل اتخاذ أي إجراء قانوني.';

const _long =
    'التطبيق بيساعدك تفهم المكتوب في الورقة فقط، ومش بديل عن استشارة محامي '
    'متخصص قبل ما تمضي على أي حاجة أو تاخد أي إجراء قانوني بناءً عليها.';

Future<void> _pump(
  WidgetTester tester,
  String text, {
  String? semanticsLabel,
  TextScaler? textScaler,
}) => pumpApp(
  tester,
  Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 340,
        child: CompactAlertBanner(text: text, semanticsLabel: semanticsLabel),
      ),
    ),
  ),
  textScaler: textScaler,
);

void main() {
  group('CompactAlertBanner', () {
    testWidgets('is at least 48 px tall for a short text', (tester) async {
      await _pump(tester, _short);

      expect(
        tester.getSize(find.byType(CompactAlertBanner)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('grows with a long text instead of clipping it', (
      tester,
    ) async {
      await _pump(tester, _short);
      final shortHeight = tester
          .getSize(find.byType(CompactAlertBanner))
          .height;

      await _pump(tester, _long, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(CompactAlertBanner)).height,
        greaterThan(shortHeight),
      );
    });

    testWidgets('does not lean on colour alone', (tester) async {
      await _pump(tester, _short);

      // An icon and words carry the caution in greyscale or high contrast.
      expect(find.byType(StrokeIcon), findsOneWidget);
      expect(find.text(_short), findsOneWidget);
    });

    testWidgets('reads its text, or the label it is given', (tester) async {
      await _pump(tester, _short);
      expect(find.bySemanticsLabel(_short), findsOneWidget);

      await _pump(tester, _short, semanticsLabel: 'تنبيه مهم: $_short');
      expect(find.bySemanticsLabel('تنبيه مهم: $_short'), findsOneWidget);
    });
  });
}
