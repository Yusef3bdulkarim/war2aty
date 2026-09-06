import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../crypto/file_encryptor.dart';
import '../error/app_failure.dart';
import '../result/result.dart';
import 'document_image_store.dart';

/// Name of the folder holding every saved document's encrypted picture,
/// inside the app's private directory (master plan §14).
const String kDocumentImagesDirName = 'documents';

/// [DocumentImageStore] backed by `dart:io` and [FileEncryptor].
final class FileDocumentImageStore implements DocumentImageStore {
  FileDocumentImageStore(
    this._encryptor, {
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final FileEncryptor _encryptor;
  final Future<Directory> Function() _supportDirectory;

  @override
  Future<Result<String, AppFailure>> encryptAndStore({
    required String documentId,
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
      ok: (ciphertext) => _write(documentId, sourcePath, ciphertext),
      err: (failure) async => Err(failure),
    );
  }

  @override
  Future<Result<Uint8List, AppFailure>> load(String documentId) async {
    try {
      final support = await _supportDirectory();
      final file = File(
        p.join(
          support.path,
          kDocumentImagesDirName,
          documentId,
          'original.enc',
        ),
      );
      if (!await file.exists()) {
        return const Err(FileStorageFailure());
      }
      final ciphertext = await file.readAsBytes();
      return _encryptor.decrypt(ciphertext);
    } on Object {
      return const Err(FileStorageFailure());
    }
  }

  @override
  Future<void> delete(String documentId) async {
    try {
      final support = await _supportDirectory();
      final dir = Directory(
        p.join(support.path, kDocumentImagesDirName, documentId),
      );
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
      final dir = Directory(p.join(support.path, kDocumentImagesDirName));
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      // Best-effort, same reasoning as [delete].
    }
  }

  Future<Result<String, AppFailure>> _write(
    String documentId,
    String sourcePath,
    Uint8List ciphertext,
  ) async {
    try {
      final support = await _supportDirectory();
      final dir = Directory(
        p.join(support.path, kDocumentImagesDirName, documentId),
      );
      await dir.create(recursive: true);
      final destination = p.join(dir.path, 'original.enc');
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
      // Best-effort, matching IOCaptureFileCleanup: a stale temp file is
      // cleaned up later by the session's own cleanup pass if this fails.
    }
  }
}
