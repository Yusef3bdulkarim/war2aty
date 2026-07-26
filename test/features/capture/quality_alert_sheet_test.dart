import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/capture/presentation/widgets/quality_alert_sheet.dart';

import '../../support/pump_app.dart';

const _strings = ArStrings();

Future<bool?> _pumpSheet(WidgetTester tester, {TextScaler? textScaler}) async {
  bool? result;

  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showQualityAlertSheet(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
    textScaler: textScaler,
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  return result;
}

void main() {
  group('QualityAlertSheet', () {
    testWidgets('shows the title, message and both actions', (tester) async {
      await _pumpSheet(tester);

      expect(find.text(_strings.qualityAlertTitle), findsOneWidget);
      expect(find.text(_strings.qualityAlertMessage), findsOneWidget);
      expect(find.text(_strings.qualityAlertRetake), findsOneWidget);
      expect(find.text(_strings.qualityAlertContinue), findsOneWidget);
    });

    testWidgets('retake pops with false', (tester) async {
      final result = await _pumpSheet(tester);
      expect(result, isNull);

      await tester.tap(find.text(_strings.qualityAlertRetake));
      await tester.pumpAndSettle();

      expect(find.text(_strings.qualityAlertTitle), findsNothing);
    });

    testWidgets('continue pops with true', (tester) async {
      await _pumpSheet(tester);

      final continueButton = find.text(_strings.qualityAlertContinue);
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text(_strings.qualityAlertTitle), findsNothing);
    });

    testWidgets('lays out right-to-left', (tester) async {
      await _pumpSheet(tester);

      expect(
        Directionality.of(
          tester.element(find.text(_strings.qualityAlertTitle)),
        ),
        TextDirection.rtl,
      );
    });

    testWidgets('survives Large Text without overflowing', (tester) async {
      await _pumpSheet(tester, textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });
  });
}
