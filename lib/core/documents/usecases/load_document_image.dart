import 'dart:typed_data';

import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../document_image_store.dart';

/// Decrypts and returns a saved document's picture bytes.
///
/// The details screen's image section: when the user saved with
/// [DocumentStorageMode.withImage], this hands back the decrypted picture
/// so the screen can display it.
final class LoadDocumentImage {
  const LoadDocumentImage(this._store);

  final DocumentImageStore _store;

  /// Returns the plaintext image bytes, or a failure if the file is missing
  /// or cannot be decrypted.
  Future<Result<Uint8List, AppFailure>> call(String documentId) =>
      _store.load(documentId);
}
