import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:war2aty/core/crypto/aes_gcm_file_encryptor.dart';
import 'package:war2aty/core/crypto/document_encryption_key_store.dart';
import 'package:war2aty/core/crypto/file_encryptor.dart';
import 'package:war2aty/core/documents/file_document_image_store.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

void main() {
  late Directory tempDir;
  late File source;
  late _FakeFileEncryptor encryptor;
  late FileDocumentImageStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('war2aty_image_store_');
    source = File(p.join(tempDir.path, 'processed.jpg'))
      ..writeAsBytesSync([1, 2, 3, 4, 5]);
    encryptor = _FakeFileEncryptor();
    store = FileDocumentImageStore(
      encryptor,
      supportDirectory: () async => Directory(p.join(tempDir.path, 'support')),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('encryptAndStore', () {
    test(
      'writes the encrypted bytes under documents/{id}/original.enc',
      () async {
        final outcome = await store.encryptAndStore(
          documentId: 'doc-1',
          sourcePath: source.path,
        );

        final path = (outcome as Ok<String, AppFailure>).value;
        expect(
          path,
          p.join(tempDir.path, 'support', 'documents', 'doc-1', 'original.enc'),
        );
        expect(
          await File(path).readAsBytes(),
          encryptor.reverse([1, 2, 3, 4, 5]),
        );
      },
    );

    test(
      'deletes the plaintext source once the encrypted copy is written',
      () async {
        await store.encryptAndStore(
          documentId: 'doc-1',
          sourcePath: source.path,
        );

        expect(await source.exists(), isFalse);
      },
    );

    test(
      'returns FileStorageFailure when the source file is missing',
      () async {
        final outcome = await store.encryptAndStore(
          documentId: 'doc-1',
          sourcePath: p.join(tempDir.path, 'missing.jpg'),
        );

        expect(outcome, const Err<String, AppFailure>(FileStorageFailure()));
      },
    );

    test('propagates the encryption failure and keeps the plaintext', () async {
      encryptor.fails = true;

      final outcome = await store.encryptAndStore(
        documentId: 'doc-1',
        sourcePath: source.path,
      );

      expect(outcome, const Err<String, AppFailure>(FileEncryptionFailure()));
      expect(await source.exists(), isTrue);
    });

    test('round-trips through the real AES-GCM encryptor', () async {
      final real = AesGcmFileEncryptor(
        DocumentEncryptionKeyStore(FakeSecureStorage()),
      );
      final realStore = FileDocumentImageStore(
        real,
        supportDirectory: () async =>
            Directory(p.join(tempDir.path, 'support')),
      );

      final outcome = await realStore.encryptAndStore(
        documentId: 'doc-1',
        sourcePath: source.path,
      );
      final path = (outcome as Ok<String, AppFailure>).value;
      final ciphertext = await File(path).readAsBytes();

      final decrypted = await real.decrypt(ciphertext);
      expect((decrypted as Ok<Uint8List, AppFailure>).value, [1, 2, 3, 4, 5]);
    });
  });

  group('delete', () {
    test("removes a document's encrypted directory", () async {
      await store.encryptAndStore(documentId: 'doc-1', sourcePath: source.path);

      await store.delete('doc-1');

      expect(
        await Directory(
          p.join(tempDir.path, 'support', 'documents', 'doc-1'),
        ).exists(),
        isFalse,
      );
    });

    test('is a quiet no-op when there is nothing to delete', () async {
      await store.delete('never-saved');
    });
  });
}

/// A [FileEncryptor] that reverses bytes instead of encrypting — deterministic
/// and fast, so the store's file handling can be tested without real crypto.
final class _FakeFileEncryptor implements FileEncryptor {
  bool fails = false;

  Uint8List reverse(List<int> bytes) =>
      Uint8List.fromList(bytes.reversed.toList());

  @override
  Future<Result<Uint8List, AppFailure>> encrypt(Uint8List plaintext) async {
    if (fails) return const Err(FileEncryptionFailure());
    return Ok(reverse(plaintext));
  }

  @override
  Future<Result<Uint8List, AppFailure>> decrypt(Uint8List ciphertext) async {
    if (fails) return const Err(FileEncryptionFailure());
    return Ok(reverse(ciphertext));
  }
}
