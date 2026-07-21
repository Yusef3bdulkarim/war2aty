import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_service.dart';

/// [SecureStorageService] backed by the platform keystore/keychain via
/// `flutter_secure_storage`. On Android, values are encrypted with the
/// platform keystore; on iOS, kept in the Keychain.
final class FlutterSecureStorageService implements SecureStorageService {
  const FlutterSecureStorageService([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
