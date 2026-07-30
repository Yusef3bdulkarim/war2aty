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
  late DriftDocumentsRepository repository;

  setUp(() {
    db = memoryDatabase();
    dao = db.documentsDao;
    repository = DriftDocumentsRepository(
      dao,
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
      idGenerator: () => 'doc-1',
      clock: () => DateTime(2026, 7, 29),
    );

    final outcome = await failing.saveResultOnly(
      analysis: _analysis(),
      extractedText: 'شركة الكهرباء',
    );

    expect(outcome, const Err<String, AppFailure>(LocalDatabaseFailure()));
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

DocumentAnalysis _analysis() => const DocumentAnalysis(
  sessionId: 'session-1',
  status: AnalysisStatus.success,
  kind: DocumentKind.invoice,
  title: 'فاتورة كهرباء',
  kindConfidence: ConfidenceBand.high,
  summary: AnalysisSummary(short: 'سددها', detailed: 'فاتورة شهر يوليو.'),
  keyInformation: [
    KeyInformation(
      label: 'رقم الحساب',
      value: '12345',
      confidence: ConfidenceBand.high,
      source: InfoSource.extracted,
    ),
  ],
  instructions: ['ادفع'],
);
