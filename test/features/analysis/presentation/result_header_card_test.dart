import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/analysis/presentation/document_kind_label.dart';
import 'package:war2aty/features/analysis/presentation/widgets/caveat_badge.dart';
import 'package:war2aty/features/analysis/presentation/widgets/result_header_card.dart';

import '../../../support/pump_app.dart';
import '../analysis_fixtures.dart';

const _strings = ArStrings();

DocumentAnalysis _analysis({
  DocumentKind kind = DocumentKind.invoice,
  String title = 'فاتورة كهرباء شهر أغسطس',
  ConfidenceBand kindConfidence = ConfidenceBand.high,
}) => DocumentAnalysis(
  sessionId: 'session-1',
  status: AnalysisStatus.success,
  kind: kind,
  title: title,
  kindConfidence: kindConfidence,
  summary: const AnalysisSummary(short: 'خلاصة', detailed: 'شرح'),
);

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    DocumentAnalysis analysis, {
    Locale locale = AppLocalizations.arabic,
    TextScaler? textScaler,
  }) => pumpApp(
    tester,
    Scaffold(body: ResultHeaderCard(analysis: analysis)),
    locale: locale,
    textScaler: textScaler,
  );

  group('ResultHeaderCard', () {
    testWidgets('names the kind of paper and its title', (tester) async {
      await pumpCard(tester, _analysis());

      expect(find.text(_strings.documentKindInvoice), findsOneWidget);
      expect(find.text('فاتورة كهرباء شهر أغسطس'), findsOneWidget);
    });

    testWidgets('says nothing extra when the kind is certain', (tester) async {
      await pumpCard(tester, _analysis());

      expect(find.byType(CaveatBadge), findsNothing);
    });

    testWidgets('asks the user to double-check a medium-confidence kind', (
      tester,
    ) async {
      await pumpCard(tester, _analysis(kindConfidence: ConfidenceBand.medium));

      expect(find.text(_strings.confidenceReview), findsOneWidget);
    });

    testWidgets('marks a low-confidence kind as an uncertain reading', (
      tester,
    ) async {
      await pumpCard(tester, _analysis(kindConfidence: ConfidenceBand.low));

      expect(find.text(_strings.confidenceUncertain), findsOneWidget);
    });

    testWidgets('the title is a heading for assistive technology', (
      tester,
    ) async {
      await pumpCard(tester, _analysis());

      expect(
        tester.getSemantics(find.text('فاتورة كهرباء شهر أغسطس')),
        isSemantics(isHeader: true),
      );
    });

    testWidgets('lays out a long title under Large Text', (tester) async {
      await pumpCard(
        tester,
        _analysis(
          title: 'إشعار من مصلحة الضرائب المصرية بخصوص استكمال المستندات',
          kindConfidence: ConfidenceBand.low,
        ),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('follows the locale', (tester) async {
      await pumpCard(
        tester,
        _analysis(kind: DocumentKind.medical),
        locale: AppLocalizations.english,
      );

      expect(find.text(const EnStrings().documentKindMedical), findsOneWidget);
    });

    testWidgets('renders the fixture paper the result screen shows', (
      tester,
    ) async {
      await pumpCard(tester, invoiceAnalysis());

      expect(find.text('فاتورة كهرباء'), findsOneWidget);
    });
  });

  group('documentKindLabel', () {
    test('every kind has a name in both languages', () {
      for (final kind in DocumentKind.values) {
        expect(documentKindLabel(_strings, kind), isNotEmpty);
        expect(documentKindLabel(const EnStrings(), kind), isNotEmpty);
      }
    });

    test('no two kinds share a name', () {
      final labels = DocumentKind.values
          .map((kind) => documentKindLabel(_strings, kind))
          .toSet();

      expect(labels, hasLength(DocumentKind.values.length));
    });
  });
}
