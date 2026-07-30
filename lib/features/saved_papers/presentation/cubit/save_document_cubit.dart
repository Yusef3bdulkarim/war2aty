import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/document_analysis.dart';
import '../../../../core/documents/usecases/save_document.dart';
import 'save_document_state.dart';

/// Drives the result screen's «حفظ الورقة» action.
///
/// Its own cubit rather than another job for `AnalysisResultCubit`: saving
/// outlives the analysis it started from — the documents screens (F08-T05
/// onwards) save nothing, and the analysis cubit should not grow a second
/// reason to change.
///
/// Depends on one use case (architecture rule); it never sees the repository
/// or the database.
final class SaveDocumentCubit extends Cubit<SaveDocumentState> {
  SaveDocumentCubit(this._saveDocument) : super(const SaveDocumentIdle());

  final SaveDocument _saveDocument;

  /// Whether this paper has already been kept.
  ///
  /// Guards against a second write: the result screen stays open after a save,
  /// so a second tap would otherwise store the same paper twice under a new
  /// id (the id is generated per save, so the DAO's upsert would not catch it).
  bool get isSaved => state is SaveDocumentSaved;

  /// Saves the analysis and the text it was read from — result only, no image.
  Future<void> save({
    required DocumentAnalysis analysis,
    required String extractedText,
  }) async {
    if (isClosed || state is SaveDocumentSaving || isSaved) return;
    emit(const SaveDocumentSaving());

    final outcome = await _saveDocument(
      analysis: analysis,
      extractedText: extractedText,
    );
    if (isClosed) return;

    emit(outcome.when(ok: SaveDocumentSaved.new, err: SaveDocumentFailed.new));
  }
}
