import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/database/daos/documents_dao.dart';
import 'package:war2aty/core/database/tables/document_tables.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/drift_documents_repository.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late DocumentsDao dao;
  late FakeDocumentImageStore images;
  late DriftDocumentsRepository repository;

  setUp(() {
    db = memoryDatabase();
    dao = db.documentsDao;
    images = FakeDocumentImageStore();
    repository = DriftDocumentsRepository(
      dao,
      images,
      idGenerator: () => 'doc-1',
      clock: () => DateTime(2026, 7, 29),
    );
  });
  tearDown(() => db.close());

  test('returns the id of the document it saved', () async {
    final outcome = await repository.saveResultOnly(
      analysis: _analysis(),
      extractedText: 'شركة الكهرباء',
    );

    expect(outcome, const Ok<String, AppFailure>('doc-1'));
  });

  test('writes the paper and its children', () async {
    await repository.saveResultOnly(
      analysis: _analysis(),
      extractedText: 'شركة الكهرباء',
    );

    final bundle = await dao.documentById('doc-1');

    expect(bundle!.document.title, 'فاتورة كهرباء');
    expect(bundle.document.category, DocumentCategory.invoice);
    expect(bundle.document.extractedText, 'شركة الكهرباء');
    expect(bundle.keyInformation.single.label, 'رقم الحساب');
    expect(bundle.textItemsOf(DocumentTextItemKind.instruction), ['ادفع']);
  });

  test('keeps the result only — no image is written', () async {
    await repository.saveResultOnly(
      analysis: _analysis(),
      extractedText: 'شركة الكهرباء',
    );

    final bundle = await dao.documentById('doc-1');

    expect(bundle!.document.storageMode, DocumentStorageMode.resultOnly);
    expect(bundle.document.encryptedImagePath, isNull);
  });

  test('stamps the save with the clock it was given', () async {
    await repository.saveResultOnly(
      analysis: _analysis(),
      extractedText: 'شركة الكهرباء',
    );

    final bundle = await dao.documentById('doc-1');

    expect(bundle!.document.savedAt, DateTime(2026, 7, 29));
  });

  test('gives each save its own id', () async {
    var next = 0;
    final repo = DriftDocumentsRepository(
      dao,
      images,
      idGenerator: () => 'doc-${next++}',
      clock: () => DateTime(2026, 7, 29),
    );

    await repo.saveResultOnly(analysis: _analysis(), extractedText: 'أ');
    await repo.saveResultOnly(analysis: _analysis(), extractedText: 'ب');

    expect(await dao.watchDocuments().first, hasLength(2));
  });

  test('turns a database error into a LocalDatabaseFailure', () async {
    final failing = DriftDocumentsRepository(
      _ThrowingDao(db),
      images,
      idGenerator: () => 'doc-1',
      clock: () => DateTime(2026, 7, 29),
    );

    final outcome = await failing.saveResultOnly(
      analysis: _analysis(),
      extractedText: 'شركة الكهرباء',
    );

    expect(outcome, const Err<String, AppFailure>(LocalDatabaseFailure()));
  });

  group('saveWithImage', () {
    test('returns the id and encrypts the picture for it', () async {
      final outcome = await repository.saveWithImage(
        analysis: _analysis(),
        extractedText: 'شركة الكهرباء',
        imagePath: '/cache/analysis_sessions/s1/processed.jpg',
      );

      expect(outcome, const Ok<String, AppFailure>('doc-1'));
      expect(
        images.stored['doc-1'],
        '/cache/analysis_sessions/s1/processed.jpg',
      );
    });

    test('writes the row with the encrypted path and withImage mode', () async {
      await repository.saveWithImage(
        analysis: _analysis(),
        extractedText: 'شركة الكهرباء',
        imagePath: '/cache/analysis_sessions/s1/processed.jpg',
      );

      final bundle = await dao.documentById('doc-1');

      expect(bundle!.document.storageMode, DocumentStorageMode.withImage);
      expect(
        bundle.document.encryptedImagePath,
        '/private/documents/doc-1/original.enc',
      );
    });

    test('writes nothing when encryption fails', () async {
      images.fails = true;

      final outcome = await repository.saveWithImage(
        analysis: _analysis(),
        extractedText: 'شركة الكهرباء',
        imagePath: '/cache/analysis_sessions/s1/processed.jpg',
      );

      expect(outcome, const Err<String, AppFailure>(FileEncryptionFailure()));
      expect(await dao.documentById('doc-1'), isNull);
    });

    test('deletes the encrypted picture if the row write fails', () async {
      final failing = DriftDocumentsRepository(
        _ThrowingDao(db),
        images,
        idGenerator: () => 'doc-1',
        clock: () => DateTime(2026, 7, 29),
      );

      final outcome = await failing.saveWithImage(
        analysis: _analysis(),
        extractedText: 'شركة الكهرباء',
        imagePath: '/cache/analysis_sessions/s1/processed.jpg',
      );

      expect(outcome, const Err<String, AppFailure>(LocalDatabaseFailure()));
      expect(images.deletedIds, ['doc-1']);
    });
  });

  group('watchDocuments', () {
    test('emits an empty list when nothing has been saved', () async {
      final result = await repository.watchDocuments().first;

      expect((result as Ok<List<RecentDocument>, AppFailure>).value, isEmpty);
    });

    test('emits a row as soon as it is written', () async {
      await repository.saveResultOnly(
        analysis: _analysis(),
        extractedText: 'شركة الكهرباء',
      );

      final result = await repository.watchDocuments().first;
      final docs = (result as Ok<List<RecentDocument>, AppFailure>).value;
      expect(docs, hasLength(1));
    });

    test('filters by title when titleQuery is given', () async {
      var next = 0;
      final repo = DriftDocumentsRepository(
        dao,
        images,
        idGenerator: () => 'doc-${next++}',
        clock: () => DateTime(2026, 7, 29),
      );

      await repo.saveResultOnly(analysis: _analysis(), extractedText: 'كهرباء');

      final result = await repo.watchDocuments(titleQuery: 'كهرباء').first;
      expect(
        (result as Ok<List<RecentDocument>, AppFailure>).value,
        hasLength(1),
      );

      final noMatch = await repo.watchDocuments(titleQuery: 'قطة').first;
      expect((noMatch as Ok<List<RecentDocument>, AppFailure>).value, isEmpty);
    });

    test('filters by category when category is given (F08-T07)', () async {
      var next = 0;
      final repo = DriftDocumentsRepository(
        dao,
        images,
        idGenerator: () => 'doc-${next++}',
        clock: () => DateTime(2026, 7, 29),
      );

      await repo.saveResultOnly(analysis: _analysis(), extractedText: 'كهرباء');
      await repo.saveResultOnly(
        analysis: _analysis(kind: DocumentKind.appointment),
        extractedText: 'كشف',
      );

      final result = await repo
          .watchDocuments(category: DocumentCategory.appointment)
          .first;
      final docs = (result as Ok<List<RecentDocument>, AppFailure>).value;
      expect(docs, hasLength(1));
      expect(docs.single.category, DocumentCategory.appointment);
    });

    test('keeps emitting as new rows are written', () async {
      var next = 0;
      final repo = DriftDocumentsRepository(
        dao,
        images,
        idGenerator: () => 'doc-${next++}',
        clock: () => DateTime(2026, 7, 29),
      );

      final states = <Object>[];
      final sub = repo.watchDocuments().listen(states.add);
      await pumpEventQueue();

      await repo.saveResultOnly(analysis: _analysis(), extractedText: 'أ');
      await pumpEventQueue();

      await sub.cancel();

      // Initial empty list + list after the write.
      expect(states, hasLength(2));
      final second = (states[1] as Ok<List<RecentDocument>, AppFailure>).value;
      expect(second, hasLength(1));
    });

    test('reads every saved document, not just the newest few', () async {
      var next = 0;
      final repo = DriftDocumentsRepository(
        dao,
        images,
        idGenerator: () => 'doc-${next++}',
        clock: () => DateTime(2026, 7, 29),
      );
      for (var i = 0; i < 5; i++) {
        await repo.saveResultOnly(analysis: _analysis(), extractedText: 'أ');
      }

      final result = await repo.watchDocuments().first;

      expect(
        (result as Ok<List<RecentDocument>, AppFailure>).value,
        hasLength(5),
      );
    });
  });

  group('watchRecent', () {
    test('limits the list to the requested count', () async {
      var next = 0;
      final repo = DriftDocumentsRepository(
        dao,
        images,
        idGenerator: () => 'doc-${next++}',
        clock: () => DateTime(2026, 7, 29),
      );

      for (var i = 0; i < 5; i++) {
        await repo.saveResultOnly(analysis: _analysis(), extractedText: '$i');
      }

      final result = await repo.watchRecent(limit: 2).first;
      expect(
        (result as Ok<List<RecentDocument>, AppFailure>).value,
        hasLength(2),
      );
    });

    test('defaults to Home\'s usual three', () async {
      var next = 0;
      final repo = DriftDocumentsRepository(
        dao,
        images,
        idGenerator: () => 'doc-${next++}',
        clock: () => DateTime(2026, 7, 29),
      );
      for (var i = 0; i < 5; i++) {
        await repo.saveResultOnly(analysis: _analysis(), extractedText: 'أ');
      }

      final result = await repo.watchRecent().first;

      expect(
        (result as Ok<List<RecentDocument>, AppFailure>).value,
        hasLength(3),
      );
    });
  });
}

/// A DAO whose write always fails, so the repository's error boundary can be
/// exercised without a database that has to be broken first.
final class _ThrowingDao extends DocumentsDao {
  _ThrowingDao(super.db);

  @override
  Future<void> saveDocument(DocumentWrite write) =>
      Future<void>.error(StateError('disk is on fire'));
}

DocumentAnalysis _analysis({DocumentKind kind = DocumentKind.invoice}) =>
    DocumentAnalysis(
      sessionId: 'session-1',
      status: AnalysisStatus.success,
      kind: kind,
      title: 'فاتورة كهرباء',
      kindConfidence: ConfidenceBand.high,
      summary: const AnalysisSummary(
        short: 'سددها',
        detailed: 'فاتورة شهر يوليو.',
      ),
      keyInformation: const [
        KeyInformation(
          label: 'رقم الحساب',
          value: '12345',
          confidence: ConfidenceBand.high,
          source: InfoSource.extracted,
        ),
      ],
      instructions: ['ادفع'],
    );
