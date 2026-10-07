import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/storage/flutter_secure_storage_service.dart';

/// F27-T16: the iOS keychain items are device-bound.
///
/// `const FlutterSecureStorage()` defaults to `KeychainAccessibility.unlocked`
/// — `kSecAttrAccessibleWhenUnlocked`, *without* `ThisDeviceOnly`. iCloud
/// sync is off by default, but an item like that is still included in an
/// encrypted iTunes/Finder backup and restored onto a different device. What
/// this store holds is the AES-256 document key and the installation id, so on
/// iOS the key would have ridden the backup to a new device and arrived beside
/// the `original.enc` files it decrypts — every saved photograph of a bill,
/// court paper or medical letter.
///
/// It also broke the reasoning `data_extraction_rules.xml` leans on
/// ("Keystore material does not leave the device, so a restore brings back
/// ciphertext with no key"), which was only ever true on Android.
///
/// This is a guard rather than a behaviour test, because the accessibility class
/// is enforced by iOS at runtime and there is no iOS runtime here — hence
/// asserting the value the app will hand the platform.
void main() {
  group('secure storage iOS options (F27-T16)', () {
    test('keychain items are bound to this device', () {
      expect(
        kSecureStorageIosOptions.accessibility,
        KeychainAccessibility.first_unlock_this_device,
        reason:
            'anything without a ThisDeviceOnly accessibility class travels in '
            'an encrypted iOS backup, taking the document encryption key with '
            'it',
      );
    });

    test('the accessibility class is not the package default', () {
      // Negative-proves the test: if someone drops the explicit options, the
      // package default comes back and this fails.
      expect(
        kSecureStorageIosOptions.accessibility,
        isNot(IOSOptions.defaultOptions.accessibility),
        reason:
            'the package default is `unlocked`, which is not device-bound — if '
            'these now match, the explicit options have been lost',
      );
    });

    test('iCloud keychain sync stays off', () {
      expect(
        kSecureStorageIosOptions.synchronizable,
        isFalse,
        reason: 'syncing the document key to iCloud would defeat the point',
      );
    });
  });
}
