import 'dart:isolate';
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
/// The cipher work is CPU-heavy on a full-resolution photo (this package's
/// AES-GCM is pure Dart, not hardware-accelerated) and does not yield to the
/// event loop while it runs, so it runs in a background isolate to keep the
/// UI thread free — same pattern as [ImagePackageRotator] and
/// [DartImagePreprocessor] in the capture/OCR pipelines. Only the pure byte
/// computation is offloaded: fetching the key from secure storage needs a
/// platform channel, so it stays on the calling isolate, and only the raw
/// key bytes cross the isolate boundary.
///
/// The catch-all boundary here is deliberate (CLAUDE.md §5): a `SecretBox`
/// integrity failure and a malformed-input error both become
/// [FileEncryptionFailure], and neither the plaintext nor the key is ever
/// part of that failure — only the fact that something went wrong (§7).
final class AesGcmFileEncryptor implements FileEncryptor {
  AesGcmFileEncryptor(this._keys);

  final DocumentEncryptionKeyStore _keys;

  @override
  Future<Result<Uint8List, AppFailure>> encrypt(Uint8List plaintext) async {
    try {
      final key = await _keys.keyOrCreate();
      final keyBytes = await key.extractBytes();
      final ciphertext = await Isolate.run(
        () => _encryptBytes(plaintext, keyBytes),
      );
      return Ok(ciphertext);
    } on Object {
      return const Err(FileEncryptionFailure());
    }
  }

  @override
  Future<Result<Uint8List, AppFailure>> decrypt(Uint8List ciphertext) async {
    try {
      final key = await _keys.keyOrCreate();
      final keyBytes = await key.extractBytes();
      final plaintext = await Isolate.run(
        () => _decryptBytes(ciphertext, keyBytes),
      );
      return Ok(plaintext);
    } on Object {
      // Covers both a malformed concatenation (ArgumentError) and a failed
      // MAC check (SecretBoxAuthenticationError) — both mean "not readable",
      // and the caller has no different action for either.
      return const Err(FileEncryptionFailure());
    }
  }

  /// Runs inside the isolate: encrypts with a fresh random nonce and returns
  /// `nonce ‖ ciphertext ‖ tag`. Rebuilds the algorithm/key from plain bytes
  /// rather than capturing `this` — only sendable data crosses the boundary.
  static Future<Uint8List> _encryptBytes(
    Uint8List plaintext,
    List<int> keyBytes,
  ) async {
    final algorithm = AesGcm.with256bits();
    final box = await algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(keyBytes),
    );
    return box.concatenation();
  }

  /// Runs inside the isolate: the inverse of [_encryptBytes].
  static Future<Uint8List> _decryptBytes(
    Uint8List ciphertext,
    List<int> keyBytes,
  ) async {
    final algorithm = AesGcm.with256bits();
    final box = SecretBox.fromConcatenation(
      ciphertext,
      nonceLength: algorithm.nonceLength,
      macLength: algorithm.macAlgorithm.macLength,
    );
    final plaintext = await algorithm.decrypt(
      box,
      secretKey: SecretKey(keyBytes),
    );
    return Uint8List.fromList(plaintext);
  }
}
