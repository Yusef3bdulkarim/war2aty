import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../crypto/file_encryptor.dart';
import '../error/app_failure.dart';
import '../result/result.dart';
import 'paper_image_store.dart';

const String kPaperImagesDirName = 'paper_images';

final class FilePaperImageStore implements PaperImageStore {
  FilePaperImageStore(
    this._encryptor, {
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final FileEncryptor _encryptor;
  final Future<Directory> Function() _supportDirectory;

  @override
  Future<Result<String, AppFailure>> encryptAndStore({
    required String paperId,
    required String sourcePath,
  }) async {
    final Uint8List plaintext;
    try {
      plaintext = await File(sourcePath).readAsBytes();
    } on Object {
      return const Err(FileStorageFailure());
    }

    final encrypted = await _encryptor.encrypt(plaintext);
    return encrypted.when(
      ok: (ciphertext) => _write(paperId, sourcePath, ciphertext),
      err: (failure) async => Err(failure),
    );
  }

  @override
  Future<Result<Uint8List, AppFailure>> load(String paperId) async {
    try {
      final support = await _supportDirectory();
      final file = File(
        p.join(support.path, kPaperImagesDirName, paperId, 'image.enc'),
      );
      if (!await file.exists()) {
        return const Err(FileStorageFailure());
      }
      final ciphertext = await file.readAsBytes();
      return await _encryptor.decrypt(ciphertext);
    } on Object {
      return const Err(FileStorageFailure());
    }
  }

  @override
  Future<void> delete(String paperId) async {
    try {
      final support = await _supportDirectory();
      final dir = Directory(p.join(support.path, kPaperImagesDirName, paperId));
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      return;
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      final support = await _supportDirectory();
      final dir = Directory(p.join(support.path, kPaperImagesDirName));
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      return;
    }
  }

  Future<Result<String, AppFailure>> _write(
    String paperId,
    String sourcePath,
    Uint8List ciphertext,
  ) async {
    try {
      final support = await _supportDirectory();
      final dir = Directory(p.join(support.path, kPaperImagesDirName, paperId));
      await dir.create(recursive: true);
      final destination = p.join(dir.path, 'image.enc');
      await File(destination).writeAsBytes(ciphertext, flush: true);
      await _deleteQuietly(sourcePath);
      return Ok(destination);
    } on Object {
      return const Err(FileStorageFailure());
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on Object {
      return;
    }
  }
}
