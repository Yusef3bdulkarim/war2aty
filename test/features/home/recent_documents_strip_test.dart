import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/document_category_style.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/core/widgets/skeleton.dart';
import 'package:war2aty/features/home/presentation/cubit/home_state.dart';
import 'package:war2aty/features/home/presentation/widgets/recent_documents_strip.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  group('visibility', () {
    test('hidden while loading', () {
      expect(RecentDocumentsStrip.isVisible(const DocumentsLoading()), isFalse);
    });

    test('hidden when the list could not be read', () {
      expect(
        RecentDocumentsStrip.isVisible(
          const DocumentsUnavailable(LocalDatabaseFailure()),
        ),
        isFalse,
      );
    });

    test(
      'hidden when nothing is saved — Home\'s empty state speaks instead',
      () {
        expect(
          RecentDocumentsStrip.isVisible(const DocumentsAvailable([])),
          isFalse,
        );
      },
    );

    test('shown once a document exists', () {
      expect(
        RecentDocumentsStrip.isVisible(DocumentsAvailable([documentWith()])),
        isTrue,
      );
    });
  });

  group('RecentDocumentsStrip', () {
    testWidgets('shows placeholder rows while the database is read', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const RecentDocumentsStrip(section: DocumentsLoading()),
        settle: false,
      );

      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.bySemanticsLabel(ar.stateLoading), findsOneWidget);
      // Placeholder shapes must not be read out as content.
      expect(find.text(ar.homeRecentDocumentsTitle), findsNothing);
    });

    testWidgets('renders nothing when empty', (tester) async {
      await pumpApp(
        tester,
        const RecentDocumentsStrip(section: DocumentsAvailable([])),
      );

      expect(find.text(ar.homeRecentDocumentsTitle), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the section heading and a card per document', (
      tester,
    ) async {
      await pumpApp(
        tester,
        RecentDocumentsStrip(
          section: DocumentsAvailable([
            documentWith(id: 'a', title: 'فاتورة كهرباء'),
            documentWith(
              id: 'b',
              title: 'موعد الأشعة',
              category: DocumentCategory.appointment,
            ),
          ]),
        ),
      );

      expect(find.text(ar.homeRecentDocumentsTitle), findsOneWidget);
      expect(find.text('فاتورة كهرباء'), findsOneWidget);
      expect(find.text('موعد الأشعة'), findsOneWidget);
    });

    testWidgets('labels each card with its category and what was stored', (
      tester,
    ) async {
      await pumpApp(
        tester,
        RecentDocumentsStrip(section: DocumentsAvailable([documentWith()])),
      );

      expect(find.text(ar.documentCategoryInvoice), findsOneWidget);
      expect(find.text(ar.documentStoredResultOnly), findsOneWidget);
    });

    testWidgets('says so when the photo was kept too', (tester) async {
      await pumpApp(
        tester,
        RecentDocumentsStrip(
          section: DocumentsAvailable([
            documentWith(storageMode: DocumentStorageMode.withImage),
          ]),
        ),
      );

      // The privacy-relevant difference must be visible, not implied.
      expect(find.text(ar.documentStoredWithImage), findsOneWidget);
      expect(find.text(ar.documentStoredResultOnly), findsNothing);
    });

    testWidgets('gives each category its own icon', (tester) async {
      await pumpApp(
        tester,
        RecentDocumentsStrip(
          section: DocumentsAvailable([
            documentWith(id: 'a'),
            documentWith(id: 'b', category: DocumentCategory.government),
          ]),
        ),
      );

      final glyphs = tester
          .widgetList<StrokeIcon>(find.byType(StrokeIcon))
          .map((i) => i.glyph)
          .toList();

      expect(glyphs, [StrokeGlyph.invoice, StrokeGlyph.government]);
    });

    testWidgets('hides "see all" until the documents list exists', (
      tester,
    ) async {
      await pumpApp(
        tester,
        RecentDocumentsStrip(section: DocumentsAvailable([documentWith()])),
      );

      // A button that goes nowhere is worse than no button.
      expect(find.text(ar.homeSeeAll), findsNothing);
    });

    testWidgets('shows and fires "see all" once it has a destination', (
      tester,
    ) async {
      var tapped = 0;
      await pumpApp(
        tester,
        RecentDocumentsStrip(
          section: DocumentsAvailable([documentWith()]),
          onSeeAll: () => tapped++,
        ),
      );

      await tester.tap(find.text(ar.homeSeeAll));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

    testWidgets('opens the document that was tapped', (tester) async {
      RecentDocument? opened;
      final second = documentWith(id: 'b', title: 'ورقة تانية');

      await pumpApp(
        tester,
        RecentDocumentsStrip(
          section: DocumentsAvailable([documentWith(id: 'a'), second]),
          onOpenDocument: (document) => opened = document,
        ),
      );

      await tester.tap(find.text('ورقة تانية'));
      await tester.pumpAndSettle();

      expect(opened, second);
    });

    testWidgets('reads a card as one sentence to screen readers', (
      tester,
    ) async {
      await pumpApp(
        tester,
        RecentDocumentsStrip(
          section: DocumentsAvailable([documentWith(title: 'فاتورة كهرباء')]),
          onOpenDocument: (_) {},
        ),
      );

      expect(
        tester.getSemantics(find.text('فاتورة كهرباء')),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          label:
              'فاتورة كهرباء. ${ar.documentCategoryInvoice}. '
              '${ar.documentStoredResultOnly}',
        ),
      );
    });

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        RecentDocumentsStrip(
          section: DocumentsAvailable([
            documentWith(title: 'Electricity bill'),
          ]),
        ),
        locale: AppLocalizations.english,
      );

      expect(find.text(en.homeRecentDocumentsTitle), findsOneWidget);
      expect(find.text(en.documentCategoryInvoice), findsOneWidget);
    });

    testWidgets('survives large text and a long title', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        RecentDocumentsStrip(
          section: DocumentsAvailable([
            documentWith(
              title: 'فاتورة كهرباء شهر أغسطس لشقة الدور الخامس عمارة رقم 12',
            ),
          ]),
        ),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('DocumentCategoryStyle', () {
    test('every category has a distinct look', () {
      final styles = DocumentCategory.values.map(DocumentCategoryStyle.of);

      expect(
        styles.map((s) => s.tint).toSet().length,
        DocumentCategory.values.length,
        reason: 'two categories must not be indistinguishable',
      );
    });
  });
}
