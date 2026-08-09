import '../error/app_failure.dart';
import '../result/result.dart';
import 'document_analysis.dart';
import 'document_category.dart';
import 'recent_document.dart';
import 'saved_document.dart';

/// Keeps analysed papers on the device.
///
/// Lives in `core/` for the same reason [RecentDocumentsRepository] does: the
/// result screen writes documents, Home reads the newest of them and the
/// documents list (F08) reads all of them. Nothing here ever reaches the
/// network — a saved paper stays on the phone (CLAUDE.md §7).
abstract interface class DocumentsRepository {
  /// Watches saved documents, newest first (F08-T05).
  ///
  /// [titleQuery], when given, narrows the stream to titles containing it —
  /// matched case-insensitively by the database (F08-T06). [category], when
  /// given, narrows it to that one filter chip (F08-T07). The two combine.
  /// An empty list means "nothing saved" or "nothing matched", the same
  /// convention [RecentDocumentsRepository.watchRecent] uses for an empty
  /// library; failures arrive as `Err` values rather than as stream errors,
  /// so a transient problem cannot tear the stream down.
  Stream<Result<List<RecentDocument>, AppFailure>> watchDocuments({
    String? titleQuery,
    DocumentCategory? category,
  });

  /// Watches one saved document, in full — the details screen (F08-T08).
  ///
  /// Emits `null` once the document is gone (deleted, or never there), the
  /// same "answer, not a failure" convention [watchDocuments] uses for an
  /// empty list — a missing document is something the screen shows, not an
  /// error it reports.
  Stream<Result<SavedDocument?, AppFailure>> watchDocument(String id);

  /// Updates the fields the user can edit on a saved document (F08-T10).
  ///
  /// Either field may be omitted, in which case it keeps its current value.
  /// The underlying row's `updatedAt` is always touched.
  Future<Result<void, AppFailure>> updateDocument(
    String id, {
    String? title,
    DocumentCategory? category,
  });

  /// Adds, replaces, or removes the user's note on a saved document (F08-T09).
  ///
  /// A `null` [note] deletes it. The note is the user's own words; the privacy
  /// contract (CLAUDE.md §7) forbids logging it, same as the extracted text.
  Future<Result<void, AppFailure>> setNote(String id, String? note);

  /// Saves [analysis] and the text it was read from, and nothing else.
  ///
  /// This is the privacy default: no picture is written, so a saved document
  /// costs the user only what they already saw on the screen. Keeping the
  /// image is a separate opt-in step (F08-T04).
  ///
  /// Returns the new document's id on success.
  Future<Result<String, AppFailure>> saveResultOnly({
    required DocumentAnalysis analysis,
    required String extractedText,
  });

  /// Saves [analysis], the text it was read from, and the page picture at
  /// [imagePath] — the explicit opt-in (F08-T04).
  ///
  /// The picture is encrypted before it touches the private directory, and
  /// the plaintext at [imagePath] is gone once this returns [Ok]. Nothing is
  /// written at all if the encryption step fails.
  ///
  /// Returns the new document's id on success.
  Future<Result<String, AppFailure>> saveWithImage({
    required DocumentAnalysis analysis,
    required String extractedText,
    required String imagePath,
  });

  /// Deletes a saved document and its encrypted image, if any (F08-T11).
  ///
  /// The database cascade removes every child row; the image store removes
  /// the encrypted file. Once F09 lands, a linked reminder should be
  /// cancelled here as well — for now there is nothing to cancel.
  Future<Result<void, AppFailure>> deleteDocument(String id);
}
