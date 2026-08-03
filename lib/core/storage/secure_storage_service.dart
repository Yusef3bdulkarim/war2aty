/// Well-known keys stored in secure storage. Keeping them here avoids typo'd
/// string keys scattered across the codebase.
abstract final class SecureStorageKeys {
  /// Stable per-install identifier (UUID v4).
  static const String installationId = 'installation_id';

  /// Serialized anonymous session (contains a JWT — must stay encrypted).
  static const String session = 'session';

  /// Base64-encoded AES-256 key that encrypts saved documents' images
  /// (F08-T03). Generated on first use; losing it makes every encrypted
  /// picture unreadable, which is why it lives here and not beside the files
  /// it protects.
  static const String documentEncryptionKey = 'document_encryption_key';
}

/// A thin, testable wrapper over encrypted key/value storage.
///
/// Only small secrets/identifiers live here (e.g. the installation id) — never
/// document content. Implementations back this with platform secure storage;
/// tests use an in-memory fake.
abstract interface class SecureStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
