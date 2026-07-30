import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/analysis_status.dart';
import 'package:war2aty/core/documents/analysis_summary.dart';
import 'package:war2aty/core/documents/confidence_band.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/document_kind.dart';
import 'package:war2aty/core/documents/documents_repository.dart';
import 'package:war2aty/core/documents/usecases/save_document.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_cubit.dart';
import 'package:war2aty/features/saved_papers/presentation/cubit/save_document_state.dart';

void main() {
  late _FakeRepository repository;
  late SaveDocumentCubit cubit;

  setUp(() {
    repository = _FakeRepository();
    cubit = SaveDocumentCubit(SaveDocument(repository));
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

    expect(states, const [SaveDocumentSaving(), SaveDocumentSaved('doc-1')]);
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

    expect(cubit.state, const SaveDocumentSaved('doc-1'));
    expect(repository.saveCount, 2);
  });

  test('emits nothing once closed', () async {
    await cubit.close();

    await cubit.save(analysis: _analysis(), extractedText: 'نص');

    expect(cubit.state, const SaveDocumentIdle());
  });
}

final class _FakeRepository implements DocumentsRepository {
  Result<String, AppFailure> outcome = const Ok('doc-1');
  int saveCount = 0;
  DocumentAnalysis? lastAnalysis;
  String? lastText;

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
}

DocumentAnalysis _analysis() => const DocumentAnalysis(
  sessionId: 'session-1',
  status: AnalysisStatus.success,
  kind: DocumentKind.invoice,
  title: 'فاتورة كهرباء',
  kindConfidence: ConfidenceBand.high,
  summary: AnalysisSummary(short: 'سددها', detailed: 'فاتورة شهر يوليو.'),
);
