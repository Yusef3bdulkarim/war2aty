import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/database/daos/documents_dao.dart';
import 'package:war2aty/core/database/tables/document_tables.dart';
import 'package:war2aty/core/documents/analysis_date.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_warning.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/document_read_mapper.dart';
import 'package:war2aty/core/documents/key_information.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/documents/required_action.dart';

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

  group('savedDocumentOf', () {
    DocumentBundle bundle({
      String kind = 'invoice',
      String status = 'success',
      String kindConfidence = 'high',
      String? note,
      DocumentStorageMode storageMode = DocumentStorageMode.resultOnly,
      List<DocumentInfoRow> keyInformation = const [],
      List<DocumentDateRow> dates = const [],
      List<DocumentAmountRow> amounts = const [],
      List<DocumentActionRow> actions = const [],
      List<DocumentWarningRow> warnings = const [],
      List<DocumentTextItemRow> textItems = const [],
    }) {
      final at = DateTime(2026, 7, 29, 14, 30);
      return DocumentBundle(
        document: DocumentRow(
          id: 'doc-1',
          title: 'فاتورة كهرباء',
          category: DocumentCategory.invoice,
          kind: kind,
          status: status,
          kindConfidence: kindConfidence,
          summaryShort: 'سددها',
          summaryDetailed: 'فاتورة شهر يوليو.',
          extractedText: 'شركة الكهرباء',
          storageMode: storageMode,
          note: note,
          sessionId: 'session-1',
          savedAt: at,
          updatedAt: at,
        ),
        keyInformation: keyInformation,
        dates: dates,
        amounts: amounts,
        actions: actions,
        warnings: warnings,
        textItems: textItems,
      );
    }

    test('carries the id and the bookkeeping fields across', () {
      final document = savedDocumentOf(
        bundle(
          note: 'ادفع من الفوري',
          storageMode: DocumentStorageMode.withImage,
        ),
      );

      expect(document.id, 'doc-1');
      expect(document.extractedText, 'شركة الكهرباء');
      expect(document.storageMode, DocumentStorageMode.withImage);
      expect(document.note, 'ادفع من الفوري');
      expect(document.savedAt, DateTime(2026, 7, 29, 14, 30));
      expect(document.updatedAt, DateTime(2026, 7, 29, 14, 30));
    });

    test('leaves the note null when none was written', () {
      expect(savedDocumentOf(bundle()).note, isNull);
    });

    test('rebuilds the analysis from the row', () {
      final document = savedDocumentOf(bundle());

      expect(document.analysis.sessionId, 'session-1');
      expect(document.analysis.status, AnalysisStatus.success);
      expect(document.analysis.kind, DocumentKind.invoice);
      expect(document.analysis.title, 'فاتورة كهرباء');
      expect(document.analysis.kindConfidence, ConfidenceBand.high);
      expect(document.analysis.summary.short, 'سددها');
      expect(document.analysis.summary.detailed, 'فاتورة شهر يوليو.');
    });

    test('rebuilds each key-information row', () {
      final document = savedDocumentOf(
        bundle(
          keyInformation: [
            const DocumentInfoRow(
              documentId: 'doc-1',
              position: 0,
              label: 'رقم الحساب',
              value: '12345',
              confidence: 'medium',
              source: 'inferred',
            ),
          ],
        ),
      );

      final info = document.analysis.keyInformation.single;
      expect(info.label, 'رقم الحساب');
      expect(info.value, '12345');
      expect(info.confidence, ConfidenceBand.medium);
      expect(info.source, InfoSource.inferred);
    });

    test('rebuilds a date with the time the paper gave', () {
      final document = savedDocumentOf(
        bundle(
          dates: [
            DocumentDateRow(
              documentId: 'doc-1',
              position: 0,
              label: 'آخر موعد للسداد',
              date: DateTime(2026, 8, 15),
              minuteOfDay: 9 * 60 + 30,
              role: 'deadline',
              isReminderWorthy: true,
              confidence: 'high',
            ),
          ],
        ),
      );

      final date = document.analysis.dates.single;
      expect(date.date, DateTime(2026, 8, 15));
      expect(date.time, const AnalysisTime(hour: 9, minute: 30));
      expect(date.role, DateRole.deadline);
      expect(date.isReminderWorthy, isTrue);
    });

    test('keeps a date with no time absent rather than midnight', () {
      final document = savedDocumentOf(
        bundle(
          dates: [
            DocumentDateRow(
              documentId: 'doc-1',
              position: 0,
              label: 'آخر موعد للسداد',
              date: DateTime(2026, 8, 15),
              role: 'deadline',
              isReminderWorthy: true,
              confidence: 'high',
            ),
          ],
        ),
      );

      expect(document.analysis.dates.single.time, isNull);
    });

    test('rebuilds an amount', () {
      final document = savedDocumentOf(
        bundle(
          amounts: [
            const DocumentAmountRow(
              documentId: 'doc-1',
              position: 0,
              label: 'إجمالي المبلغ',
              value: 250.5,
              currency: 'EGP',
              confidence: 'high',
            ),
          ],
        ),
      );

      final amount = document.analysis.amounts.single;
      expect(amount.value, 250.5);
      expect(amount.currency, 'EGP');
    });

    test('rebuilds an action', () {
      final document = savedDocumentOf(
        bundle(
          actions: [
            const DocumentActionRow(
              documentId: 'doc-1',
              position: 0,
              description: 'سدد الفاتورة',
              basis: 'inferred',
              priority: 'high',
            ),
          ],
        ),
      );

      final action = document.analysis.actions.single;
      expect(action.description, 'سدد الفاتورة');
      expect(action.basis, ActionBasis.inferred);
      expect(action.priority, ActionPriority.high);
    });

    test('rebuilds a warning', () {
      final document = savedDocumentOf(
        bundle(
          warnings: [
            const DocumentWarningRow(
              documentId: 'doc-1',
              position: 0,
              message: 'راجع الجهة',
              kind: 'government',
            ),
          ],
        ),
      );

      expect(document.analysis.warnings.single.text, 'راجع الجهة');
      expect(document.analysis.warnings.single.kind, WarningKind.government);
    });

    test('splits the plain-text lists back apart by kind', () {
      final document = savedDocumentOf(
        bundle(
          textItems: const [
            DocumentTextItemRow(
              documentId: 'doc-1',
              kind: DocumentTextItemKind.requiredDocument,
              position: 0,
              value: 'بطاقة الرقم القومي',
            ),
            DocumentTextItemRow(
              documentId: 'doc-1',
              kind: DocumentTextItemKind.instruction,
              position: 0,
              value: 'روح لأقرب فرع',
            ),
            DocumentTextItemRow(
              documentId: 'doc-1',
              kind: DocumentTextItemKind.missingField,
              position: 0,
              value: 'dueDate',
            ),
          ],
        ),
      );

      expect(document.analysis.requiredDocuments, ['بطاقة الرقم القومي']);
      expect(document.analysis.instructions, ['روح لأقرب فرع']);
      expect(document.analysis.missingFields, ['dueDate']);
    });

    test(
      'degrades a kind that no longer parses to other rather than throwing',
      () {
        final document = savedDocumentOf(bundle(kind: 'no-longer-a-kind'));

        expect(document.analysis.kind, DocumentKind.other);
      },
    );

    test(
      'degrades a status that no longer parses to partial rather than throwing',
      () {
        final document = savedDocumentOf(bundle(status: 'no-longer-a-status'));

        expect(document.analysis.status, AnalysisStatus.partial);
      },
    );

    test('degrades a confidence band that no longer parses to low', () {
      final document = savedDocumentOf(
        bundle(kindConfidence: 'no-longer-a-band'),
      );

      expect(document.analysis.kindConfidence, ConfidenceBand.low);
    });
  });
}
