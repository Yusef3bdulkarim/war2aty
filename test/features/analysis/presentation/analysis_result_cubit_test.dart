import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_section.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/domain/usecases/build_analysis_result.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_state.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/normalized_ocr_text.dart';

import '../analysis_fixtures.dart';

const _session = AnalysisSession(id: 'session-1', imagePath: '/tmp/paper.jpg');

const _extraction = ExtractionResult(
  text: NormalizedOcrText(
    originalText: 'فاتورة كهرباء ٢٥٠',
    cleanedText: 'فاتورة كهرباء 250',
  ),
  detectedLanguages: ['ar'],
);

/// Records what it was asked, answers what it was told to.
final class FakeAnalysisRepository implements AnalysisRepository {
  FakeAnalysisRepository({this.answer});

  Result<DocumentAnalysis, AppFailure>? answer;

  /// Set to make [analyze] hang until it is completed, so the in-flight state
  /// can be observed.
  Completer<void>? gate;

  final List<AnalysisRequest> requests = [];

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) async {
    requests.add(request);
    await gate?.future;
    return answer ?? Ok(invoiceAnalysis());
  }
}

void main() {
  late FakeAnalysisRepository repository;

  setUp(() => repository = FakeAnalysisRepository());

  AnalysisResultCubit buildCubit() => AnalysisResultCubit(
    session: _session,
    extraction: _extraction,
    analyzeDocument: AnalyzeDocument(repository),
    buildResult: const BuildAnalysisResult(),
  );

  group('AnalysisResultCubit', () {
    test('starts analyzing', () {
      expect(buildCubit().state, const AnalysisResultAnalyzing());
    });

    test('sends the session id, the extraction and the languages — and '
        'nothing else', () async {
      await buildCubit().analyze();

      expect(repository.requests, hasLength(1));
      final request = repository.requests.single;
      expect(request.sessionId, _session.id);
      expect(request.extraction, _extraction);
      expect(request.detectedLanguages, ['ar']);
    });

    test('emits the ordered result on success', () async {
      final cubit = buildCubit();
      await cubit.analyze();

      final state = cubit.state;
      expect(state, isA<AnalysisResultReady>());
      final result = (state as AnalysisResultReady).result;
      expect(result.sections.first, AnalysisSection.header);
      expect(result.extractedText, _extraction.text.cleanedText);
    });

    test('stays analyzing while the request is in flight', () async {
      repository.gate = Completer<void>();
      final cubit = buildCubit();
      final pending = cubit.analyze();

      expect(cubit.state, const AnalysisResultAnalyzing());

      repository.gate!.complete();
      await pending;
      expect(cubit.state, isA<AnalysisResultReady>());
    });

    test('carries the failure through, not a message', () async {
      repository.answer = const Err(NoInternetFailure());
      final cubit = buildCubit();
      await cubit.analyze();

      expect(
        cubit.state,
        // The text comes along: every failure's way forward ends at what the
        // phone already read off the paper.
        AnalysisResultFailed(
          const NoInternetFailure(),
          _extraction.text.cleanedText,
        ),
      );
    });

    test('retrying runs the analysis again', () async {
      repository.answer = const Err(AnalysisServiceFailure());
      final cubit = buildCubit();
      await cubit.analyze();

      repository.answer = null;
      await cubit.analyze();

      expect(repository.requests, hasLength(2));
      expect(cubit.state, isA<AnalysisResultReady>());
    });

    test('does not emit a result once closed', () async {
      repository.gate = Completer<void>();
      final cubit = buildCubit();
      final emitted = <AnalysisResultState>[];
      final subscription = cubit.stream.listen(emitted.add);

      final pending = cubit.analyze();
      await cubit.close();
      repository.gate!.complete();
      await pending;

      expect(emitted.whereType<AnalysisResultReady>(), isEmpty);
      expect(cubit.state, const AnalysisResultAnalyzing());
      await subscription.cancel();
    });
  });
}
