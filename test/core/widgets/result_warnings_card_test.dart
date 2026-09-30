import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_warning.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/widgets/compact_alert_banner.dart';
import 'package:war2aty/core/widgets/result_warnings_card.dart';

import '../../support/pump_app.dart';

const _strings = ArStrings();

const _medical = AnalysisWarning(
  text: 'التطبيق بيساعدك تفهم المكتوب فقط، ومش بديل عن الطبيب.',
  kind: WarningKind.medical,
);

const _government = AnalysisWarning(
  text: 'راجع الجهة الرسمية قبل تقديم مستندات أو دفع أي رسوم.',
  kind: WarningKind.government,
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    List<AnalysisWarning> warnings, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(body: ResultWarningsCard(warnings: warnings)),
    locale: locale,
    textScaler: textScaler,
  );

  group('ResultWarningsCard', () {
    testWidgets('shows the disclaimer as a compact banner', (tester) async {
      await pumpCard(tester, const [_medical]);

      expect(find.byType(CompactAlertBanner), findsOneWidget);
      expect(find.text(_medical.text), findsOneWidget);
      // No drawn heading any more (F21 locked decision #10).
      expect(find.text(_strings.resultWarningsTitle), findsNothing);
    });

    testWidgets('gives every disclaimer its own banner, in order', (
      tester,
    ) async {
      await pumpCard(tester, const [_medical, _government]);

      expect(find.byType(CompactAlertBanner), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text(_medical.text)).dy,
        lessThan(tester.getTopLeft(find.text(_government.text)).dy),
      );
    });

    testWidgets('a screen reader still hears that it is a warning', (
      tester,
    ) async {
      await pumpCard(tester, const [_medical]);

      expect(
        find.bySemanticsLabel(
          '${_strings.resultWarningsTitle}: ${_medical.text}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('lays out under Large Text', (tester) async {
      await pumpCard(tester, const [
        _medical,
        _government,
      ], textScaler: const TextScaler.linear(2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(tester, const [
        _medical,
      ], locale: AppLocalizations.english);

      expect(
        find.bySemanticsLabel(
          '${const EnStrings().resultWarningsTitle}: ${_medical.text}',
        ),
        findsOneWidget,
      );
    });
  });
}
