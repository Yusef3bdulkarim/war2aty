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
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_state.dart';

void main() {
  late _FakeRepository repository;
  late SaveDocumentCubit cubit;

  setUp(() {
    repository = _FakeRepository();
    cubit = SaveDocumentCubit(
      SaveDocument(repository),
      SaveDocumentWithImage(repository),
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
}

final class _FakeRepository implements DocumentsRepository {
  Result<String, AppFailure> outcome = const Ok('doc-1');
  Result<String, AppFailure> withImageOutcome = const Ok('doc-1');
  int saveCount = 0;
  int withImageCount = 0;
  DocumentAnalysis? lastAnalysis;
  String? lastText;
  String? lastImagePath;

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
}

DocumentAnalysis _analysis() => const DocumentAnalysis(
  sessionId: 'session-1',
  status: AnalysisStatus.success,
  kind: DocumentKind.invoice,
  title: 'فاتورة كهرباء',
  kindConfidence: ConfidenceBand.high,
  summary: AnalysisSummary(short: 'سددها', detailed: 'فاتورة شهر يوليو.'),
);
