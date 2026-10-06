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
/// The catch-all boundary here is deliberate (CLAUDE.md §5): a `SecretBox`
/// integrity failure and a malformed-input error both become
/// [FileEncryptionFailure], and neither the plaintext nor the key is ever
/// part of that failure — only the fact that something went wrong (§7).
/// **The cipher runs in a background isolate** (F27-T15). `package:cryptography`
/// has no Flutter plugin here, so `AesGcm` is its pure-Dart implementation and
/// does all its work on whichever isolate calls it, `async` signature or not.
/// A saved page is a multi-megabyte JPEG, so on the UI isolate that froze the
/// frame -- once when the user saves a paper with its picture, and again every
/// time they open one.
///
/// The key does not leave the process. `Isolate.run` *copies* the captured
/// bytes rather than sharing them -- same-isolate-group does not mean shared
/// mutable heap -- but the copy lands in another isolate of this same app:
/// never a file, never a log, never a wire format. That copy is also why this
/// is only worth doing for page-sized payloads; a few megabytes of memcpy buys
/// back tens to hundreds of milliseconds of cipher work on a low-end phone,
/// and would not be worth it for a small one.
///
/// Reading the key stays out here, because secure storage is a platform
/// channel that only the root isolate has.
final class AesGcmFileEncryptor implements FileEncryptor {
  AesGcmFileEncryptor(this._keys) : _algorithm = AesGcm.with256bits();

  final DocumentEncryptionKeyStore _keys;
  final AesGcm _algorithm;

  @override
  Future<Result<Uint8List, AppFailure>> encrypt(Uint8List plaintext) async {
    try {
      final key = await _keys.keyOrCreate();
      final keyBytes = await key.extractBytes();
      final box = await Isolate.run(
        () => AesGcm.with256bits().encrypt(
          plaintext,
          secretKey: SecretKey(keyBytes),
        ),
      );
      return Ok(box.concatenation());
    } on Object {
      return const Err(FileEncryptionFailure());
    }
  }

  @override
  Future<Result<Uint8List, AppFailure>> decrypt(Uint8List ciphertext) async {
    try {
      final key = await _keys.keyOrCreate();
      final keyBytes = await key.extractBytes();
      final box = SecretBox.fromConcatenation(
        ciphertext,
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      final plaintext = await Isolate.run(
        () => AesGcm.with256bits().decrypt(box, secretKey: SecretKey(keyBytes)),
      );
      return Ok(Uint8List.fromList(plaintext));
    } on Object {
      // Covers both a malformed concatenation (ArgumentError) and a failed
      // MAC check (SecretBoxAuthenticationError) — both mean "not readable",
      // and the caller has no different action for either.
      return const Err(FileEncryptionFailure());
    }
  }
}
