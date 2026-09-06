import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../error/app_failure.dart';
import '../result/result.dart';
import 'document_encryption_key_store.dart';
import 'file_encryptor.dart';

/// [FileEncryptor] backed by AES-256-GCM (`package:cryptography`).
///
/// Output is `nonce ‖ ciphertext ‖ tag` — [SecretBox.concatenation] — so a
/// saved document needs no separate nonce column (see `document_tables.dart`):
/// the file carries everything [decrypt] needs to read it back.
///
/// The catch-all boundary here is deliberate (CLAUDE.md §5): a `SecretBox`
/// integrity failure and a malformed-input error both become
/// [FileEncryptionFailure], and neither the plaintext nor the key is ever
/// part of that failure — only the fact that something went wrong (§7).
final class AesGcmFileEncryptor implements FileEncryptor {
  AesGcmFileEncryptor(this._keys) : _algorithm = AesGcm.with256bits();

  final DocumentEncryptionKeyStore _keys;
  final AesGcm _algorithm;

  @override
  Future<Result<Uint8List, AppFailure>> encrypt(Uint8List plaintext) async {
    try {
      final key = await _keys.keyOrCreate();
      final box = await _algorithm.encrypt(plaintext, secretKey: key);
      return Ok(box.concatenation());
    } on Object {
      return const Err(FileEncryptionFailure());
    }
  }

  @override
  Future<Result<Uint8List, AppFailure>> decrypt(Uint8List ciphertext) async {
    try {
      final key = await _keys.keyOrCreate();
      final box = SecretBox.fromConcatenation(
        ciphertext,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      final plaintext = await _algorithm.decrypt(box, secretKey: key);
      return Ok(Uint8List.fromList(plaintext));
    } on Object {
      // Covers both a malformed concatenation (ArgumentError) and a failed
      // MAC check (SecretBoxAuthenticationError) — both mean "not readable",
      // and the caller has no different action for either.
      return const Err(FileEncryptionFailure());
    }
  }
}
