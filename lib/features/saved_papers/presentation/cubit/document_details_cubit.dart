import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/usecases/build_analysis_result.dart';
import '../../../../core/documents/usecases/set_document_note.dart';
import '../../../../core/documents/usecases/watch_document.dart';
import 'document_details_state.dart';

/// Feeds the document details screen from the local database (F08-T08).
///
/// One instance per opened document — [_documentId] is fixed at creation, the
/// way [ImagePreviewCubit] is fixed to one image. Depends on its use cases
/// only (architecture rule); it never sees the repository or the database.
final class DocumentDetailsCubit extends Cubit<DocumentDetailsState> {
  DocumentDetailsCubit(
    this._watchDocument,
    this._buildAnalysisResult,
    this._setDocumentNote, {
    required String documentId,
  }) : _documentId = documentId,
       super(const DocumentDetailsLoading());

  final WatchDocument _watchDocument;
  final BuildAnalysisResult _buildAnalysisResult;
  final SetDocumentNote _setDocumentNote;
  final String _documentId;

  StreamSubscription<void>? _subscription;

  /// Starts watching the document. Safe to call more than once.
  void start() {
    if (_subscription != null) return;
    _subscription = _watchDocument(_documentId).listen((result) {
      if (isClosed) return;
      emit(
        result.when(
          ok: (document) => document == null
              ? const DocumentDetailsNotFound()
              // The same ordering the result screen draws from, so a saved
              // paper reads exactly as it did before it was saved (F08-T08).
              : DocumentDetailsAvailable(
                  document: document,
                  sections: _buildAnalysisResult(
                    analysis: document.analysis,
                    extractedText: document.extractedText,
                  ).sections,
                ),
          err: DocumentDetailsUnavailable.new,
        ),
      );
    });
  }

  /// Saves or replaces the user's note (F08-T09). The watcher picks up the
  /// change and refreshes the screen, so no manual state mutation here.
  ///
  /// Returns `true` on success so the caller can show feedback.
  Future<bool> saveNote(String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty || isClosed) return false;
    final result = await _setDocumentNote(_documentId, trimmed);
    return result.isOk;
  }

  /// Removes the user's note (F08-T09). Same feedback contract as [saveNote].
  Future<bool> deleteNote() async {
    if (isClosed) return false;
    final result = await _setDocumentNote(_documentId, null);
    return result.isOk;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
