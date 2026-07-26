import 'dart:io';

import '../../domain/services/capture_file_cleanup.dart';

/// [CaptureFileCleanup] backed by [dart:io].
final class IOCaptureFileCleanup implements CaptureFileCleanup {
  const IOCaptureFileCleanup();

  @override
  Future<void> deleteFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on Object {
        // Best-effort: a failure to delete a temp file must never surface.
      }
    }
  }
}
