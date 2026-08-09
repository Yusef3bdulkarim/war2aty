import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/document_analysis.dart';
import '../../../../core/documents/recent_document.dart';
import '../../../../core/documents/usecases/save_document.dart';
import '../../../../core/documents/usecases/save_document_with_image.dart';
import 'save_document_state.dart';

/// Drives the result screen's «حفظ الورقة» action.
///
/// Its own cubit rather than another job for `AnalysisResultCubit`: saving
/// outlives the analysis it started from — the documents screens (F08-T05
/// onwards) save nothing, and the analysis cubit should not grow a second
/// reason to change.
///
/// Depends on its use cases only (architecture rule); it never sees the
/// repository or the database.
final class SaveDocumentCubit extends Cubit<SaveDocumentState> {
  SaveDocumentCubit(this._saveDocument, this._saveDocumentWithImage)
    : super(const SaveDocumentIdle());

  final SaveDocument _saveDocument;
  final SaveDocumentWithImage _saveDocumentWithImage;

  /// Whether this paper has already been kept.
  ///
  /// Guards against a second write: the result screen stays open after a save,
  /// so a second tap would otherwise store the same paper twice under a new
  /// id (the id is generated per save, so the DAO's upsert would not catch it).
  bool get isSaved => state is SaveDocumentSaved;

  /// Saves the analysis and the text it was read from.
  ///
  /// [imagePath] is the opt-in: absent, this keeps the result only; given, it
  /// is the plaintext page picture to encrypt and keep alongside it (F08-T04).
  /// The choice comes from the save sheet, never from a default here.
  Future<void> save({
    required DocumentAnalysis analysis,
    required String extractedText,
    String? imagePath,
  }) async {
    if (isClosed || state is SaveDocumentSaving || isSaved) return;
    emit(const SaveDocumentSaving());

    final outcome = imagePath == null
        ? await _saveDocument(analysis: analysis, extractedText: extractedText)
        : await _saveDocumentWithImage(
            analysis: analysis,
            extractedText: extractedText,
            imagePath: imagePath,
          );
    if (isClosed) return;

    final storageMode = imagePath == null
        ? DocumentStorageMode.resultOnly
        : DocumentStorageMode.withImage;
    emit(
      outcome.when(
        ok: (id) => SaveDocumentSaved(id, storageMode),
        err: SaveDocumentFailed.new,
      ),
    );
  }
}
