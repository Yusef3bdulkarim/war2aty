import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/paper/presentation/screens/enlarged_address_screen.dart';

import '../../../../support/pump_app.dart';
import '../../../../support/ui_audit.dart';

const _strings = ArStrings();
const _address = 'مدرسة النور، شارع الجمهورية، دمنهور';

Future<void> _pumpScreen(
  WidgetTester tester, {
  Locale locale = const Locale('ar'),
  TextScaler? textScaler,
}) => pumpApp(
  tester,
  const EnlargedAddressScreen(address: _address),
  locale: locale,
  textScaler: textScaler,
);

void main() {
  auditScreenLayout(
    'EnlargedAddressScreen',
    (tester, locale, scaler) =>
        _pumpScreen(tester, locale: locale, textScaler: scaler),
  );

  group('EnlargedAddressScreen', () {
    testWidgets('shows the address in a very large style', (tester) async {
      await _pumpScreen(tester);

      final text = tester.widget<Text>(find.text(_address));
      expect(text.style!.fontSize, greaterThanOrEqualTo(30));
    });

    testWidgets('the back button pops the screen', (tester) async {
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const EnlargedAddressScreen(address: _address),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(_address), findsOneWidget);

      await tester.tap(find.byTooltip(_strings.analysisResultBackLabel));
      await tester.pumpAndSettle();

      expect(find.text(_address), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('stays readable at the largest text scale', (tester) async {
      await _pumpScreen(tester, textScaler: const TextScaler.linear(2.0));

      expect(find.text(_address), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
