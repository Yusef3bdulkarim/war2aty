import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/saved_papers/presentation/widgets/documents_empty_state.dart';

import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  group('DocumentsEmptyState', () {
    testWidgets('invites the user to scan their first paper', (tester) async {
      await pumpApp(tester, DocumentsEmptyState(onScan: () {}));

      expect(find.text(ar.documentsEmptyTitle), findsOneWidget);
      expect(find.text(ar.documentsEmptySubtitle), findsOneWidget);
      expect(find.text(ar.documentsEmptyCta), findsOneWidget);
    });

    testWidgets('the CTA reaches the capture flow', (tester) async {
      var taps = 0;
      await pumpApp(tester, DocumentsEmptyState(onScan: () => taps++));

      await tester.tap(find.text(ar.documentsEmptyCta));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a search that matched nothing offers no scan action', (
      tester,
    ) async {
      // Photographing a new paper does not help a search that is off, so the
      // no-results variant drops the CTA rather than repeating it.
      await pumpApp(tester, const DocumentsEmptyState.noResults());

      expect(find.text(ar.documentsSearchNoResultsTitle), findsOneWidget);
      expect(find.text(ar.documentsEmptyCta), findsNothing);
    });

    testWidgets('draws the illustration without a single shadow', (
      tester,
    ) async {
      // F29-T02: the owner asked for the page's drop shadow and the camera
      // tile's teal glow to come off, and for nothing to replace them. Every
      // decoration in the subtree is checked, not just the two that used to
      // carry one, so a shadow cannot reappear on a third shape either.
      await pumpApp(tester, DocumentsEmptyState(onScan: () {}));

      final shadowed = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(DocumentsEmptyState),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.boxShadow?.isNotEmpty ?? false)
          .toList();

      expect(shadowed, isEmpty);
    });

    testWidgets('hides the illustration from screen readers', (tester) async {
      // It is decoration; the sentence below carries the meaning.
      await pumpApp(tester, DocumentsEmptyState(onScan: () {}));

      expect(find.bySemanticsLabel(ar.documentsEmptyTitle), findsOneWidget);
    });

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        DocumentsEmptyState(onScan: () {}),
        locale: AppLocalizations.english,
      );

      expect(find.text(en.documentsEmptyTitle), findsOneWidget);
    });

    testWidgets('survives large text', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        SingleChildScrollView(child: DocumentsEmptyState(onScan: () {})),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
