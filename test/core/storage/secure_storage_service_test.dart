import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';

import '../../support/fakes.dart';

void main() {
  late SecureStorageService storage;

  setUp(() => storage = FakeSecureStorage());

  test('read returns null for a missing key', () async {
    expect(await storage.read('nope'), isNull);
  });

  test('write then read round-trips', () async {
    await storage.write('k', 'v');
    expect(await storage.read('k'), 'v');
  });

  test('write overwrites an existing key', () async {
    await storage.write('k', 'v1');
    await storage.write('k', 'v2');
    expect(await storage.read('k'), 'v2');
  });

  test('delete removes only the given key', () async {
    await storage.write('a', '1');
    await storage.write('b', '2');
    await storage.delete('a');
    expect(await storage.read('a'), isNull);
    expect(await storage.read('b'), '2');
  });

  test('delete on a missing key is a no-op', () async {
    await storage.delete('ghost');
    expect(await storage.read('ghost'), isNull);
  });

  test('keys are namespaced constants, not ad-hoc strings', () {
    expect(SecureStorageKeys.installationId, 'installation_id');
  });
}
