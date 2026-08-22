import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/storage/analysis_session_storage.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';

void main() {
  late Directory cacheRoot;
  late FileAnalysisSessionStorage storage;

  setUp(() {
    cacheRoot = Directory.systemTemp.createTempSync('war2aty_cache_');
    storage = FileAnalysisSessionStorage(
      cacheDirectory: () async => cacheRoot,
      idGenerator: () => 'fixed-uuid',
    );
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

  group('createSession', () {
    late File sourceImage;

    setUp(() {
      sourceImage = File(p.join(cacheRoot.path, 'source.jpg'))
        ..writeAsBytesSync([10, 20, 30, 40]);
    });

    test('creates the session directory and copies the image', () async {
      final result = await storage.createSession(
        CapturedPhoto(sourceImage.path),
      );

      expect(result.isOk, isTrue);
      final session = result.valueOrNull!;
      expect(session.id, 'fixed-uuid');

      final copied = File(session.imagePath);
      expect(copied.existsSync(), isTrue);
      expect(copied.readAsBytesSync(), [10, 20, 30, 40]);
    });

    test(
      'places the image under analysis_sessions/{id}/processed.jpg',
      () async {
        final result = await storage.createSession(
          CapturedPhoto(sourceImage.path),
        );

        final session = result.valueOrNull!;
        final expected = p.join(
          cacheRoot.path,
          kAnalysisSessionsDirName,
          'fixed-uuid',
          'processed.jpg',
        );
        expect(session.imagePath, expected);
      },
    );

    test('returns the session id from the id generator', () async {
      final custom = FileAnalysisSessionStorage(
        cacheDirectory: () async => cacheRoot,
        idGenerator: () => 'custom-id-42',
      );

      final result = await custom.createSession(
        CapturedPhoto(sourceImage.path),
      );

      expect(result.valueOrNull!.id, 'custom-id-42');
    });

    test('reports a classified failure when the source is missing', () async {
      final result = await storage.createSession(
        const CapturedPhoto('/nonexistent/photo.jpg'),
      );

      expect(
        result,
        const Err<AnalysisSession, AppFailure>(FileStorageFailure()),
      );
    });

    test('reports a classified failure when cache is unreachable', () async {
      final broken = FileAnalysisSessionStorage(
        cacheDirectory: () async => throw const FileSystemException('nope'),
      );

      final result = await broken.createSession(
        CapturedPhoto(sourceImage.path),
      );

      expect(
        result,
        const Err<AnalysisSession, AppFailure>(FileStorageFailure()),
      );
    });
  });

  group('deleteSession', () {
    test('deletes the session directory and everything inside it', () async {
      seedSession('session-a');
      final resized = File(
        p.join(sessionsDir().path, 'session-a', 'ocr_resized_1.jpg'),
      )..writeAsBytesSync([9]);

      await storage.deleteSession('session-a');

      expect(
        Directory(p.join(sessionsDir().path, 'session-a')).existsSync(),
        isFalse,
      );
      expect(resized.existsSync(), isFalse);
    });

    test('does not touch other sessions', () async {
      seedSession('session-a');
      seedSession('session-b');

      await storage.deleteSession('session-a');

      expect(
        Directory(p.join(sessionsDir().path, 'session-b')).existsSync(),
        isTrue,
      );
    });

    test('is a no-op when the session does not exist', () async {
      sessionsDir().createSync(recursive: true);

      // Must not throw.
      await storage.deleteSession('never-existed');
    });

    test('is a no-op when the sessions folder never existed', () async {
      // Must not throw.
      await storage.deleteSession('anything');
    });

    test('swallows a filesystem failure instead of throwing', () async {
      final broken = FileAnalysisSessionStorage(
        cacheDirectory: () async => throw const FileSystemException('nope'),
      );

      // Must not throw.
      await broken.deleteSession('session-a');
    });

    test(
      'refuses a path-traversal id instead of deleting outside the sessions '
      'folder (defense in depth — id is never network input today)',
      () async {
        seedSession('session-a');
        final outside = File(p.join(cacheRoot.path, 'keep-me.txt'))
          ..writeAsStringSync('hi');

        await storage.deleteSession('../keep-me.txt');
        await storage.deleteSession('..');
        await storage.deleteSession('');

        expect(outside.existsSync(), isTrue);
        expect(
          Directory(p.join(sessionsDir().path, 'session-a')).existsSync(),
          isTrue,
        );
      },
    );
  });
}
