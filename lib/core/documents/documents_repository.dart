import '../error/app_failure.dart';
import '../result/result.dart';
import 'document_analysis.dart';

/// Keeps analysed papers on the device.
///
/// Lives in `core/` for the same reason [RecentDocumentsRepository] does: the
/// result screen writes documents, Home reads the newest of them and the
/// documents list (F08) reads all of them. Nothing here ever reaches the
/// network — a saved paper stays on the phone (CLAUDE.md §7).
abstract interface class DocumentsRepository {
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
}
