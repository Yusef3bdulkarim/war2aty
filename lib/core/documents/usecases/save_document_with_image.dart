import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../document_analysis.dart';
import '../documents_repository.dart';

/// Keeps the paper the user is looking at, picture included.
///
/// The result screen's second «حفظ الورقة» path — chosen explicitly in the
/// save sheet, never the default. A separate use case from `SaveDocument`
/// rather than an optional flag on it: the privacy-default entry point stays
/// one that structurally cannot be asked to keep a picture.
final class SaveDocumentWithImage {
  const SaveDocumentWithImage(this._repository);

  final DocumentsRepository _repository;

  /// Returns the saved document's id, or the failure to show instead.
  Future<Result<String, AppFailure>> call({
    required DocumentAnalysis analysis,
    required String extractedText,
    required String imagePath,
  }) {
    return _repository.saveWithImage(
      analysis: analysis,
      extractedText: extractedText,
      imagePath: imagePath,
    );
  }
}
