import 'dart:typed_data';

import '../error/app_failure.dart';
import '../result/result.dart';

/// Encrypts and decrypts bytes for at-rest storage.
///
/// A generic primitive, not a documents concern: it knows nothing about
/// pictures, papers or the database. [FileEncryptor.encrypt] and
/// [FileEncryptor.decrypt] are inverses of each other and of nothing else —
/// there is no format compatibility with any other encryption in the app.
abstract interface class FileEncryptor {
  /// Encrypts [plaintext]. The nonce is random per call and travels inside
  /// the returned bytes, so nothing else needs to track it.
  Future<Result<Uint8List, AppFailure>> encrypt(Uint8List plaintext);

  /// Decrypts bytes this same encryptor produced.
  ///
  /// Fails — rather than returning corrupted bytes — if [ciphertext] was
  /// tampered with or truncated: GCM's authentication tag is checked before
  /// anything is returned.
  Future<Result<Uint8List, AppFailure>> decrypt(Uint8List ciphertext);
}
