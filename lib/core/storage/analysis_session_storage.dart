import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../features/capture/domain/entities/captured_photo.dart';
import '../error/app_failure.dart';
import '../identity/installation_id_provider.dart';
import '../result/result.dart';
import 'analysis_session.dart';

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

  /// Creates a new session directory, copies the processed image into it, and
  /// returns the session token that F04 picks up for OCR + analysis.
  Future<Result<AnalysisSession, AppFailure>> createSession(
    CapturedPhoto photo,
  );
}

/// Filesystem-backed [AnalysisSessionStorage].
final class FileAnalysisSessionStorage implements AnalysisSessionStorage {
  FileAnalysisSessionStorage({
    Future<Directory> Function()? cacheDirectory,
    IdGenerator? idGenerator,
  }) : _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory,
       _generateId = idGenerator ?? (() => const Uuid().v4());

  final Future<Directory> Function() _cacheDirectory;
  final IdGenerator _generateId;

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

  @override
  Future<Result<AnalysisSession, AppFailure>> createSession(
    CapturedPhoto photo,
  ) async {
    try {
      final id = _generateId();
      final cache = await _cacheDirectory();
      final sessionDir = Directory(
        p.join(cache.path, kAnalysisSessionsDirName, id),
      );
      await sessionDir.create(recursive: true);

      final dest = p.join(sessionDir.path, 'processed.jpg');
      await File(photo.path).copy(dest);

      return Ok(AnalysisSession(id: id, imagePath: dest));
    } on Object {
      return const Err(FileStorageFailure());
    }
  }
}
