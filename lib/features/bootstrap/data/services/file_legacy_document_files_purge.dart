import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/documents/file_document_image_store.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/services/legacy_document_files_purge.dart';

final class FileLegacyDocumentFilesPurge implements LegacyDocumentFilesPurge {
  FileLegacyDocumentFilesPurge({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;

  @override
  Future<Result<void, AppFailure>> call() async {
    try {
      final support = await _supportDirectory();
      final dir = Directory(p.join(support.path, kDocumentImagesDirName));
      if (await dir.exists()) await dir.delete(recursive: true);
      return const Ok(null);
    } on Object {
      return const Err(FileStorageFailure());
    }
  }
}
