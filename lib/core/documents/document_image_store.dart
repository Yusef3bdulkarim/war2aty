import 'dart:typed_data';

import '../error/app_failure.dart';
import '../result/result.dart';

/// Turns a plaintext page photo into the encrypted file a saved document
/// keeps (F08-T04).
///
/// The one place that touches a document's picture on disk: the repository
/// above it never opens a file itself, and nothing below it knows about
/// documents at all — [encryptAndStore] takes a source path and hands back
/// the encrypted one, or a failure.
abstract interface class DocumentImageStore {
  /// Encrypts the plaintext image at [sourcePath] and writes it inside the
  /// app's private directory under [documentId].
  ///
  /// [sourcePath] is deleted once the encrypted copy is safely on disk, so no
  /// plaintext outlives a save that succeeded (CLAUDE.md §7). Left in place on
  /// failure — nothing was written to keep, and the session's own cleanup
  /// (F04) removes it if the user does not try again.
  ///
  /// Returns the encrypted file's path on success.
  Future<Result<String, AppFailure>> encryptAndStore({
    required String documentId,
    required String sourcePath,
  });

  /// Decrypts and returns a saved document's image bytes, or a failure if the
  /// file is missing or cannot be decrypted.
  Future<Result<Uint8List, AppFailure>> load(String documentId);

  /// Deletes a document's encrypted picture, if it has one (F08-T11).
  Future<void> delete(String documentId);

  /// Deletes every saved document's encrypted picture in one call — settings'
  /// «حذف كل المستندات» / «حذف كل بيانات التطبيق» (F11-T11).
  Future<void> deleteAll();
}
