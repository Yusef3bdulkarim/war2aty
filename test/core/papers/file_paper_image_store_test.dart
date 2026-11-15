import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:war2aty/core/crypto/aes_gcm_file_encryptor.dart';
import 'package:war2aty/core/crypto/document_encryption_key_store.dart';
import 'package:war2aty/core/crypto/file_encryptor.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/file_paper_image_store.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

void main() {
  late Directory tempDir;
  late File source;
  late _FakeFileEncryptor encryptor;
  late FilePaperImageStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('war2aty_paper_image_');
    source = File(p.join(tempDir.path, 'processed.jpg'))
      ..writeAsBytesSync([1, 2, 3, 4, 5]);
    encryptor = _FakeFileEncryptor();
    store = FilePaperImageStore(
      encryptor,
      supportDirectory: () async => Directory(p.join(tempDir.path, 'support')),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('encryptAndStore', () {
    test(
      'writes the encrypted bytes under paper_images/{id}/image.enc',
      () async {
        final outcome = await store.encryptAndStore(
          paperId: 'paper-1',
          sourcePath: source.path,
        );

        final path = (outcome as Ok<String, AppFailure>).value;
        expect(
          path,
          p.join(
            tempDir.path,
            'support',
            'paper_images',
            'paper-1',
            'image.enc',
          ),
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
          paperId: 'paper-1',
          sourcePath: source.path,
        );

        expect(await source.exists(), isFalse);
      },
    );

    test(
      'returns FileStorageFailure when the source file is missing',
      () async {
        final outcome = await store.encryptAndStore(
          paperId: 'paper-1',
          sourcePath: p.join(tempDir.path, 'missing.jpg'),
        );

        expect(outcome, const Err<String, AppFailure>(FileStorageFailure()));
      },
    );

    test('propagates the encryption failure and keeps the plaintext', () async {
      encryptor.failsEncrypt = true;

      final outcome = await store.encryptAndStore(
        paperId: 'paper-1',
        sourcePath: source.path,
      );

      expect(outcome, const Err<String, AppFailure>(FileEncryptionFailure()));
      expect(await source.exists(), isTrue);
    });

    test('round-trips through the real AES-GCM encryptor', () async {
      final real = AesGcmFileEncryptor(
        DocumentEncryptionKeyStore(FakeSecureStorage()),
      );
      final realStore = FilePaperImageStore(
        real,
        supportDirectory: () async =>
            Directory(p.join(tempDir.path, 'support')),
      );

      final outcome = await realStore.encryptAndStore(
        paperId: 'paper-1',
        sourcePath: source.path,
      );
      final path = (outcome as Ok<String, AppFailure>).value;
      final ciphertext = await File(path).readAsBytes();

      final decrypted = await real.decrypt(ciphertext);
      expect((decrypted as Ok<Uint8List, AppFailure>).value, [1, 2, 3, 4, 5]);
    });
  });

  group('load', () {
    test('reads back the bytes encryptAndStore wrote', () async {
      await store.encryptAndStore(paperId: 'paper-1', sourcePath: source.path);

      final outcome = await store.load('paper-1');

      expect((outcome as Ok<Uint8List, AppFailure>).value, [1, 2, 3, 4, 5]);
    });

    test('a missing paper is a failure, not a crash', () async {
      final outcome = await store.load('never-saved');

      expect(outcome.failureOrNull, isA<FileStorageFailure>());
    });

    test(
      'a truncated file yields FileEncryptionFailure, not a crash',
      () async {
        final real = AesGcmFileEncryptor(
          DocumentEncryptionKeyStore(FakeSecureStorage()),
        );
        final realStore = FilePaperImageStore(
          real,
          supportDirectory: () async =>
              Directory(p.join(tempDir.path, 'support')),
        );
        await realStore.encryptAndStore(
          paperId: 'paper-1',
          sourcePath: source.path,
        );
        final path = p.join(
          tempDir.path,
          'support',
          'paper_images',
          'paper-1',
          'image.enc',
        );
        final truncated = (await File(path).readAsBytes()).sublist(0, 4);
        await File(path).writeAsBytes(truncated);

        final outcome = await realStore.load('paper-1');

        expect(
          outcome,
          const Err<Uint8List, AppFailure>(FileEncryptionFailure()),
        );
      },
    );

    test('a throwing encryptor is classified, not left to escape', () async {
      await store.encryptAndStore(paperId: 'paper-1', sourcePath: source.path);
      encryptor.throwsOnDecrypt = true;

      final outcome = await store.load('paper-1');

      expect(outcome.failureOrNull, isA<FileStorageFailure>());
    });
  });

  group('delete', () {
    test("removes a paper's encrypted directory", () async {
      await store.encryptAndStore(paperId: 'paper-1', sourcePath: source.path);

      await store.delete('paper-1');

      expect(
        await Directory(
          p.join(tempDir.path, 'support', 'paper_images', 'paper-1'),
        ).exists(),
        isFalse,
      );
    });

    test('is a quiet no-op when there is nothing to delete', () async {
      await store.delete('never-saved');
    });
  });

  group('deleteAll', () {
    test('removes every paper under paper_images', () async {
      await store.encryptAndStore(paperId: 'paper-1', sourcePath: source.path);

      await store.deleteAll();

      expect(
        await Directory(
          p.join(tempDir.path, 'support', 'paper_images'),
        ).exists(),
        isFalse,
      );
    });

    test('is a quiet no-op when there is nothing to delete', () async {
      await store.deleteAll();
    });
  });
}

final class _FakeFileEncryptor implements FileEncryptor {
  bool failsEncrypt = false;
  bool throwsOnDecrypt = false;

  Uint8List reverse(List<int> bytes) =>
      Uint8List.fromList(bytes.reversed.toList());

  @override
  Future<Result<Uint8List, AppFailure>> encrypt(Uint8List plaintext) async {
    if (failsEncrypt) return const Err(FileEncryptionFailure());
    return Ok(reverse(plaintext));
  }

  @override
  Future<Result<Uint8List, AppFailure>> decrypt(Uint8List ciphertext) async {
    if (throwsOnDecrypt) throw const FormatException('unreadable ciphertext');
    return Ok(reverse(ciphertext));
  }
}
