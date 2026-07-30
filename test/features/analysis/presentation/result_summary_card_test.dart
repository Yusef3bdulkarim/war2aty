import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_summary_card.dart';

import '../../../support/pump_app.dart';

const _strings = ArStrings();
const _summary = 'دي فاتورة كهرباء بقيمة 750 جنيه، وآخر موعد للسداد 25 أغسطس.';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    String summary = _summary,
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(body: ResultSummaryCard(summary: summary)),
    locale: locale,
    textScaler: textScaler,
  );

  group('ResultSummaryCard', () {
    testWidgets('shows the one-line summary under its own label', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(find.text(_strings.resultSummaryLabel), findsOneWidget);
      expect(find.text(_summary), findsOneWidget);
    });

    testWidgets('claims nothing about how sure the analysis is', (
      tester,
    ) async {
      await pumpCard(tester);

      // UX rule §5.10 — no document-wide badge such as «واضح». The label names
      // the section, and per-value caveats live on the values themselves.
      expect(find.text(_strings.confidenceReview), findsNothing);
      expect(find.text(_strings.confidenceUncertain), findsNothing);
    });

    testWidgets('lays out a long summary under Large Text', (tester) async {
      await pumpCard(
        tester,
        summary:
            'الورقة دي إخطار من الجهة الرسمية بطلب استكمال مستنداتك قبل يوم '
            '30 أغسطس 2026، ولازم تقدم صورة البطاقة وأصل شهادة الميلاد.',
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(tester, locale: AppLocalizations.english);

      expect(find.text(const EnStrings().resultSummaryLabel), findsOneWidget);
    });
  });
}
