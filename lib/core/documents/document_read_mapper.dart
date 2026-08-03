import '../database/app_database.dart';
import 'recent_document.dart';

/// Turns a stored row back into the little a list row needs.
///
/// The reverse of [documentWriteOf] (`document_write_mapper.dart`), but far
/// smaller: [RecentDocument] carries only what Home's strip and the documents
/// list (F08-T05) show, so nothing else on [row] is read here.
RecentDocument recentDocumentOf(DocumentRow row) => RecentDocument(
  id: row.id,
  title: row.title,
  category: row.category,
  storageMode: row.storageMode,
  savedAt: row.savedAt,
);
