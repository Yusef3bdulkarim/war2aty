import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../crypto/file_encryptor.dart';
import '../error/app_failure.dart';
import '../result/result.dart';
import 'encrypted_audio_store.dart';

/// Name of the folder holding every stored voice audio's encrypted file,
/// inside the app's private directory.
const String kVoiceAudioDirName = 'voice_audio';

/// [EncryptedAudioStore] backed by `dart:io` and [FileEncryptor].
///
/// Mirrors [FileDocumentImageStore] in shape, with two differences:
///
/// 1. **Input is bytes, not a file path.** The encoder returns a `Uint8List`
///    (T12's `finish()`) and no plaintext file is ever created — the bytes go
///    straight into the encryptor, so there is no window where a readable
///    recording of someone's paper sits on disk (CLAUDE.md §7).
///
/// 2. **The file is `audio.m4a.enc`**, not `original.enc`, because there is
///    no `original` — the audio was never a user-visible file.
final class FileEncryptedAudioStore implements EncryptedAudioStore {
  FileEncryptedAudioStore(
    this._encryptor, {
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final FileEncryptor _encryptor;
  final Future<Directory> Function() _supportDirectory;

  @override
  Future<Result<String, AppFailure>> store({
    required String id,
    required Uint8List audioBytes,
  }) async {
    final encrypted = await _encryptor.encrypt(audioBytes);
    return encrypted.when(
      ok: (ciphertext) => _write(id, ciphertext),
      err: (failure) async => Err(failure),
    );
  }

  @override
  Future<Result<Uint8List, AppFailure>> load(String id) async {
    try {
      final file = await _fileFor(id);
      if (!await file.exists()) {
        return const Err(FileStorageFailure());
      }
      final ciphertext = await file.readAsBytes();
      // Awaited inside the `try` on purpose: returning the future unawaited
      // would hand it to the caller before it completes, so the catch below
      // could not convert a throwing encryptor into an `AppFailure`.
      final result = await _encryptor.decrypt(ciphertext);
      return result;
    } on Object {
      return const Err(FileStorageFailure());
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final support = await _supportDirectory();
      final dir = Directory(p.join(support.path, kVoiceAudioDirName, id));
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      // Best-effort: a stray encrypted file left behind is not worth
      // surfacing to the user over a delete that otherwise succeeded.
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final support = await _supportDirectory();
      final dir = Directory(p.join(support.path, kVoiceAudioDirName));
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      // Best-effort, same reasoning as [delete].
    }
  }

  @override
  Future<bool> exists(String id) async {
    try {
      final file = await _fileFor(id);
      return await file.exists();
    } on Object {
      return false;
    }
  }

  Future<File> _fileFor(String id) async {
    final support = await _supportDirectory();
    return File(p.join(support.path, kVoiceAudioDirName, id, 'audio.m4a.enc'));
  }

  Future<Result<String, AppFailure>> _write(
    String id,
    Uint8List ciphertext,
  ) async {
    try {
      final support = await _supportDirectory();
      final dir = Directory(p.join(support.path, kVoiceAudioDirName, id));
      await dir.create(recursive: true);
      final destination = p.join(dir.path, 'audio.m4a.enc');
      await File(destination).writeAsBytes(ciphertext, flush: true);
      return Ok(destination);
    } on Object {
      return const Err(FileStorageFailure());
    }
  }
}
