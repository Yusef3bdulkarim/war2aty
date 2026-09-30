import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/widgets/caveat_badge.dart';
import 'package:war2aty/core/widgets/caveated_value.dart';

import '../../support/pump_app.dart';

const _strings = ArStrings();

const _valueKey = Key('value');

Future<void> _pump(
  WidgetTester tester, {
  required String value,
  List<String> caveats = const [],
  double width = 320,
  TextScaler? textScaler,
}) => pumpApp(
  tester,
  Scaffold(
    body: Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        child: CaveatedValue(
          value: Text(value, key: _valueKey),
          caveats: caveats,
        ),
      ),
    ),
  ),
  textScaler: textScaler,
);

void main() {
  group('CaveatedValue', () {
    testWidgets('a sure value stands alone', (tester) async {
      await _pump(tester, value: '750');

      expect(find.text('750'), findsOneWidget);
      expect(find.byType(CaveatBadge), findsNothing);
    });

    testWidgets('puts the caution on the value\'s own line when it fits', (
      tester,
    ) async {
      await _pump(tester, value: '750', caveats: [_strings.confidenceReview]);

      final value = tester.getRect(find.byKey(_valueKey));
      final chip = tester.getRect(find.byType(CaveatBadge));
      // Same line: the two overlap vertically…
      expect(chip.top, lessThan(value.bottom));
      expect(chip.bottom, greaterThan(value.top));
      // …and in Arabic the chip follows the value leftwards.
      expect(chip.right, lessThanOrEqualTo(value.left));
    });

    testWidgets('drops the caution under the value when the line is full', (
      tester,
    ) async {
      await _pump(
        tester,
        value: 'مصلحة الضرائب المصرية — مأمورية شمال القاهرة',
        caveats: [_strings.confidenceUncertain],
        width: 220,
      );

      final value = tester.getRect(find.byKey(_valueKey));
      final chip = tester.getRect(find.byType(CaveatBadge));
      expect(chip.top, greaterThanOrEqualTo(value.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows every caution, each as its own chip', (tester) async {
      await _pump(
        tester,
        value: '750',
        caveats: [_strings.confidenceUncertain, _strings.resultActionInferred],
      );

      expect(find.byType(CaveatBadge), findsNWidgets(2));
      expect(find.text(_strings.confidenceUncertain), findsOneWidget);
      expect(find.text(_strings.resultActionInferred), findsOneWidget);
    });

    testWidgets('lays out under Large Text without overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        value: 'رقم الحساب 1234567890',
        caveats: [_strings.confidenceUncertain, _strings.resultActionInferred],
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(CaveatBadge), findsNWidgets(2));
    });

    testWidgets('a screen reader hears the caution as its own sentence', (
      tester,
    ) async {
      await _pump(tester, value: '750', caveats: [_strings.confidenceReview]);

      expect(find.bySemanticsLabel(_strings.confidenceReview), findsOneWidget);
      expect(find.bySemanticsLabel('750'), findsOneWidget);
    });
  });
}
