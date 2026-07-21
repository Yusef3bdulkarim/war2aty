import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/identity/installation_id_provider.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';

import '../../support/fakes.dart';

/// Storage that always blows up — exercises the failure boundary.
final class _ThrowingStorage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => throw Exception('boom');

  @override
  Future<void> write(String key, String value) async => throw Exception('boom');

  @override
  Future<void> delete(String key) async => throw Exception('boom');
}

void main() {
  test('generates and persists an id on first launch', () async {
    final storage = FakeSecureStorage();
    final provider = SecureInstallationIdProvider(
      storage,
      generator: () => 'generated-id',
    );

    final result = await provider.getOrCreate();

    expect(result, const Ok<String, AppFailure>('generated-id'));
    expect(storage.contents[SecureStorageKeys.installationId], 'generated-id');
  });

  test('is stable across launches — same id on a second call', () async {
    var counter = 0;
    final storage = FakeSecureStorage();
    final provider = SecureInstallationIdProvider(
      storage,
      generator: () => 'id-${counter++}',
    );

    final first = await provider.getOrCreate();
    final second = await provider.getOrCreate();

    expect(first, second);
    expect(counter, 1, reason: 'generator must run only once');
  });

  test('returns the already-stored id without generating', () async {
    final storage = FakeSecureStorage({
      SecureStorageKeys.installationId: 'existing-id',
    });
    final provider = SecureInstallationIdProvider(
      storage,
      generator: () => fail('generator must not be called'),
    );

    expect(
      await provider.getOrCreate(),
      const Ok<String, AppFailure>('existing-id'),
    );
  });

  test('regenerates when the stored value is empty', () async {
    final storage = FakeSecureStorage({SecureStorageKeys.installationId: ''});
    final provider = SecureInstallationIdProvider(
      storage,
      generator: () => 'fresh-id',
    );

    expect(
      await provider.getOrCreate(),
      const Ok<String, AppFailure>('fresh-id'),
    );
  });

  test('default generator produces a valid UUID v4', () async {
    final provider = SecureInstallationIdProvider(FakeSecureStorage());

    final id = (await provider.getOrCreate()).valueOrNull!;

    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(id),
      isTrue,
      reason: 'expected a UUID v4, got $id',
    );
  });

  test(
    'storage errors become a classified failure, never an exception',
    () async {
      final provider = SecureInstallationIdProvider(_ThrowingStorage());

      expect(
        await provider.getOrCreate(),
        const Err<String, AppFailure>(FileStorageFailure()),
      );
    },
  );
}
