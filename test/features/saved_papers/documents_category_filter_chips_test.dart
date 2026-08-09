import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/usecases/watch_documents.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/documents_list_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/widgets/documents_category_filter_chips.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

  late FakeDocumentsRepository repository;

  setUp(() => repository = FakeDocumentsRepository());
  tearDown(() => repository.dispose());

  Widget chipsUnderTest({DocumentCategory? selected}) =>
      BlocProvider<DocumentsListCubit>(
        create: (_) => DocumentsListCubit(WatchDocuments(repository))..start(),
        child: Scaffold(body: DocumentsCategoryFilterChips(selected: selected)),
      );

  group('DocumentsCategoryFilterChips', () {
    testWidgets('shows «الكل» plus one chip per category', (tester) async {
      await pumpApp(tester, chipsUnderTest());

      expect(find.text(ar.documentsFilterAll), findsOneWidget);
      expect(find.text(ar.documentsFilterAppointment), findsOneWidget);
      expect(find.text(ar.documentsFilterInvoice), findsOneWidget);
      expect(find.text(ar.documentsFilterGovernment), findsOneWidget);
      expect(find.text(ar.documentsFilterEducation), findsOneWidget);
      expect(find.text(ar.documentsFilterOther), findsOneWidget);
    });

    testWidgets('asks the cubit to filter by the tapped category', (
      tester,
    ) async {
      await pumpApp(tester, chipsUnderTest());

      await tester.tap(find.text(ar.documentsFilterInvoice));
      await tester.pumpAndSettle();

      expect(repository.requestedCategory, DocumentCategory.invoice);
    });

    testWidgets('asks the cubit to clear the filter when «الكل» is tapped', (
      tester,
    ) async {
      await pumpApp(tester, chipsUnderTest(selected: DocumentCategory.invoice));

      await tester.tap(find.text(ar.documentsFilterAll));
      await tester.pumpAndSettle();

      expect(repository.requestedCategory, isNull);
    });

    testWidgets('marks the active category as selected for assistive tech', (
      tester,
    ) async {
      await pumpApp(
        tester,
        chipsUnderTest(selected: DocumentCategory.government),
      );

      expect(
        tester.getSemantics(find.text(ar.documentsFilterGovernment)),
        isSemantics(isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.text(ar.documentsFilterAll)),
        isSemantics(isButton: true, isSelected: false),
      );
    });
  });
}
