import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session_storage.dart';

void main() {
  late Directory cacheRoot;
  late FileAnalysisSessionStorage storage;

  setUp(() {
    cacheRoot = Directory.systemTemp.createTempSync('war2aty_cache_');
    storage = FileAnalysisSessionStorage(cacheDirectory: () async => cacheRoot);
  });

  tearDown(() {
    if (cacheRoot.existsSync()) cacheRoot.deleteSync(recursive: true);
  });

  Directory sessionsDir() =>
      Directory(p.join(cacheRoot.path, kAnalysisSessionsDirName));

  /// Creates `analysis_sessions/<id>/original.jpg` with some bytes.
  void seedSession(String id) {
    final dir = Directory(p.join(sessionsDir().path, id))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'original.jpg')).writeAsBytesSync([1, 2, 3]);
  }

  test('returns 0 when the sessions folder never existed', () async {
    expect(await storage.deleteStaleSessions(), const Ok<int, AppFailure>(0));
  });

  test('returns 0 when the sessions folder is empty', () async {
    sessionsDir().createSync(recursive: true);

    expect(await storage.deleteStaleSessions(), const Ok<int, AppFailure>(0));
  });

  test('deletes every leftover session folder and its files', () async {
    seedSession('session-a');
    seedSession('session-b');

    final result = await storage.deleteStaleSessions();

    expect(result, const Ok<int, AppFailure>(2));
    expect(sessionsDir().listSync(), isEmpty);
  });

  test('leaves no page image behind (privacy)', () async {
    seedSession('session-a');
    final leftover = File(
      p.join(sessionsDir().path, 'session-a', 'original.jpg'),
    );
    expect(leftover.existsSync(), isTrue);

    await storage.deleteStaleSessions();

    expect(leftover.existsSync(), isFalse);
  });

  test('does not touch unrelated cache contents', () async {
    final unrelated = File(p.join(cacheRoot.path, 'keep-me.txt'))
      ..writeAsStringSync('hi');
    seedSession('session-a');

    await storage.deleteStaleSessions();

    expect(unrelated.existsSync(), isTrue);
  });

  test('reports a classified failure instead of throwing', () async {
    final broken = FileAnalysisSessionStorage(
      cacheDirectory: () async => throw const FileSystemException('nope'),
    );

    expect(
      await broken.deleteStaleSessions(),
      const Err<int, AppFailure>(FileStorageFailure()),
    );
  });
}
