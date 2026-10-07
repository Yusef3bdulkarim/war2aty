import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_service.dart';

/// The iOS keychain options this app stores secrets under (F27-T16).
///
/// The package's default accessibility is `unlocked` —
/// `kSecAttrAccessibleWhenUnlocked`, *without* the `ThisDeviceOnly` suffix —
/// and an item like that is included in an encrypted iTunes/Finder backup and
/// restored onto a different device. What lives in this store is the AES-256
/// document key and the installation id, so on iOS the key would have
/// travelled with the backup and arrived next to the `original.enc` files it
/// decrypts. That also contradicted the reasoning `data_extraction_rules.xml`
/// relies on ("Keystore material does not leave the device, so a restore
/// brings back ciphertext with no key"), which was only ever true on Android.
///
/// `first_unlock_this_device` rather than `unlocked_this_device`: device-bound
/// and excluded from backups either way, but readable after the first unlock,
/// so background work does not depend on the screen being unlocked at that
/// moment.
///
/// Named, rather than inlined, so a test can assert the accessibility class:
/// it only takes effect on a real device, so no behavioural test in this suite
/// could otherwise notice it reverting to the package default.
const IOSOptions kSecureStorageIosOptions = IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

/// [SecureStorageService] backed by the platform keystore/keychain via
/// `flutter_secure_storage`. On Android, values are encrypted with the
/// platform keystore; on iOS, kept in the Keychain under
/// [kSecureStorageIosOptions].
///
/// Android needs no explicit options: on `flutter_secure_storage` 10 the
/// defaults are already the strong path (an Android Keystore RSA-OAEP key
/// wrapping AES-GCM values). `encryptedSharedPreferences` is deprecated and
/// ignored in that version, so not setting it is correct rather than an
/// omission.
final class FlutterSecureStorageService implements SecureStorageService {
  const FlutterSecureStorageService([
    this._storage = const FlutterSecureStorage(
      iOptions: kSecureStorageIosOptions,
    ),
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
