import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/crypto/document_encryption_key_store.dart';
import 'package:war2aty/core/storage/secure_storage_service.dart';

import '../../support/fakes.dart';

void main() {
  late FakeSecureStorage storage;
  late DocumentEncryptionKeyStore keys;

  setUp(() {
    storage = FakeSecureStorage();
    keys = DocumentEncryptionKeyStore(storage);
  });

  test('generates and persists a key on first use', () async {
    expect(await storage.read(SecureStorageKeys.documentEncryptionKey), isNull);

    final key = await keys.keyOrCreate();

    expect(await key.extractBytes(), hasLength(32));
    expect(
      await storage.read(SecureStorageKeys.documentEncryptionKey),
      isNotNull,
    );
  });

  test('reuses the same key on later calls', () async {
    final first = await keys.keyOrCreate();
    final second = await keys.keyOrCreate();

    expect(await second.extractBytes(), await first.extractBytes());
  });

  test('reads a key back that another instance already stored', () async {
    final original = await keys.keyOrCreate();

    final reopened = DocumentEncryptionKeyStore(storage);
    final reread = await reopened.keyOrCreate();

    expect(await reread.extractBytes(), await original.extractBytes());
  });

  test('stores the key as base64, not raw bytes', () async {
    await keys.keyOrCreate();

    final stored = await storage.read(SecureStorageKeys.documentEncryptionKey);
    expect(() => base64Decode(stored!), returnsNormally);
  });

  test('uses the injected generator instead of a random key', () async {
    final fixed = SecretKey(List.filled(32, 7));
    final withFixedGenerator = DocumentEncryptionKeyStore(
      storage,
      generator: () async => fixed,
    );

    final key = await withFixedGenerator.keyOrCreate();

    expect(await key.extractBytes(), List.filled(32, 7));
  });
}
