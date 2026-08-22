import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/documents/document_analysis.dart';
import '../../../../core/documents/recent_document.dart';
import '../../../../core/documents/usecases/save_document.dart';
import '../../../../core/documents/usecases/save_document_with_image.dart';
import '../../../../core/storage/usecases/cleanup_analysis_session.dart';
import 'save_document_state.dart';

/// Drives the result screen's «حفظ الورقة» action.
///
/// Its own cubit rather than another job for `AnalysisResultCubit`: saving
/// outlives the analysis it started from — the documents screens (F08-T05
/// onwards) save nothing, and the analysis cubit should not grow a second
/// reason to change.
///
/// Also the last possible reader of the analysis session's processed photo
/// (`AnalysisSessionStorage`'s `<cache>/analysis_sessions/{id}/`): the
/// offline OCR pass may have left a resized copy beside it, and neither the
/// online nor offline route ever deletes that directory itself — the only
/// prior cleanup was the *next app launch's* stale-session sweep. [save] and
/// [close] below close that gap explicitly (F12-T06 — privacy §7: no temp
/// copy should outlive the flow that created it, not just "until next cold
/// start").
///
/// Depends on its use cases only (architecture rule); it never sees the
/// repository or the database.
final class SaveDocumentCubit extends Cubit<SaveDocumentState> {
  SaveDocumentCubit(
    this._saveDocument,
    this._saveDocumentWithImage, {
    required String sessionId,
    required CleanupAnalysisSession cleanupSession,
  }) : _sessionId = sessionId,
       _cleanupSession = cleanupSession,
       super(const SaveDocumentIdle());

  final SaveDocument _saveDocument;
  final SaveDocumentWithImage _saveDocumentWithImage;
  final String _sessionId;
  final CleanupAnalysisSession _cleanupSession;

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

    // Whatever this save needed from the session's temp files, it has read
    // them by now — sequential, so this can never race that read. A
    // result-only save never opened them at all; a with-image save has
    // already consumed and deleted the one file it needed
    // (`FileDocumentImageStore`). Either way, nothing left in the session's
    // cache directory should wait for the next app launch to go. Runs even
    // if [close] already ran (see its own doc comment).
    unawaited(_cleanupSession(_sessionId));

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

  /// Safety net for the one exit path with no button: the user backs out (or
  /// the app is killed) before ever tapping «حفظ الورقة». [save] never ran in
  /// that case, so its own cleanup above never fired.
  ///
  /// Skipped while a save is genuinely in flight ([SaveDocumentSaving]):
  /// that call's own cleanup above still runs once it resolves — even though
  /// this cubit is already closed by then, the call itself keeps running —
  /// so deleting here at the same moment would only race its still-in-flight
  /// read of the session's image for no reason.
  @override
  Future<void> close() {
    if (state is! SaveDocumentSaving) unawaited(_cleanupSession(_sessionId));
    return super.close();
  }
}
