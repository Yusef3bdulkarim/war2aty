import 'document_category.dart';

/// How much of a document was kept on the device.
///
/// The privacy default is [resultOnly]; saving the picture is opt-in
/// (CLAUDE.md §7), and the user is told which one applies.
enum DocumentStorageMode { resultOnly, withImage }

/// The little a list row needs to know about a saved document.
///
/// Deliberately *not* the full document: Home shows a title, a category and a
/// storage badge, so that is all this carries. Nothing here is document
/// content beyond the title the user already sees.
final class RecentDocument {
  const RecentDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.storageMode,
    required this.savedAt,
  });

  final String id;
  final String title;
  final DocumentCategory category;
  final DocumentStorageMode storageMode;
  final DateTime savedAt;

  @override
  bool operator ==(Object other) =>
      other is RecentDocument &&
      other.id == id &&
      other.title == title &&
      other.category == category &&
      other.storageMode == storageMode &&
      other.savedAt == savedAt;

  @override
  int get hashCode => Object.hash(id, title, category, storageMode, savedAt);
}
