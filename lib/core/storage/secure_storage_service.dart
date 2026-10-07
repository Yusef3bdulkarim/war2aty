/// Well-known keys stored in secure storage. Keeping them here avoids typo'd
/// string keys scattered across the codebase.
abstract final class SecureStorageKeys {
  /// Stable per-install identifier (UUID v4).
  static const String installationId = 'installation_id';

  /// Serialized anonymous session: the access JWT and the long-lived refresh
  /// token, so it must stay encrypted.
  ///
  /// Written by [SecureSessionLocalStorage], which F27-T16 installed as the
  /// Supabase SDK's session store. Until then this key described an intent
  /// nothing honoured for the real session — the SDK's own default put it in
  /// plain `SharedPreferences` — and only the dev-only stub repository used it.
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
