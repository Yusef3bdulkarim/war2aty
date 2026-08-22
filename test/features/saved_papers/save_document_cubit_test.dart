import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_category.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/documents_repository.dart';
import 'package:war2aty/core/documents/recent_document.dart';
import 'package:war2aty/core/documents/saved_document.dart';
import 'package:war2aty/core/documents/usecases/save_document.dart';
import 'package:war2aty/core/documents/usecases/save_document_with_image.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/usecases/cleanup_analysis_session.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_state.dart';

import '../../support/fakes.dart';

const _sessionId = 'session-1';

void main() {
  late _FakeRepository repository;
  late FakeAnalysisSessionStorage sessionStorage;
  late SaveDocumentCubit cubit;

  setUp(() {
    repository = _FakeRepository();
    sessionStorage = FakeAnalysisSessionStorage(sessionId: _sessionId);
    cubit = SaveDocumentCubit(
      SaveDocument(repository),
      SaveDocumentWithImage(repository),
      sessionId: _sessionId,
      cleanupSession: CleanupAnalysisSession(sessionStorage),
    );
  });
  tearDown(() => cubit.close());

  test('starts idle', () {
    expect(cubit.state, const SaveDocumentIdle());
    expect(cubit.isSaved, isFalse);
  });

  test('goes saving then saved, carrying the new id', () async {
    final states = <SaveDocumentState>[];
    final sub = cubit.stream.listen(states.add);

    await cubit.save(analysis: _analysis(), extractedText: 'نص');
    await pumpEventQueue();
    await sub.cancel();

    expect(states, const [
      SaveDocumentSaving(),
      SaveDocumentSaved('doc-1', DocumentStorageMode.resultOnly),
    ]);
    expect(cubit.isSaved, isTrue);
  });

  test('passes the analysis and its text through to the repository', () async {
    await cubit.save(analysis: _analysis(), extractedText: 'شركة الكهرباء');

    expect(repository.lastAnalysis?.title, 'فاتورة كهرباء');
    expect(repository.lastText, 'شركة الكهرباء');
  });

  test('carries the failure when the write fails', () async {
    repository.outcome = const Err(LocalDatabaseFailure());

    await cubit.save(analysis: _analysis(), extractedText: 'نص');

    expect(cubit.state, const SaveDocumentFailed(LocalDatabaseFailure()));
    expect(cubit.isSaved, isFalse);
  });

  test('does not save the same paper twice', () async {
    await cubit.save(analysis: _analysis(), extractedText: 'نص');
    await cubit.save(analysis: _analysis(), extractedText: 'نص');

    expect(repository.saveCount, 1);
  });

  test('lets the user retry after a failure', () async {
    repository.outcome = const Err(LocalDatabaseFailure());
    await cubit.save(analysis: _analysis(), extractedText: 'نص');

    repository.outcome = const Ok('doc-1');
    await cubit.save(analysis: _analysis(), extractedText: 'نص');

    expect(
      cubit.state,
      const SaveDocumentSaved('doc-1', DocumentStorageMode.resultOnly),
    );
    expect(repository.saveCount, 2);
  });

  test('emits nothing once closed', () async {
    await cubit.close();

    await cubit.save(analysis: _analysis(), extractedText: 'نص');

    expect(cubit.state, const SaveDocumentIdle());
  });

  group('with an image path', () {
    test(
      'goes through saveWithImage instead, carrying withImage mode',
      () async {
        await cubit.save(
          analysis: _analysis(),
          extractedText: 'نص',
          imagePath: '/cache/analysis_sessions/s1/processed.jpg',
        );

        expect(
          cubit.state,
          const SaveDocumentSaved('doc-1', DocumentStorageMode.withImage),
        );
        expect(repository.saveCount, 0);
        expect(repository.withImageCount, 1);
        expect(
          repository.lastImagePath,
          '/cache/analysis_sessions/s1/processed.jpg',
        );
      },
    );

    test('carries the failure when the encrypted write fails', () async {
      repository.withImageOutcome = const Err(FileEncryptionFailure());

      await cubit.save(
        analysis: _analysis(),
        extractedText: 'نص',
        imagePath: '/cache/analysis_sessions/s1/processed.jpg',
      );

      expect(cubit.state, const SaveDocumentFailed(FileEncryptionFailure()));
    });
  });

  // F12-T06: no temp copy of the session's working files (the processed
  // photo, or the offline OCR pass's resize sibling) should outlive the
  // flow that created it — see `SaveDocumentCubit`'s own doc comment.
  group('session cleanup (F12-T06)', () {
    test('cleans up the session after a result-only save', () async {
      await cubit.save(analysis: _analysis(), extractedText: 'نص');

      expect(sessionStorage.deletedSessionIds, [_sessionId]);
    });

    test(
      'cleans up the session after a with-image save that succeeded',
      () async {
        await cubit.save(
          analysis: _analysis(),
          extractedText: 'نص',
          imagePath: '/cache/analysis_sessions/$_sessionId/processed.jpg',
        );

        expect(sessionStorage.deletedSessionIds, [_sessionId]);
      },
    );

    test(
      'cleans up the session even when the with-image save failed',
      () async {
        repository.withImageOutcome = const Err(FileEncryptionFailure());

        await cubit.save(
          analysis: _analysis(),
          extractedText: 'نص',
          imagePath: '/cache/analysis_sessions/$_sessionId/processed.jpg',
        );

        expect(sessionStorage.deletedSessionIds, [_sessionId]);
      },
    );

    test(
      'close() cleans up the session when no save was ever attempted',
      () async {
        await cubit.close();

        expect(sessionStorage.deletedSessionIds, [_sessionId]);
      },
    );

    test('close() does not clean up while a save is genuinely in flight — that '
        'would race its still-in-flight read of the session image', () async {
      repository.gate = Completer<void>();
      final pending = cubit.save(
        analysis: _analysis(),
        extractedText: 'نص',
        imagePath: '/cache/analysis_sessions/$_sessionId/processed.jpg',
      );

      await cubit.close();

      expect(sessionStorage.deletedSessionIds, isEmpty);

      // The in-flight save's own cleanup still runs once it resolves,
      // even though the cubit is already closed by then.
      repository.gate!.complete();
      await pending;
      expect(sessionStorage.deletedSessionIds, [_sessionId]);
    });

    test('close() after a completed save is a harmless no-op', () async {
      await cubit.save(analysis: _analysis(), extractedText: 'نص');
      sessionStorage.deletedSessionIds.clear();

      await cubit.close();

      // Runs again — deleting an already-gone session directory is
      // idempotent by design (`AnalysisSessionStorage.deleteSession`'s own
      // doc comment), so this is safe, not a bug to guard against.
      expect(sessionStorage.deletedSessionIds, [_sessionId]);
    });
  });
}

final class _FakeRepository implements DocumentsRepository {
  Result<String, AppFailure> outcome = const Ok('doc-1');
  Result<String, AppFailure> withImageOutcome = const Ok('doc-1');
  int saveCount = 0;
  int withImageCount = 0;
  DocumentAnalysis? lastAnalysis;
  String? lastText;
  String? lastImagePath;

  /// Set to make a save hang until it is completed, so the in-flight state
  /// can be observed — same pattern `AnalysisResultCubit`'s own test suite
  /// uses for its repository fake.
  Completer<void>? gate;

  @override
  Stream<Result<List<RecentDocument>, AppFailure>> watchDocuments({
    String? titleQuery,
    DocumentCategory? category,
  }) => const Stream.empty();

  @override
  Stream<Result<SavedDocument?, AppFailure>> watchDocument(String id) =>
      const Stream.empty();

  @override
  Future<Result<String, AppFailure>> saveResultOnly({
    required DocumentAnalysis analysis,
    required String extractedText,
  }) async {
    saveCount++;
    lastAnalysis = analysis;
    lastText = extractedText;
    await gate?.future;
    return outcome;
  }

  @override
  Future<Result<String, AppFailure>> saveWithImage({
    required DocumentAnalysis analysis,
    required String extractedText,
    required String imagePath,
  }) async {
    withImageCount++;
    lastAnalysis = analysis;
    lastText = extractedText;
    lastImagePath = imagePath;
    await gate?.future;
    return withImageOutcome;
  }

  @override
  Future<Result<void, AppFailure>> updateDocument(
    String id, {
    String? title,
    DocumentCategory? category,
  }) async => const Ok(null);

  @override
  Future<Result<void, AppFailure>> setNote(String id, String? note) async =>
      const Ok(null);

  @override
  Future<Result<void, AppFailure>> deleteDocument(String id) async =>
      const Ok(null);

  @override
  Future<Result<void, AppFailure>> deleteAllDocuments() async => const Ok(null);
}

DocumentAnalysis _analysis() => const DocumentAnalysis(
  sessionId: 'session-1',
  status: AnalysisStatus.success,
  kind: DocumentKind.invoice,
  title: 'فاتورة كهرباء',
  kindConfidence: ConfidenceBand.high,
  summary: AnalysisSummary(short: 'سددها', detailed: 'فاتورة شهر يوليو.'),
);
