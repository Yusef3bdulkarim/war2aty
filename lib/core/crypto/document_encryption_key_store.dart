import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../storage/secure_storage_service.dart';

/// Hands out the one AES-256 key that protects saved documents' pictures.
///
/// Generated once, on the first document ever saved with an image, and kept
/// in secure storage from then on — never derived from anything document-
/// related, so it carries nothing to log or leak. Every encrypted file uses
/// the same key; only the nonce differs per file (F08-T03).
final class DocumentEncryptionKeyStore {
  DocumentEncryptionKeyStore(this._storage, {SecretKeyGenerator? generator})
    : _generateKey = generator ?? (() => AesGcm.with256bits().newSecretKey());

  final SecureStorageService _storage;
  final SecretKeyGenerator _generateKey;

  /// The key, generating and persisting one the first time this is called.
  Future<SecretKey> keyOrCreate() async {
    final stored = await _storage.read(SecureStorageKeys.documentEncryptionKey);
    if (stored != null) {
      return SecretKey(base64Decode(stored));
    }

    final key = await _generateKey();
    final bytes = await key.extractBytes();
    await _storage.write(
      SecureStorageKeys.documentEncryptionKey,
      base64Encode(bytes),
    );
    return SecretKey(Uint8List.fromList(bytes));
  }
}

/// Produces a fresh 256-bit key. A seam for tests that need a fixed key
/// rather than a random one.
typedef SecretKeyGenerator = Future<SecretKey> Function();
