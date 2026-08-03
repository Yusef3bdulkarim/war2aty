import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/saved_papers/presentation/widgets/document_list_item.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

  group('DocumentListItem', () {
    testWidgets('shows the title, category and what was stored', (
      tester,
    ) async {
      await pumpApp(
        tester,
        DocumentListItem(document: documentWith(title: 'فاتورة كهرباء')),
      );

      expect(find.text('فاتورة كهرباء'), findsOneWidget);
      expect(find.text(ar.documentCategoryInvoice), findsOneWidget);
      expect(find.text('· ${ar.documentStoredResultOnly}'), findsOneWidget);
    });

    testWidgets('gives its category the shared icon', (tester) async {
      await pumpApp(
        tester,
        DocumentListItem(
          document: documentWith(category: DocumentCategory.government),
        ),
      );

      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon).first).glyph,
        StrokeGlyph.government,
      );
    });

    testWidgets('is inert with no destination yet (F08-T08)', (tester) async {
      await pumpApp(tester, DocumentListItem(document: documentWith()));

      expect(
        tester.getSemantics(find.text(documentWith().title)),
        isSemantics(isButton: false, hasTapAction: false),
      );
    });

    testWidgets('opens the document once a destination is wired', (
      tester,
    ) async {
      RecentDocument? opened;

      await pumpApp(
        tester,
        DocumentListItem(
          document: documentWith(title: 'فاتورة كهرباء'),
          onTap: () => opened = documentWith(title: 'فاتورة كهرباء'),
        ),
      );

      await tester.tap(find.text('فاتورة كهرباء'));
      await tester.pumpAndSettle();

      expect(opened, isNotNull);
    });

    testWidgets('survives large text and a long title', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        DocumentListItem(
          document: documentWith(
            title: 'فاتورة كهرباء شهر أغسطس لشقة الدور الخامس عمارة رقم 12',
          ),
        ),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
