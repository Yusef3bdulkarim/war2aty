import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../features/voice/domain/entities/voice_read_outcome.dart';
import '../database/daos/papers_dao.dart';
import '../error/app_failure.dart';
import '../identity/installation_id_provider.dart';
import '../result/result.dart';
import '../voice/encrypted_audio_store.dart';
import 'explain_outcome.dart';
import 'paper_image_store.dart';
import 'paper_read_mapper.dart';
import 'paper_write_mapper.dart';
import 'papers_repository.dart';
import 'saved_paper.dart';

final class DriftPapersRepository implements PapersRepository {
  DriftPapersRepository(
    this._dao,
    this._images,
    this._audio, {
    IdGenerator? idGenerator,
    DateTime Function()? clock,
  }) : _generateId = idGenerator ?? (() => const Uuid().v4()),
       _now = clock ?? DateTime.now;

  final PapersDao _dao;
  final PaperImageStore _images;
  final EncryptedAudioStore _audio;
  final IdGenerator _generateId;
  final DateTime Function() _now;

  @override
  Stream<Result<List<SavedPaper>, AppFailure>> watchPapers() {
    return _dao
        .watchPapers()
        .map<Result<List<SavedPaper>, AppFailure>>(
          (bundles) => Ok(bundles.map(savedPaperOf).toList()),
        )
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.add(const Err(LocalDatabaseFailure())),
          ),
        );
  }

  @override
  Stream<Result<SavedPaper?, AppFailure>> watchPaper(String id) {
    return _dao
        .watchPaper(id)
        .map<Result<SavedPaper?, AppFailure>>(
          (bundle) => Ok(bundle == null ? null : savedPaperOf(bundle)),
        )
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) =>
                sink.add(const Err(LocalDatabaseFailure())),
          ),
        );
  }

  @override
  Future<Result<String, AppFailure>> insertPaper({
    String? id,
    required ExplainOutcome outcome,
    required DateTime photographedAt,
    String? encryptedImagePath,
  }) async {
    final paperId = id ?? _generateId();

    try {
      await _dao.insertPaper(
        paperWriteOf(
          id: paperId,
          outcome: outcome,
          photographedAt: photographedAt,
          savedAt: _now(),
          encryptedImagePath: encryptedImagePath,
        ),
      );
      return Ok(paperId);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> recordReading({
    required String id,
    required VoiceReadOutcome outcome,
  }) async {
    try {
      await _dao.recordReading(
        id: id,
        engine: outcome.engine.name,
        durationMs: outcome.duration.inMilliseconds,
        verified: outcome.verified,
        audioSaved: outcome.audioSaved,
        spans: paperSpansOf(id, outcome.spans),
      );
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> deletePaper(String id) async {
    try {
      await _images.delete(id);
      await _audio.delete(id);
      await _dao.deletePaper(id);
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }

  @override
  Future<Result<void, AppFailure>> deleteAllPapers() async {
    try {
      await _images.deleteAll();
      await _audio.deleteAll();
      await _dao.deleteAllPapers();
      return const Ok(null);
    } on Object {
      return const Err(LocalDatabaseFailure());
    }
  }
}
