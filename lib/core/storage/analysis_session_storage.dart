import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../error/app_failure.dart';
import '../result/result.dart';

/// Name of the folder holding per-analysis working files inside the app cache.
const String kAnalysisSessionsDirName = 'analysis_sessions';

/// Manages the temporary working files of an analysis session.
///
/// Layout (master plan §14):
/// ```
/// <app cache>/analysis_sessions/{sessionId}/{original,cropped,processed}.jpg
/// ```
abstract interface class AnalysisSessionStorage {
  /// Deletes leftover session folders and returns how many were removed.
  ///
  /// Called at launch. Nothing can be mid-analysis at that moment, so every
  /// remaining folder is by definition stale — a crash or a force-quit left it
  /// behind. Removing them honours the privacy rule that no unencrypted page
  /// image outlives its analysis (§50).
  Future<Result<int, AppFailure>> deleteStaleSessions();
}

/// Filesystem-backed [AnalysisSessionStorage].
final class FileAnalysisSessionStorage implements AnalysisSessionStorage {
  const FileAnalysisSessionStorage({
    Future<Directory> Function()? cacheDirectory,
  }) : _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory;

  final Future<Directory> Function() _cacheDirectory;

  @override
  Future<Result<int, AppFailure>> deleteStaleSessions() async {
    try {
      final cache = await _cacheDirectory();
      final sessions = Directory(p.join(cache.path, kAnalysisSessionsDirName));

      if (!await sessions.exists()) return const Ok(0);

      var deleted = 0;
      await for (final entity in sessions.list()) {
        await entity.delete(recursive: true);
        deleted++;
      }
      return Ok(deleted);
    } on Object {
      return const Err(FileStorageFailure());
    }
  }
}
