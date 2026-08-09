import 'document_analysis.dart';
import 'recent_document.dart';

/// One saved document, in full — the details screen's subject (F08-T08).
///
/// [RecentDocument] is what a list row needs; this is what opening one shows:
/// the whole [analysis] the paper was understood as, the text it came from,
/// and the bookkeeping around the save itself — how much was kept, the user's
/// own note, and when.
///
/// Pure Dart, no Flutter import.
final class SavedDocument {
  const SavedDocument({
    required this.id,
    required this.analysis,
    required this.extractedText,
    required this.storageMode,
    required this.note,
    required this.savedAt,
    required this.updatedAt,
  });

  final String id;

  final DocumentAnalysis analysis;

  /// The normalized OCR text the analysis was built from.
  final String extractedText;

  final DocumentStorageMode storageMode;

  /// The user's own note — «ملاحظتي» (F08-T09). `null` until they write one.
  final String? note;

  final DateTime savedAt;

  /// Last edit to title, category, note or stored image.
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedDocument &&
          other.id == id &&
          other.analysis == analysis &&
          other.extractedText == extractedText &&
          other.storageMode == storageMode &&
          other.note == note &&
          other.savedAt == savedAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    analysis,
    extractedText,
    storageMode,
    note,
    savedAt,
    updatedAt,
  );

  // Neither the analysis nor the note nor the text is printed — all three are
  // document content and entity toStrings reach logs and error reports
  // (privacy §7).
  @override
  String toString() => 'SavedDocument($id, $storageMode)';
}
