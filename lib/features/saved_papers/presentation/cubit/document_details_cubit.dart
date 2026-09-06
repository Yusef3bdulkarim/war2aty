import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/analysis_section.dart';
import '../../../../core/documents/document_category.dart';
import '../../../../core/documents/recent_document.dart';
import '../../../../core/documents/saved_document.dart';
import '../../../../core/documents/usecases/build_analysis_result.dart';
import '../../../../core/documents/usecases/delete_document.dart';
import '../../../../core/documents/usecases/load_document_image.dart';
import '../../../../core/documents/usecases/set_document_note.dart';
import '../../../../core/documents/usecases/update_document.dart';
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
    this._setDocumentNote,
    this._updateDocument,
    this._deleteDocument,
    this._loadDocumentImage, {
    required String documentId,
  }) : _documentId = documentId,
       super(const DocumentDetailsLoading());

  final WatchDocument _watchDocument;
  final BuildAnalysisResult _buildAnalysisResult;
  final SetDocumentNote _setDocumentNote;
  final UpdateDocument _updateDocument;
  final DeleteDocument _deleteDocument;
  final LoadDocumentImage _loadDocumentImage;
  final String _documentId;

  StreamSubscription<void>? _subscription;

  /// Cached image bytes so a database-triggered re-emission does not decrypt
  /// the file again. Cleared when the document disappears or fails.
  Uint8List? _cachedImageBytes;

  /// Starts watching the document. Safe to call more than once.
  void start() {
    if (_subscription != null) return;
    _subscription = _watchDocument(_documentId).listen((result) {
      if (isClosed) return;
      result.when(
        ok: (document) {
          if (document == null) {
            _cachedImageBytes = null;
            emit(const DocumentDetailsNotFound());
            return;
          }

          final sections = _buildAnalysisResult(
            analysis: document.analysis,
            extractedText: document.extractedText,
          ).sections;

          // Emit immediately with whatever image we already have.
          emit(
            DocumentDetailsAvailable(
              document: document,
              sections: sections,
              imageBytes: _cachedImageBytes,
            ),
          );

          // If the document has an image and we haven't loaded it yet, decrypt
          // it in the background and re-emit.
          if (document.storageMode == DocumentStorageMode.withImage &&
              _cachedImageBytes == null) {
            _loadImage(document, sections);
          }
        },
        err: (failure) {
          _cachedImageBytes = null;
          emit(DocumentDetailsUnavailable(failure));
        },
      );
    });
  }

  Future<void> _loadImage(
    SavedDocument document,
    List<AnalysisSection> sections,
  ) async {
    final result = await _loadDocumentImage(_documentId);
    if (isClosed) return;
    result.when(
      ok: (bytes) {
        _cachedImageBytes = bytes;
        // Re-emit with the decrypted image.
        emit(
          DocumentDetailsAvailable(
            document: document,
            sections: sections,
            imageBytes: bytes,
          ),
        );
      },
      err: (_) {
        // Decryption failed — the document is still usable without its image.
        // No re-emission needed; the screen already shows the analysis.
      },
    );
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

  /// Replaces the document's title (F08-T10). Same feedback contract as
  /// [saveNote]: the watcher refreshes the screen, the caller shows a snackbar.
  Future<bool> updateTitle(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || isClosed) return false;
    final result = await _updateDocument(_documentId, title: trimmed);
    return result.isOk;
  }

  /// Replaces the document's category (F08-T10). Same feedback contract.
  Future<bool> updateCategory(DocumentCategory category) async {
    if (isClosed) return false;
    final result = await _updateDocument(_documentId, category: category);
    return result.isOk;
  }

  /// Permanently removes the document and everything that belongs to it
  /// (F08-T11). Returns `true` on success so the caller can navigate away.
  ///
  /// The watcher will emit `null` once the row is gone, which transitions the
  /// screen to [DocumentDetailsNotFound] — but the caller should not wait for
  /// that; it pops immediately on success.
  Future<bool> deleteDocument() async {
    if (isClosed) return false;
    final result = await _deleteDocument(_documentId);
    return result.isOk;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
