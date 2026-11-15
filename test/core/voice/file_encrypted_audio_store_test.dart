import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:war2aty/core/crypto/aes_gcm_file_encryptor.dart';
import 'package:war2aty/core/crypto/document_encryption_key_store.dart';
import 'package:war2aty/core/crypto/file_encryptor.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/file_encrypted_audio_store.dart';

import '../../support/fakes.dart';

void main() {
  late Directory tempDir;
  late _FakeFileEncryptor encryptor;
  late FileEncryptedAudioStore store;

  final sampleAudio = Uint8List.fromList(List.generate(256, (i) => i % 256));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('war2aty_audio_store_');
    encryptor = _FakeFileEncryptor();
    store = FileEncryptedAudioStore(
      encryptor,
      supportDirectory: () async => Directory(p.join(tempDir.path, 'support')),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('store', () {
    test(
      'writes encrypted bytes under voice_audio/{id}/audio.m4a.enc',
      () async {
        final outcome = await store.store(
          id: 'read-1',
          audioBytes: sampleAudio,
        );

        final path = (outcome as Ok<String, AppFailure>).value;
        expect(
          path,
          p.join(
            tempDir.path,
            'support',
            'voice_audio',
            'read-1',
            'audio.m4a.enc',
          ),
        );
        expect(await File(path).readAsBytes(), encryptor.reverse(sampleAudio));
      },
    );

    test('propagates encryption failure', () async {
      encryptor.fails = true;

      final outcome = await store.store(id: 'read-1', audioBytes: sampleAudio);

      expect(outcome, const Err<String, AppFailure>(FileEncryptionFailure()));
    });

    test('overwrites an existing file for the same id', () async {
      await store.store(id: 'read-1', audioBytes: sampleAudio);

      final different = Uint8List.fromList([10, 20, 30]);
      await store.store(id: 'read-1', audioBytes: different);

      final loaded = await store.load('read-1');
      expect((loaded as Ok<Uint8List, AppFailure>).value, [10, 20, 30]);
    });
  });

  group('load', () {
    test('reads back the bytes store wrote', () async {
      await store.store(id: 'read-1', audioBytes: sampleAudio);

      final outcome = await store.load('read-1');

      expect((outcome as Ok<Uint8List, AppFailure>).value, sampleAudio);
    });

    test('a missing id is a failure, not a crash', () async {
      final outcome = await store.load('never-saved');

      expect(outcome.failureOrNull, isA<FileStorageFailure>());
    });

    test('a truncated file yields FileEncryptionFailure', () async {
      final storeResult = await store.store(
        id: 'read-1',
        audioBytes: sampleAudio,
      );
      final path = (storeResult as Ok<String, AppFailure>).value;

      // Truncate the encrypted file to corrupt it.
      final file = File(path);
      final bytes = await file.readAsBytes();
      await file.writeAsBytes(bytes.sublist(0, bytes.length ~/ 2));

      // Use a real encryptor to detect the corruption.
      final real = AesGcmFileEncryptor(
        DocumentEncryptionKeyStore(FakeSecureStorage()),
      );
      final realStore = FileEncryptedAudioStore(
        real,
        supportDirectory: () async =>
            Directory(p.join(tempDir.path, 'support')),
      );

      // First store with the real encryptor.
      await realStore.store(id: 'read-2', audioBytes: sampleAudio);
      final realPath =
          (await realStore.store(id: 'read-2', audioBytes: sampleAudio)
                  as Ok<String, AppFailure>)
              .value;

      // Truncate the real encrypted file.
      final realFile = File(realPath);
      final realBytes = await realFile.readAsBytes();
      await realFile.writeAsBytes(realBytes.sublist(0, realBytes.length ~/ 2));

      final outcome = await realStore.load('read-2');

      expect(outcome.failureOrNull, isA<FileEncryptionFailure>());
    });

    test(
      'an encryptor that throws is classified, not left to escape',
      () async {
        await store.store(id: 'read-1', audioBytes: sampleAudio);
        encryptor.throwsOnDecrypt = true;

        final outcome = await store.load('read-1');

        expect(outcome.failureOrNull, isA<FileStorageFailure>());
      },
    );

    test('round-trips through the real AES-GCM encryptor', () async {
      final real = AesGcmFileEncryptor(
        DocumentEncryptionKeyStore(FakeSecureStorage()),
      );
      final realStore = FileEncryptedAudioStore(
        real,
        supportDirectory: () async =>
            Directory(p.join(tempDir.path, 'support')),
      );

      await realStore.store(id: 'read-1', audioBytes: sampleAudio);

      final outcome = await realStore.load('read-1');
      expect((outcome as Ok<Uint8List, AppFailure>).value, sampleAudio);
    });
  });

  group('exists', () {
    test('returns false for an id that was never stored', () async {
      expect(await store.exists('never-saved'), isFalse);
    });

    test('returns true after a successful store', () async {
      await store.store(id: 'read-1', audioBytes: sampleAudio);

      expect(await store.exists('read-1'), isTrue);
    });

    test('returns false after delete', () async {
      await store.store(id: 'read-1', audioBytes: sampleAudio);
      await store.delete('read-1');

      expect(await store.exists('read-1'), isFalse);
    });
  });

  group('delete', () {
    test("removes an audio's encrypted directory", () async {
      await store.store(id: 'read-1', audioBytes: sampleAudio);

      await store.delete('read-1');

      expect(
        await Directory(
          p.join(tempDir.path, 'support', 'voice_audio', 'read-1'),
        ).exists(),
        isFalse,
      );
    });

    test('is a quiet no-op when there is nothing to delete', () async {
      await store.delete('never-saved');
    });
  });

  group('deleteAll', () {
    test('removes the entire voice_audio directory', () async {
      await store.store(id: 'read-1', audioBytes: sampleAudio);
      await store.store(id: 'read-2', audioBytes: sampleAudio);

      await store.deleteAll();

      expect(
        await Directory(
          p.join(tempDir.path, 'support', 'voice_audio'),
        ).exists(),
        isFalse,
      );
    });

    test('is a quiet no-op when there is nothing to delete', () async {
      await store.deleteAll();
    });
  });
}

/// A [FileEncryptor] that reverses bytes instead of encrypting — deterministic
/// and fast, so the store's file handling can be tested without real crypto.
final class _FakeFileEncryptor implements FileEncryptor {
  bool fails = false;

  bool throwsOnDecrypt = false;

  Uint8List reverse(List<int> bytes) =>
      Uint8List.fromList(bytes.reversed.toList());

  @override
  Future<Result<Uint8List, AppFailure>> encrypt(Uint8List plaintext) async {
    if (fails) return const Err(FileEncryptionFailure());
    return Ok(reverse(plaintext));
  }

  @override
  Future<Result<Uint8List, AppFailure>> decrypt(Uint8List ciphertext) async {
    if (throwsOnDecrypt) throw const FormatException('unreadable ciphertext');
    if (fails) return const Err(FileEncryptionFailure());
    return Ok(reverse(ciphertext));
  }
}
