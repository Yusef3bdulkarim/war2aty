import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/analysis_section.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/documents/usecases/delete_document.dart';
import 'package:war2aty/core/documents/usecases/set_document_note.dart';
import 'package:war2aty/core/documents/usecases/update_document.dart';
import 'package:war2aty/core/documents/usecases/watch_document.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/document_details_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/document_details_state.dart';

import '../../support/fakes.dart';

void main() {
  late FakeDocumentsRepository repository;

  setUp(() => repository = FakeDocumentsRepository());
  tearDown(() => repository.dispose());

  DocumentDetailsCubit buildCubit({String documentId = 'doc-1'}) =>
      DocumentDetailsCubit(
        WatchDocument(repository),
        const BuildAnalysisResult(),
        SetDocumentNote(repository),
        UpdateDocument(repository),
        DeleteDocument(repository),
        documentId: documentId,
      );

  test('starts loading', () {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    expect(cubit.state, const DocumentDetailsLoading());
  });

  test('publishes the document once the database answers', () async {
    final document = savedDocumentWith();
    repository.emitDocument(document);
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.start();
    await pumpEventQueue();

    final state = cubit.state as DocumentDetailsAvailable;
    expect(state.document, document);
  });

  test('asks the repository for the cubit\'s own id', () async {
    final cubit = buildCubit(documentId: 'doc-7');
    addTearDown(cubit.close);

    cubit.start();
    await pumpEventQueue();

    expect(repository.requestedDocumentId, 'doc-7');
  });

  test('says not found when the document no longer resolves', () async {
    repository.emitDocument(null);
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.start();
    await pumpEventQueue();

    expect(cubit.state, const DocumentDetailsNotFound());
  });

  test('surfaces a read failure instead of swallowing it', () async {
    repository.emitDocumentFailure();
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.start();
    await pumpEventQueue();

    expect(
      cubit.state,
      const DocumentDetailsUnavailable(LocalDatabaseFailure()),
    );
  });

  test('follows a later edit to the same document', () async {
    repository.emitDocument(savedDocumentWith());
    final cubit = buildCubit();
    addTearDown(cubit.close);
    cubit.start();
    await pumpEventQueue();

    repository.emitDocument(savedDocumentWith(note: 'ادفع من الفوري'));
    await pumpEventQueue();

    final state = cubit.state as DocumentDetailsAvailable;
    expect(state.document.note, 'ادفع من الفوري');
  });

  test('start is idempotent — a second call adds no second listener', () async {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    cubit.start();
    cubit.start();
    await pumpEventQueue();

    // A second subscription would double every later emission and leak.
    expect(repository.documentListenCount, 1);
  });

  test('emits nothing after close', () async {
    final cubit = buildCubit();
    cubit.start();
    await pumpEventQueue();
    await cubit.close();

    // Would throw if the subscription outlived the cubit.
    repository.emitDocument(savedDocumentWith());
    await pumpEventQueue();

    expect(cubit.isClosed, isTrue);
  });

  group('sections', () {
    test(
      'orders and filters them the same way the result screen does',
      () async {
        repository.emitDocument(
          savedDocumentWith(
            keyInformation: const [
              KeyInformation(
                label: 'رقم الحساب',
                value: '12345',
                confidence: ConfidenceBand.high,
                source: InfoSource.extracted,
              ),
            ],
            dates: [
              AnalysisDate(
                label: 'آخر موعد للسداد',
                date: DateTime(2026, 8, 15),
                role: DateRole.deadline,
                isReminderWorthy: true,
                confidence: ConfidenceBand.high,
              ),
            ],
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);

        cubit.start();
        await pumpEventQueue();

        final state = cubit.state as DocumentDetailsAvailable;
        expect(state.sections, [
          AnalysisSection.header,
          AnalysisSection.summary,
          AnalysisSection.keyInformation,
          AnalysisSection.dates,
          AnalysisSection.detailedExplanation,
          AnalysisSection.extractedText,
        ]);
      },
    );

    test('drops a section the document has nothing to fill', () async {
      repository.emitDocument(savedDocumentWith());
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.start();
      await pumpEventQueue();

      final state = cubit.state as DocumentDetailsAvailable;
      expect(state.sections, isNot(contains(AnalysisSection.keyInformation)));
      expect(state.sections, isNot(contains(AnalysisSection.dates)));
    });
  });

  group('notes (F08-T09)', () {
    test('saveNote writes the trimmed text', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.saveNote('  ادفع من الفوري  ');

      expect(ok, isTrue);
      expect(repository.lastNoteSet, 'ادفع من الفوري');
    });

    test('saveNote rejects an empty string', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.saveNote('   ');

      expect(ok, isFalse);
      expect(repository.lastNoteSet, isNull);
    });

    test('saveNote reports failure', () async {
      repository.setNoteOutcome = const Err(LocalDatabaseFailure());
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.saveNote('test');

      expect(ok, isFalse);
    });

    test('deleteNote clears the note', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.deleteNote();

      expect(ok, isTrue);
      expect(repository.noteDeleted, isTrue);
    });

    test('deleteNote reports failure', () async {
      repository.setNoteOutcome = const Err(LocalDatabaseFailure());
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.deleteNote();

      expect(ok, isFalse);
    });
  });

  group('update (F08-T10)', () {
    test('updateTitle writes the trimmed text', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.updateTitle('  فاتورة مياه  ');

      expect(ok, isTrue);
      expect(repository.lastTitleSet, 'فاتورة مياه');
    });

    test('updateTitle rejects an empty string', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.updateTitle('   ');

      expect(ok, isFalse);
      expect(repository.lastTitleSet, isNull);
    });

    test('updateTitle reports failure', () async {
      repository.updateOutcome = const Err(LocalDatabaseFailure());
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.updateTitle('فاتورة مياه');

      expect(ok, isFalse);
    });

    test('updateCategory writes the chosen category', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.updateCategory(DocumentCategory.government);

      expect(ok, isTrue);
      expect(repository.lastCategorySet, DocumentCategory.government);
    });

    test('updateCategory reports failure', () async {
      repository.updateOutcome = const Err(LocalDatabaseFailure());
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.updateCategory(DocumentCategory.education);

      expect(ok, isFalse);
    });
  });

  group('delete (F08-T11)', () {
    test('deleteDocument calls the repository with the cubit\'s id', () async {
      final cubit = buildCubit(documentId: 'doc-5');
      addTearDown(cubit.close);

      final ok = await cubit.deleteDocument();

      expect(ok, isTrue);
      expect(repository.lastDeletedId, 'doc-5');
    });

    test('deleteDocument reports failure', () async {
      repository.deleteOutcome = const Err(LocalDatabaseFailure());
      final cubit = buildCubit();
      addTearDown(cubit.close);

      final ok = await cubit.deleteDocument();

      expect(ok, isFalse);
    });

    test('deleteDocument returns false after close', () async {
      final cubit = buildCubit();
      await cubit.close();

      final ok = await cubit.deleteDocument();

      expect(ok, isFalse);
      expect(repository.lastDeletedId, isNull);
    });
  });
}
