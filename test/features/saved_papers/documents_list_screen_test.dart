import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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

  Widget screenUnderTest({VoidCallback? onScan}) =>
      BlocProvider<DocumentsListCubit>(
        create: (_) => DocumentsListCubit(WatchDocuments(repository))..start(),
        child: DocumentsListScreen(onScan: onScan),
      );

  group('DocumentsListScreen', () {
    testWidgets('shows the heading before the database answers', (
      tester,
    ) async {
      await pumpApp(tester, screenUnderTest(), settle: false);

      expect(find.text(ar.navDocuments), findsOneWidget);
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

    testWidgets('renders in English', (tester) async {
      await pumpApp(
        tester,
        screenUnderTest(),
        locale: AppLocalizations.english,
      );

      expect(find.text(en.navDocuments), findsOneWidget);
      expect(find.text(en.documentsEmptyTitle), findsOneWidget);
    });

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
