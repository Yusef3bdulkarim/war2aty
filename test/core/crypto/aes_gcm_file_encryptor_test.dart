import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/crypto/aes_gcm_file_encryptor.dart';
import 'package:war2aty/core/crypto/document_encryption_key_store.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';

import '../../support/fakes.dart';

void main() {
  late DocumentEncryptionKeyStore keys;
  late AesGcmFileEncryptor encryptor;

  setUp(() {
    keys = DocumentEncryptionKeyStore(FakeSecureStorage());
    encryptor = AesGcmFileEncryptor(keys);
  });

  Uint8List bytes(String text) => Uint8List.fromList(text.codeUnits);

  test('decrypts what it encrypted', () async {
    final plaintext = bytes('صورة الفاتورة كبيانات وهمية');

    final encrypted = await encryptor.encrypt(plaintext);
    final ciphertext = (encrypted as Ok<Uint8List, AppFailure>).value;
    final decrypted = await encryptor.decrypt(ciphertext);

    expect((decrypted as Ok<Uint8List, AppFailure>).value, plaintext);
  });

  test('round-trips empty bytes', () async {
    final encrypted = await encryptor.encrypt(Uint8List(0));
    final ciphertext = (encrypted as Ok<Uint8List, AppFailure>).value;

    final decrypted = await encryptor.decrypt(ciphertext);
    expect((decrypted as Ok<Uint8List, AppFailure>).value, isEmpty);
  });

  test('never returns the plaintext bytes verbatim', () async {
    final plaintext = bytes('نفس المحتوى في كل مرة');

    final encrypted = await encryptor.encrypt(plaintext);
    final ciphertext = (encrypted as Ok<Uint8List, AppFailure>).value;

    expect(ciphertext, isNot(plaintext));
  });

  test(
    'uses a different nonce — and so different output — each time',
    () async {
      final plaintext = bytes('نفس المحتوى في كل مرة');

      final first =
          ((await encryptor.encrypt(plaintext)) as Ok<Uint8List, AppFailure>)
              .value;
      final second =
          ((await encryptor.encrypt(plaintext)) as Ok<Uint8List, AppFailure>)
              .value;

      expect(first, isNot(second));
    },
  );

  test('rejects ciphertext whose tag was tampered with', () async {
    final encrypted = await encryptor.encrypt(bytes('مبلغ الفاتورة 750 جنيه'));
    final ciphertext = (encrypted as Ok<Uint8List, AppFailure>).value;

    final tampered = Uint8List.fromList(ciphertext);
    tampered[tampered.length - 1] ^= 0xFF; // flips a bit in the GCM tag

    expect(
      await encryptor.decrypt(tampered),
      const Err<Uint8List, AppFailure>(FileEncryptionFailure()),
    );
  });

  test('rejects ciphertext with a flipped byte in the body', () async {
    final encrypted = await encryptor.encrypt(bytes('مبلغ الفاتورة 750 جنيه'));
    final ciphertext = (encrypted as Ok<Uint8List, AppFailure>).value;

    final tampered = Uint8List.fromList(ciphertext);
    tampered[12] ^=
        0xFF; // first byte of the ciphertext body, just past the nonce

    expect(
      await encryptor.decrypt(tampered),
      const Err<Uint8List, AppFailure>(FileEncryptionFailure()),
    );
  });

  test('rejects data too short to be a real file', () async {
    expect(
      await encryptor.decrypt(Uint8List.fromList([1, 2, 3])),
      const Err<Uint8List, AppFailure>(FileEncryptionFailure()),
    );
  });

  test('fails to decrypt under the wrong key', () async {
    final encrypted = await encryptor.encrypt(bytes('نص سري'));
    final ciphertext = (encrypted as Ok<Uint8List, AppFailure>).value;

    final otherKeys = DocumentEncryptionKeyStore(
      FakeSecureStorage(),
      generator: () async => SecretKey(List.filled(32, 9)),
    );
    final wrongEncryptor = AesGcmFileEncryptor(otherKeys);

    expect(
      await wrongEncryptor.decrypt(ciphertext),
      const Err<Uint8List, AppFailure>(FileEncryptionFailure()),
    );
  });
}
