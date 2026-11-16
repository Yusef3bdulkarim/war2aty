import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:war2aty/core/documents/file_document_image_store.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/file_paper_image_store.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/file_encrypted_audio_store.dart';
import 'package:war2aty/features/bootstrap/data/services/file_legacy_document_files_purge.dart';

void main() {
  late Directory supportRoot;
  late FileLegacyDocumentFilesPurge purge;

  setUp(() {
    supportRoot = Directory.systemTemp.createTempSync('war2aty_support_');
    purge = FileLegacyDocumentFilesPurge(
      supportDirectory: () async => supportRoot,
    );
  });

  tearDown(() {
    if (supportRoot.existsSync()) supportRoot.deleteSync(recursive: true);
  });

  Directory legacyDir() =>
      Directory(p.join(supportRoot.path, kDocumentImagesDirName));

  void seedLegacyDocument(String id) {
    final dir = Directory(p.join(legacyDir().path, id))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'original.enc')).writeAsBytesSync([1, 2, 3]);
  }

  test('removes a seeded legacy documents directory', () async {
    seedLegacyDocument('doc-a');
    seedLegacyDocument('doc-b');

    final result = await purge();

    expect(result, const Ok<void, AppFailure>(null));
    expect(legacyDir().existsSync(), isFalse);
  });

  test('is a quiet no-op when the directory never existed', () async {
    final result = await purge();

    expect(result, const Ok<void, AppFailure>(null));
  });

  test('is a quiet no-op the second time, once already purged', () async {
    seedLegacyDocument('doc-a');

    await purge();
    final second = await purge();

    expect(second, const Ok<void, AppFailure>(null));
    expect(legacyDir().existsSync(), isFalse);
  });

  test('never touches paper_images or voice_audio', () async {
    seedLegacyDocument('doc-a');
    final paperImages = Directory(p.join(supportRoot.path, kPaperImagesDirName))
      ..createSync(recursive: true);
    final voiceAudio = Directory(p.join(supportRoot.path, kVoiceAudioDirName))
      ..createSync(recursive: true);
    File(
      p.join(paperImages.path, 'paper-a', 'image.enc'),
    ).createSync(recursive: true);
    File(
      p.join(voiceAudio.path, 'paper-a', 'audio.m4a.enc'),
    ).createSync(recursive: true);

    await purge();

    expect(paperImages.existsSync(), isTrue);
    expect(voiceAudio.existsSync(), isTrue);
    expect(
      File(p.join(paperImages.path, 'paper-a', 'image.enc')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(voiceAudio.path, 'paper-a', 'audio.m4a.enc')).existsSync(),
      isTrue,
    );
  });

  test('reports a classified failure instead of throwing', () async {
    final broken = FileLegacyDocumentFilesPurge(
      supportDirectory: () async => throw const FileSystemException('nope'),
    );

    expect(await broken(), const Err<void, AppFailure>(FileStorageFailure()));
  });
}
