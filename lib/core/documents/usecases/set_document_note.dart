import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../documents_repository.dart';

/// Adds, replaces, or removes the user's note on a saved document (F08-T09).
///
/// A `null` [note] deletes it. The note is the user's own words; the privacy
/// contract (CLAUDE.md §7) forbids logging it, same as the extracted text.
final class SetDocumentNote {
  const SetDocumentNote(this._repository);

  final DocumentsRepository _repository;

  Future<Result<void, AppFailure>> call(String documentId, String? note) =>
      _repository.setNote(documentId, note);
}
