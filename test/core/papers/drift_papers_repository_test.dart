import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/database/app_database.dart';
import 'package:war2aty/core/database/daos/papers_dao.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/drift_papers_repository.dart';
import 'package:war2aty/core/papers/explain_outcome.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_image_store.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';
import 'package:war2aty/core/papers/saved_paper.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/voice/encrypted_audio_store.dart';
import 'package:war2aty/features/voice/domain/entities/spoken_card_span.dart';
import 'package:war2aty/features/voice/domain/entities/voice_engine.dart';
import 'package:war2aty/features/voice/domain/entities/voice_read_outcome.dart';

import '../../support/fakes.dart';

void main() {
  late AppDatabase db;
  late PapersDao dao;
  late _FakePaperImageStore images;
  late _FakeAudioStore audio;
  late DriftPapersRepository repository;

  setUp(() {
    db = memoryDatabase();
    dao = db.papersDao;
    images = _FakePaperImageStore();
    audio = _FakeAudioStore();
    repository = DriftPapersRepository(
      dao,
      images,
      audio,
      idGenerator: () => 'p1',
      clock: () => DateTime(2026, 11, 16, 9, 2),
    );
  });
  tearDown(() => db.close());

  group('insertPaper', () {
    test('returns the id it saved the paper under', () async {
      final outcome = await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      expect(outcome, const Ok<String, AppFailure>('p1'));
    });

    test('writes the row and its paragraphs', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      final bundle = await dao.paperById('p1');

      expect(bundle!.paper.title, 'فاتورة كهرباء');
      expect(bundle.paper.status, PaperStatus.success);
      expect(bundle.paragraphs.single.value, 'الفقرة الأولى.');
    });

    test('stamps savedAt with the clock it was given', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      final bundle = await dao.paperById('p1');

      expect(bundle!.paper.savedAt, DateTime(2026, 11, 16, 9, 2));
    });

    test('keeps photographedAt distinct from savedAt', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      final bundle = await dao.paperById('p1');

      expect(bundle!.paper.photographedAt, DateTime(2026, 11, 16, 9));
    });

    test(
      'has no audio yet — a fresh row starts with audioSaved false',
      () async {
        await repository.insertPaper(
          outcome: _outcome(),
          photographedAt: DateTime(2026, 11, 16, 9),
        );

        final bundle = await dao.paperById('p1');

        expect(bundle!.paper.audioSaved, isFalse);
        expect(bundle.paper.voiceEngine, isNull);
      },
    );

    test('writes an already-encrypted image path when given one', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
        encryptedImagePath: '/private/paper_images/p1/image.enc',
      );

      final bundle = await dao.paperById('p1');

      expect(
        bundle!.paper.encryptedImagePath,
        '/private/paper_images/p1/image.enc',
      );
    });

    test('does not touch the image or audio stores', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      expect(images.encryptCalls, isEmpty);
      expect(audio.storeCalls, isEmpty);
    });

    test('turns a database error into a LocalDatabaseFailure', () async {
      final failing = DriftPapersRepository(
        _ThrowingDao(db),
        images,
        audio,
        idGenerator: () => 'p1',
        clock: () => DateTime(2026, 11, 16, 9, 2),
      );

      final outcome = await failing.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      expect(outcome, const Err<String, AppFailure>(LocalDatabaseFailure()));
    });
  });

  group('recordReading', () {
    test(
      'writes the engine, duration, verified, audioSaved and spans',
      () async {
        await repository.insertPaper(
          outcome: _outcome(),
          photographedAt: DateTime(2026, 11, 16, 9),
        );

        final outcome = await repository.recordReading(
          id: 'p1',
          outcome: VoiceReadOutcome(
            engine: VoiceEngine.geminiLive,
            duration: const Duration(seconds: 75),
            verified: true,
            audioSaved: true,
            spans: const [
              SpokenCardSpan(
                segmentId: 'explain',
                start: Duration.zero,
                end: Duration(seconds: 4),
                exact: true,
              ),
            ],
          ),
        );

        expect(outcome, const Ok<void, AppFailure>(null));

        final bundle = await dao.paperById('p1');
        expect(bundle!.paper.voiceEngine, 'geminiLive');
        expect(bundle.paper.audioDurationMs, 75000);
        expect(bundle.paper.audioVerified, isTrue);
        expect(bundle.paper.audioSaved, isTrue);
        expect(bundle.spans.single.segmentId, 'explain');
      },
    );

    test('stores a device-TTS outcome with audioSaved false', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      await repository.recordReading(
        id: 'p1',
        outcome: VoiceReadOutcome(
          engine: VoiceEngine.deviceTts,
          duration: const Duration(seconds: 60),
          verified: true,
          audioSaved: false,
          spans: const [],
        ),
      );

      final bundle = await dao.paperById('p1');
      expect(bundle!.paper.voiceEngine, 'deviceTts');
      expect(bundle.paper.audioSaved, isFalse);
    });

    test('turns a database error into a LocalDatabaseFailure', () async {
      final failing = DriftPapersRepository(
        _ThrowingDao(db),
        images,
        audio,
        idGenerator: () => 'p1',
        clock: () => DateTime(2026, 11, 16, 9, 2),
      );

      final outcome = await failing.recordReading(
        id: 'p1',
        outcome: VoiceReadOutcome(
          engine: VoiceEngine.geminiLive,
          duration: const Duration(seconds: 1),
          verified: true,
          audioSaved: true,
          spans: const [],
        ),
      );

      expect(outcome, const Err<void, AppFailure>(LocalDatabaseFailure()));
    });
  });

  group('watchPapers', () {
    test('emits an empty list when nothing has been saved', () async {
      final result = await repository.watchPapers().first;

      expect((result as Ok<List<SavedPaper>, AppFailure>).value, isEmpty);
    });

    test('emits a paper as soon as it is written', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      final result = await repository.watchPapers().first;
      final papers = (result as Ok<List<SavedPaper>, AppFailure>).value;

      expect(papers, hasLength(1));
      expect(papers.single.explanation.title, 'فاتورة كهرباء');
    });
  });

  group('watchPaper', () {
    test('emits null for an id nothing was saved under', () async {
      final result = await repository.watchPaper('nope').first;

      expect((result as Ok<SavedPaper?, AppFailure>).value, isNull);
    });

    test('emits the paper as soon as it is written', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      final result = await repository.watchPaper('p1').first;
      final paper = (result as Ok<SavedPaper?, AppFailure>).value;

      expect(paper, isNotNull);
      expect(paper!.id, 'p1');
    });
  });

  group('deletePaper', () {
    test('removes the row, the encrypted image and the audio', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
        encryptedImagePath: '/private/paper_images/p1/image.enc',
      );

      final outcome = await repository.deletePaper('p1');

      expect(outcome, const Ok<void, AppFailure>(null));
      expect(await dao.paperById('p1'), isNull);
      expect(images.deletedIds, ['p1']);
      expect(audio.deletedIds, ['p1']);
    });
  });

  group('deleteAllPapers', () {
    test('wipes every row, every image and every audio file', () async {
      await repository.insertPaper(
        outcome: _outcome(),
        photographedAt: DateTime(2026, 11, 16, 9),
      );

      final outcome = await repository.deleteAllPapers();

      expect(outcome, const Ok<void, AppFailure>(null));
      expect(await dao.paperById('p1'), isNull);
      expect(images.deleteAllCalled, isTrue);
      expect(audio.deleteAllCalled, isTrue);
    });
  });
}

ExplainOutcome _outcome() => (
  explanation: PaperExplanation(
    title: 'فاتورة كهرباء',
    status: PaperStatus.success,
    paragraphs: const ['الفقرة الأولى.'],
    todo: const PaperTodo(required: true, text: 'روح لأقرب فرع'),
  ),
  sessionId: 'session-1',
  explainSchemaVersion: '1.0',
);

final class _ThrowingDao extends PapersDao {
  _ThrowingDao(super.db);

  @override
  Future<void> insertPaper(PaperWrite write) =>
      Future<void>.error(StateError('disk is on fire'));

  @override
  Future<void> recordReading({
    required String id,
    String? engine,
    required int? durationMs,
    required bool? verified,
    required bool audioSaved,
    List<PaperSpansCompanion> spans = const [],
  }) => Future<void>.error(StateError('disk is on fire'));
}

final class _FakePaperImageStore implements PaperImageStore {
  final List<String> encryptCalls = [];
  final List<String> deletedIds = [];
  bool deleteAllCalled = false;

  @override
  Future<Result<String, AppFailure>> encryptAndStore({
    required String paperId,
    required String sourcePath,
  }) async {
    encryptCalls.add(paperId);
    return Ok('/private/paper_images/$paperId/image.enc');
  }

  @override
  Future<Result<Uint8List, AppFailure>> load(String paperId) async =>
      const Err(FileStorageFailure());

  @override
  Future<void> delete(String paperId) async => deletedIds.add(paperId);

  @override
  Future<void> deleteAll() async => deleteAllCalled = true;
}

final class _FakeAudioStore implements EncryptedAudioStore {
  final List<String> storeCalls = [];
  final List<String> deletedIds = [];
  bool deleteAllCalled = false;

  @override
  Future<Result<String, AppFailure>> store({
    required String id,
    required Uint8List audioBytes,
  }) async {
    storeCalls.add(id);
    return Ok('voice_audio/$id');
  }

  @override
  Future<Result<Uint8List, AppFailure>> load(String id) async =>
      const Err(FileStorageFailure());

  @override
  Future<void> delete(String id) async => deletedIds.add(id);

  @override
  Future<void> deleteAll() async => deleteAllCalled = true;

  @override
  Future<bool> exists(String id) async => false;
}
