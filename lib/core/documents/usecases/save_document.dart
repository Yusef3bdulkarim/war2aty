import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../document_analysis.dart';
import '../documents_repository.dart';

/// Keeps the paper the user is looking at — the result only, no picture.
///
/// The one entry point the result screen's «حفظ الورقة» goes through. It takes
/// the analysis and the text it was built from, never an image path: the
/// privacy default is not a flag this use case could be asked to turn off.
final class SaveDocument {
  const SaveDocument(this._repository);

  final DocumentsRepository _repository;

  /// Returns the saved document's id, or the failure to show instead.
  Future<Result<String, AppFailure>> call({
    required DocumentAnalysis analysis,
    required String extractedText,
  }) {
    return _repository.saveResultOnly(
      analysis: analysis,
      extractedText: extractedText,
    );
  }
}
