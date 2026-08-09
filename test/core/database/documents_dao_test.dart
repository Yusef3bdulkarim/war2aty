// `isNull`/`isNotNull` are drift SQL expressions too; the matchers win here.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/database/daos/documents_dao.dart';
import 'package:war2aty/core/database/tables/document_tables.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/recent_document.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late DocumentsDao dao;

  setUp(() {
    db = memoryDatabase();
    dao = db.documentsDao;
  });
  tearDown(() => db.close());

  group('saveDocument', () {
    test('round-trips a result-only document with no children', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));

      final bundle = await dao.documentById('d1');

      expect(bundle, isNotNull);
      expect(bundle!.document.title, 'فاتورة كهرباء');
      expect(bundle.document.category, DocumentCategory.invoice);
      expect(bundle.document.storageMode, DocumentStorageMode.resultOnly);
      expect(bundle.document.encryptedImagePath, isNull);
      expect(bundle.document.note, isNull);
      expect(bundle.keyInformation, isEmpty);
      expect(bundle.dates, isEmpty);
    });

    test('numbers children by their list order', () async {
      await dao.saveDocument(
        DocumentWrite(
          document: _document('d1'),
          keyInformation: [_info('رقم الحساب'), _info('القراءة')],
        ),
      );

      final bundle = await dao.documentById('d1');

      expect(bundle!.keyInformation.map((i) => i.label), [
        'رقم الحساب',
        'القراءة',
      ]);
      expect(bundle.keyInformation.map((i) => i.position), [0, 1]);
    });

    test('keeps every child list', () async {
      await dao.saveDocument(
        DocumentWrite(
          document: _document('d1'),
          keyInformation: [_info('رقم الحساب')],
          dates: [_date(DateTime(2026, 8, 15))],
          amounts: [_amount(250.5)],
          actions: [_action('سدد الفاتورة')],
          warnings: [_warning('راجع الجهة')],
          requiredDocuments: ['بطاقة الرقم القومي'],
          instructions: ['روح لأقرب فرع'],
          missingFields: ['dueDate'],
        ),
      );

      final bundle = await dao.documentById('d1');

      expect(bundle!.keyInformation, hasLength(1));
      expect(bundle.dates.single.date, DateTime(2026, 8, 15));
      expect(bundle.amounts.single.value, 250.5);
      expect(bundle.actions.single.description, 'سدد الفاتورة');
      expect(bundle.warnings.single.message, 'راجع الجهة');
      expect(bundle.textItemsOf(DocumentTextItemKind.requiredDocument), [
        'بطاقة الرقم القومي',
      ]);
      expect(bundle.textItemsOf(DocumentTextItemKind.instruction), [
        'روح لأقرب فرع',
      ]);
      expect(bundle.textItemsOf(DocumentTextItemKind.missingField), [
        'dueDate',
      ]);
    });

    test('stores a date with no time as absent rather than midnight', () async {
      await dao.saveDocument(
        DocumentWrite(
          document: _document('d1'),
          dates: [_date(DateTime(2026, 8, 15))],
        ),
      );

      final bundle = await dao.documentById('d1');

      expect(bundle!.dates.single.minuteOfDay, isNull);
    });

    test('keeps a time of day when the paper gave one', () async {
      await dao.saveDocument(
        DocumentWrite(
          document: _document('d1'),
          dates: [_date(DateTime(2026, 8, 15), minuteOfDay: 9 * 60 + 30)],
        ),
      );

      final bundle = await dao.documentById('d1');

      expect(bundle!.dates.single.minuteOfDay, 570);
    });

    test('re-saving the same id replaces the old children', () async {
      await dao.saveDocument(
        DocumentWrite(
          document: _document('d1'),
          keyInformation: [_info('رقم الحساب'), _info('القراءة')],
          requiredDocuments: ['بطاقة الرقم القومي'],
        ),
      );

      await dao.saveDocument(
        DocumentWrite(
          document: _document('d1', title: 'فاتورة مياه'),
          keyInformation: [_info('رقم العداد')],
        ),
      );

      final bundle = await dao.documentById('d1');

      expect(bundle!.document.title, 'فاتورة مياه');
      expect(bundle.keyInformation.map((i) => i.label), ['رقم العداد']);
      expect(bundle.textItems, isEmpty);
    });
  });

  group('documentById', () {
    test('returns null for an unknown id', () async {
      expect(await dao.documentById('nope'), isNull);
    });
  });

  group('watchDocuments', () {
    test('emits the newest document first', () async {
      await dao.saveDocument(
        DocumentWrite(
          document: _document('old', savedAt: DateTime(2026, 7, 5)),
        ),
      );
      await dao.saveDocument(
        DocumentWrite(
          document: _document('new', savedAt: DateTime(2026, 7, 20)),
        ),
      );

      final rows = await dao.watchDocuments().first;

      expect(rows.map((d) => d.id), ['new', 'old']);
    });

    test('caps the result at limit', () async {
      await dao.saveDocument(
        DocumentWrite(
          document: _document('old', savedAt: DateTime(2026, 7, 5)),
        ),
      );
      await dao.saveDocument(
        DocumentWrite(
          document: _document('new', savedAt: DateTime(2026, 7, 20)),
        ),
      );

      final rows = await dao.watchDocuments(limit: 1).first;

      expect(rows.map((d) => d.id), ['new']);
    });

    test('matches a title fragment', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));
      await dao.saveDocument(
        DocumentWrite(document: _document('d2', title: 'موعد الكشف')),
      );

      final rows = await dao.watchDocuments(titleQuery: 'كهرباء').first;

      expect(rows.map((d) => d.id), ['d1']);
    });

    test('matches a title regardless of case', () async {
      await dao.saveDocument(
        DocumentWrite(document: _document('d1', title: 'Electricity Bill')),
      );

      final rows = await dao.watchDocuments(titleQuery: 'BILL').first;

      expect(rows.map((d) => d.id), ['d1']);
    });

    test('ignores a blank query', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));

      final rows = await dao.watchDocuments(titleQuery: '   ').first;

      expect(rows, hasLength(1));
    });

    test('narrows to one category', () async {
      await dao.saveDocument(DocumentWrite(document: _document('bill')));
      await dao.saveDocument(
        DocumentWrite(
          document: _document('visit', category: DocumentCategory.appointment),
        ),
      );

      final rows = await dao
          .watchDocuments(category: DocumentCategory.appointment)
          .first;

      expect(rows.map((d) => d.id), ['visit']);
    });

    test('combines a query with a category', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));
      await dao.saveDocument(
        DocumentWrite(
          document: _document(
            'd2',
            title: 'فاتورة الكشف',
            category: DocumentCategory.appointment,
          ),
        ),
      );

      final rows = await dao
          .watchDocuments(
            titleQuery: 'فاتورة',
            category: DocumentCategory.appointment,
          )
          .first;

      expect(rows.map((d) => d.id), ['d2']);
    });

    test('re-emits when a document is saved', () async {
      final counts = <int>[];
      final sub = dao.watchDocuments().listen(
        (rows) => counts.add(rows.length),
      );
      await pumpEventQueue();

      await dao.saveDocument(DocumentWrite(document: _document('d1')));
      await pumpEventQueue();
      await sub.cancel();

      expect(counts, [0, 1]);
    });
  });

  group('watchDocumentById', () {
    test('re-emits when a child row changes', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));

      final counts = <int?>[];
      final sub = dao
          .watchDocumentById('d1')
          .listen((bundle) => counts.add(bundle?.keyInformation.length));
      await pumpEventQueue();

      await dao.saveDocument(
        DocumentWrite(
          document: _document('d1'),
          keyInformation: [_info('رقم الحساب')],
        ),
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(counts, [0, 1]);
    });

    test('emits null once the document is deleted', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));

      final ids = <String?>[];
      final sub = dao
          .watchDocumentById('d1')
          .listen((bundle) => ids.add(bundle?.document.id));
      await pumpEventQueue();

      await dao.deleteDocument('d1');
      await pumpEventQueue();
      await sub.cancel();

      expect(ids, ['d1', null]);
    });
  });

  group('updateDocument', () {
    test('changes title and category and stamps updatedAt', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));

      await dao.updateDocument(
        'd1',
        title: 'فاتورة الشقة',
        category: DocumentCategory.government,
        updatedAt: DateTime(2026, 7, 29),
      );

      final bundle = await dao.documentById('d1');

      expect(bundle!.document.title, 'فاتورة الشقة');
      expect(bundle.document.category, DocumentCategory.government);
      expect(bundle.document.updatedAt, DateTime(2026, 7, 29));
    });

    test('leaves the category alone when only the title changes', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));

      await dao.updateDocument(
        'd1',
        title: 'فاتورة الشقة',
        updatedAt: DateTime(2026, 7, 29),
      );

      final bundle = await dao.documentById('d1');

      expect(bundle!.document.category, DocumentCategory.invoice);
    });
  });

  group('setNote', () {
    test('writes and then clears the note', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));

      await dao.setNote(
        'd1',
        'ادفع من الفوري',
        updatedAt: DateTime(2026, 7, 29),
      );
      expect((await dao.documentById('d1'))!.document.note, 'ادفع من الفوري');

      await dao.setNote('d1', null, updatedAt: DateTime(2026, 7, 30));
      expect((await dao.documentById('d1'))!.document.note, isNull);
    });
  });

  group('setEncryptedImage', () {
    test('records the path and switches the storage mode', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));

      await dao.setEncryptedImage(
        'd1',
        '/private/d1.enc',
        storageMode: DocumentStorageMode.withImage,
        updatedAt: DateTime(2026, 7, 29),
      );

      final bundle = await dao.documentById('d1');

      expect(bundle!.document.encryptedImagePath, '/private/d1.enc');
      expect(bundle.document.storageMode, DocumentStorageMode.withImage);
    });

    test('clears the path when the image is dropped', () async {
      await dao.saveDocument(DocumentWrite(document: _document('d1')));
      await dao.setEncryptedImage(
        'd1',
        '/private/d1.enc',
        storageMode: DocumentStorageMode.withImage,
        updatedAt: DateTime(2026, 7, 29),
      );

      await dao.setEncryptedImage(
        'd1',
        null,
        storageMode: DocumentStorageMode.resultOnly,
        updatedAt: DateTime(2026, 7, 30),
      );

      final bundle = await dao.documentById('d1');

      expect(bundle!.document.encryptedImagePath, isNull);
      expect(bundle.document.storageMode, DocumentStorageMode.resultOnly);
    });
  });

  group('deleteDocument', () {
    test('takes every child row with it', () async {
      await dao.saveDocument(
        DocumentWrite(
          document: _document('d1'),
          keyInformation: [_info('رقم الحساب')],
          dates: [_date(DateTime(2026, 8, 15))],
          amounts: [_amount(250.5)],
          actions: [_action('سدد الفاتورة')],
          warnings: [_warning('راجع الجهة')],
          requiredDocuments: ['بطاقة الرقم القومي'],
        ),
      );

      await dao.deleteDocument('d1');

      expect(await dao.documentById('d1'), isNull);
      expect(await db.select(db.documentKeyInformation).get(), isEmpty);
      expect(await db.select(db.documentDates).get(), isEmpty);
      expect(await db.select(db.documentAmounts).get(), isEmpty);
      expect(await db.select(db.documentActions).get(), isEmpty);
      expect(await db.select(db.documentWarnings).get(), isEmpty);
      expect(await db.select(db.documentTextItems).get(), isEmpty);
    });

    test('leaves other documents alone', () async {
      await dao.saveDocument(
        DocumentWrite(
          document: _document('d1'),
          keyInformation: [_info('رقم الحساب')],
        ),
      );
      await dao.saveDocument(
        DocumentWrite(
          document: _document('d2'),
          keyInformation: [_info('رقم العداد')],
        ),
      );

      await dao.deleteDocument('d1');

      final kept = await dao.documentById('d2');
      expect(kept!.keyInformation.map((i) => i.label), ['رقم العداد']);
    });
  });
}

DocumentsCompanion _document(
  String id, {
  String title = 'فاتورة كهرباء',
  DocumentCategory category = DocumentCategory.invoice,
  DateTime? savedAt,
}) {
  final at = savedAt ?? DateTime(2026, 7, 29);
  return DocumentsCompanion.insert(
    id: id,
    title: title,
    category: category,
    kind: 'invoice',
    status: 'success',
    kindConfidence: 'high',
    summaryShort: 'فاتورة كهرباء عليك تسددها',
    summaryDetailed: 'الفاتورة دي عن استهلاك شهر يوليو.',
    extractedText: 'شركة الكهرباء - فاتورة',
    storageMode: DocumentStorageMode.resultOnly,
    sessionId: 'session-1',
    savedAt: at,
    updatedAt: at,
  );
}

DocumentKeyInformationCompanion _info(String label) {
  return DocumentKeyInformationCompanion.insert(
    documentId: '',
    position: 0,
    label: label,
    value: '12345',
    confidence: 'high',
    source: 'extracted',
  );
}

DocumentDatesCompanion _date(DateTime date, {int? minuteOfDay}) {
  return DocumentDatesCompanion.insert(
    documentId: '',
    position: 0,
    label: 'آخر موعد للسداد',
    date: date,
    minuteOfDay: Value(minuteOfDay),
    role: 'deadline',
    isReminderWorthy: true,
    confidence: 'high',
  );
}

DocumentAmountsCompanion _amount(double value) {
  return DocumentAmountsCompanion.insert(
    documentId: '',
    position: 0,
    label: 'إجمالي المبلغ',
    value: value,
    currency: 'EGP',
    confidence: 'high',
  );
}

DocumentActionsCompanion _action(String description) {
  return DocumentActionsCompanion.insert(
    documentId: '',
    position: 0,
    description: description,
    basis: 'explicit',
    priority: 'high',
  );
}

DocumentWarningsCompanion _warning(String message) {
  return DocumentWarningsCompanion.insert(
    documentId: '',
    position: 0,
    message: message,
    kind: 'financial',
  );
}
