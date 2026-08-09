import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/usecases/watch_documents.dart';
import 'package:war2aty/core/localization/app_localizations.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/core/localization/en_strings.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/documents_list_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/screens/documents_list_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();
  const en = EnStrings();

  late FakeDocumentsRepository repository;

  setUp(() => repository = FakeDocumentsRepository());
  tearDown(() => repository.dispose());

  Widget screenUnderTest({
    VoidCallback? onScan,
    ValueChanged<String>? onOpenDocument,
  }) => BlocProvider<DocumentsListCubit>(
    create: (_) => DocumentsListCubit(WatchDocuments(repository))..start(),
    child: DocumentsListScreen(onScan: onScan, onOpenDocument: onOpenDocument),
  );

  group('DocumentsListScreen', () {
    testWidgets('shows a spinner before the database answers', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest(), settle: false);

      // The heading text lives in the nav shell tab, not this screen.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the empty state once saved is confirmed empty', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.documentsEmptyTitle), findsOneWidget);
      expect(find.text(ar.documentsEmptySubtitle), findsOneWidget);
      expect(find.text(ar.documentsEmptyCta), findsOneWidget);
    });

    testWidgets('fires onScan from the empty state', (tester) async {
      var tapped = 0;
      await pumpApp(tester, screenUnderTest(onScan: () => tapped++));

      await tester.tap(find.text(ar.documentsEmptyCta));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

    testWidgets('lists every saved document, not just a handful', (
      tester,
    ) async {
      repository.emit([
        documentWith(id: 'a', title: 'فاتورة كهرباء'),
        documentWith(id: 'b', title: 'موعد الأشعة'),
        documentWith(id: 'c', title: 'خطاب الجامعة'),
      ]);

      await pumpApp(tester, screenUnderTest());

      expect(find.text('فاتورة كهرباء'), findsOneWidget);
      expect(find.text('موعد الأشعة'), findsOneWidget);
      expect(find.text('خطاب الجامعة'), findsOneWidget);
      expect(find.text(ar.documentsEmptyTitle), findsNothing);
    });

    testWidgets('says so when the library could not be read', (tester) async {
      repository.emitFailure();

      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.documentsListErrorTitle), findsOneWidget);
      // A read failure must not be mistaken for "nothing saved".
      expect(find.text(ar.documentsEmptyTitle), findsNothing);
    });

    testWidgets('updates live as documents are saved, no rebuild needed', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());
      expect(find.text(ar.documentsEmptyTitle), findsOneWidget);

      repository.emit([documentWith(title: 'فاتورة كهرباء')]);
      await tester.pumpAndSettle();

      expect(find.text(ar.documentsEmptyTitle), findsNothing);
      expect(find.text('فاتورة كهرباء'), findsOneWidget);
    });

    testWidgets('opens a document when its row is tapped (F08-T08)', (
      tester,
    ) async {
      repository.emit([documentWith(id: 'doc-9', title: 'فاتورة كهرباء')]);
      String? opened;

      await pumpApp(
        tester,
        screenUnderTest(onOpenDocument: (id) => opened = id),
      );

      await tester.tap(find.text('فاتورة كهرباء'));
      await tester.pumpAndSettle();

      expect(opened, 'doc-9');
    });

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        screenUnderTest(),
        locale: AppLocalizations.english,
      );

      // The heading text lives in the nav shell tab, not this screen.
      expect(find.text(en.documentsEmptyTitle), findsOneWidget);
    });

    testWidgets('shows no search field when nothing has ever been saved', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows a search field once the library has a document', (
      tester,
    ) async {
      repository.emit([documentWith(title: 'فاتورة كهرباء')]);

      await pumpApp(tester, screenUnderTest());

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('asks the cubit to search as the user types', (tester) async {
      repository.emit([documentWith(title: 'فاتورة كهرباء')]);
      await pumpApp(tester, screenUnderTest());

      await tester.enterText(find.byType(TextField), 'كهرباء');
      await tester.pumpAndSettle();

      expect(repository.requestedTitleQuery, 'كهرباء');
    });

    testWidgets('shows a no-results state when the search matches nothing', (
      tester,
    ) async {
      repository.emit([documentWith(title: 'فاتورة كهرباء')]);
      await pumpApp(tester, screenUnderTest());

      await tester.enterText(find.byType(TextField), 'قطة');
      repository.emit([]);
      await tester.pumpAndSettle();

      expect(find.text(ar.documentsSearchNoResultsTitle), findsOneWidget);
      // Scanning does not fix a search that matched nothing.
      expect(find.text(ar.documentsEmptyCta), findsNothing);
      // The search field itself must survive — the user still needs it to
      // fix or clear the query.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows no category chips when nothing has ever been saved', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.documentsFilterAll), findsNothing);
    });

    testWidgets('shows category chips once the library has a document', (
      tester,
    ) async {
      repository.emit([documentWith(title: 'فاتورة كهرباء')]);

      await pumpApp(tester, screenUnderTest());

      expect(find.text(ar.documentsFilterAll), findsOneWidget);
      expect(find.text(ar.documentsFilterAppointment), findsOneWidget);
    });

    testWidgets('asks the cubit to filter as a chip is tapped', (tester) async {
      repository.emit([documentWith(title: 'فاتورة كهرباء')]);
      await pumpApp(tester, screenUnderTest());

      await tester.tap(find.text(ar.documentsFilterInvoice));
      await tester.pumpAndSettle();

      expect(repository.requestedCategory, DocumentCategory.invoice);
    });

    testWidgets(
      'shows a no-results state when a category filter matches nothing',
      (tester) async {
        repository.emit([documentWith(title: 'فاتورة كهرباء')]);
        await pumpApp(tester, screenUnderTest());

        await tester.tap(find.text(ar.documentsFilterAppointment));
        repository.emit([]);
        await tester.pumpAndSettle();

        expect(find.text(ar.documentsSearchNoResultsTitle), findsOneWidget);
        // The chip row itself must survive — the user still needs it to
        // switch back to another category.
        expect(find.text(ar.documentsFilterAll), findsOneWidget);
      },
    );

    testWidgets('survives large text without overflowing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      repository.emit([documentWith()]);

      await pumpApp(
        tester,
        screenUnderTest(),
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
