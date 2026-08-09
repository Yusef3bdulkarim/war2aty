import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/usecases/watch_documents.dart';
import 'package:war2aty/core/icons/stroke_icon.dart';
import 'package:war2aty/core/localization/ar_strings.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/documents_list_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/widgets/documents_search_field.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

void main() {
  const ar = ArStrings();

  late FakeDocumentsRepository repository;

  setUp(() => repository = FakeDocumentsRepository());
  tearDown(() => repository.dispose());

  Widget fieldUnderTest() => BlocProvider<DocumentsListCubit>(
    create: (_) => DocumentsListCubit(WatchDocuments(repository))..start(),
    // TextField needs a Material ancestor, which the real screen's Scaffold
    // already provides; stand one in here since this test pumps the field
    // on its own.
    child: const Scaffold(body: DocumentsSearchField()),
  );

  group('DocumentsSearchField', () {
    testWidgets('shows the search hint and its icon', (tester) async {
      await pumpApp(tester, fieldUnderTest());

      expect(find.text(ar.documentsSearchHint), findsOneWidget);
      expect(
        tester.widget<StrokeIcon>(find.byType(StrokeIcon)).glyph,
        StrokeGlyph.search,
      );
    });

    testWidgets('sends what the user types to the cubit', (tester) async {
      await pumpApp(tester, fieldUnderTest());

      await tester.enterText(find.byType(TextField), 'فاتورة');
      await tester.pumpAndSettle();

      expect(repository.requestedTitleQuery, 'فاتورة');
    });

    testWidgets('disposes its controller without error', (tester) async {
      await pumpApp(tester, fieldUnderTest());
      await tester.enterText(find.byType(TextField), 'فاتورة');

      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    });
  });
}
