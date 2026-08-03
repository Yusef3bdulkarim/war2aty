import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/document_read_mapper.dart';
import 'package:war2aty/core/documents/recent_document.dart';

void main() {
  DocumentRow row({
    String id = 'doc-1',
    String title = 'فاتورة كهرباء',
    DocumentCategory category = DocumentCategory.invoice,
    DocumentStorageMode storageMode = DocumentStorageMode.resultOnly,
    DateTime? savedAt,
  }) {
    final at = savedAt ?? DateTime(2026, 7, 29, 14, 30);
    return DocumentRow(
      id: id,
      title: title,
      category: category,
      kind: 'invoice',
      status: 'success',
      kindConfidence: 'high',
      summaryShort: 'سددها',
      summaryDetailed: 'فاتورة شهر يوليو.',
      extractedText: 'شركة الكهرباء',
      storageMode: storageMode,
      sessionId: 'session-1',
      savedAt: at,
      updatedAt: at,
    );
  }

  test('carries the id, title, category and storage mode across', () {
    final document = recentDocumentOf(
      row(
        id: 'doc-2',
        title: 'موعد الأشعة',
        category: DocumentCategory.appointment,
        storageMode: DocumentStorageMode.withImage,
      ),
    );

    expect(document.id, 'doc-2');
    expect(document.title, 'موعد الأشعة');
    expect(document.category, DocumentCategory.appointment);
    expect(document.storageMode, DocumentStorageMode.withImage);
  });

  test('carries the save timestamp across unchanged', () {
    final at = DateTime(2026, 8, 1, 9);

    final document = recentDocumentOf(row(savedAt: at));

    expect(document.savedAt, at);
  });

  test('reads none of the row fields it does not need', () {
    // A row with a note, an encrypted image path and full analysis text —
    // recentDocumentOf must not choke on, or leak, any of it.
    final withExtras = DocumentRow(
      id: 'doc-3',
      title: 'ورقة',
      category: DocumentCategory.government,
      kind: 'government',
      status: 'partial',
      kindConfidence: 'low',
      summaryShort: 'ملخص',
      summaryDetailed: 'تفاصيل حساسة',
      extractedText: 'نص خام حساس',
      storageMode: DocumentStorageMode.withImage,
      encryptedImagePath: '/private/documents/doc-3/original.enc',
      note: 'ملاحظتي الخاصة',
      sessionId: 'session-9',
      savedAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 1),
    );

    final document = recentDocumentOf(withExtras);

    expect(document.id, 'doc-3');
    expect(document.category, DocumentCategory.government);
  });
}
