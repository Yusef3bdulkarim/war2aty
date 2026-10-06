import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/documents/analysis_section.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/documents/usecases/build_analysis_result.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/core/storage/usecases/discard_analysis_session.dart';
import 'package:war2aty/core/usage/daily_usage.dart';
import 'package:war2aty/core/usage/usage_repository.dart';
import 'package:war2aty/core/usage/usecases/get_daily_usage.dart';
import 'package:war2aty/core/usage/usecases/sync_daily_usage.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_source.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/analyze_document.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_cubit.dart';
import 'package:war2aty/features/analysis/presentation/cubit/analysis_result_state.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/normalized_ocr_text.dart';

import '../../../support/fakes.dart';
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

  @override
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  ) async {
    throw UnimplementedError('AnalysisResultCubit never calls ocrImage');
  }
}

void main() {
  late FakeAnalysisRepository repository;
  late FakeAnalysisConsentStore consentStore;
  late FakeUsageRepository usageRepository;

  setUp(() {
    repository = FakeAnalysisRepository();
    consentStore = FakeAnalysisConsentStore();
    usageRepository = FakeUsageRepository(
      seed: usageWith(limit: 3, remaining: 3),
    );
  });

  tearDown(() => usageRepository.dispose());

  AnalysisResultCubit buildCubit() => AnalysisResultCubit(
    session: _session,
    source: const OcrAnalysisSource(_extraction),
    getAnalysisConsent: GetAnalysisConsent(consentStore),
    analyzeDocument: AnalyzeDocument(repository),
    buildResult: const BuildAnalysisResult(),
    syncDailyUsage: SyncDailyUsage(usageRepository),
    getDailyUsage: GetDailyUsage(usageRepository),
    discardSession: DiscardAnalysisSession(FakeAnalysisSessionStorage()),
  );

  group('AnalysisResultCubit', () {
    test('starts analyzing', () {
      expect(buildCubit().state, const AnalysisResultAnalyzing());
    });

    // F27-T15 (§7): the result screen is where the scan ends, so the
    // unencrypted working copy must not survive it. Before this, the folder
    // sat in the cache until the next cold launch.
    group('the working files of a finished scan', () {
      test('are deleted when the screen closes', () async {
        final storage = FakeAnalysisSessionStorage();
        final cubit = AnalysisResultCubit(
          session: _session,
          source: const OcrAnalysisSource(_extraction),
          getAnalysisConsent: GetAnalysisConsent(consentStore),
          analyzeDocument: AnalyzeDocument(repository),
          buildResult: const BuildAnalysisResult(),
          syncDailyUsage: SyncDailyUsage(usageRepository),
          getDailyUsage: GetDailyUsage(usageRepository),
          discardSession: DiscardAnalysisSession(storage),
        );

        expect(storage.deleted, isEmpty);
        await cubit.close();

        expect(storage.deleted, [_session.id]);
      });

      test('are deleted even when the analysis never finished', () async {
        final storage = FakeAnalysisSessionStorage();
        repository.answer = const Err(AnalysisServiceFailure());
        final cubit = AnalysisResultCubit(
          session: _session,
          source: const OcrAnalysisSource(_extraction),
          getAnalysisConsent: GetAnalysisConsent(consentStore),
          analyzeDocument: AnalyzeDocument(repository),
          buildResult: const BuildAnalysisResult(),
          syncDailyUsage: SyncDailyUsage(usageRepository),
          getDailyUsage: GetDailyUsage(usageRepository),
          discardSession: DiscardAnalysisSession(storage),
        );

        await cubit.analyze();
        await cubit.close();

        expect(storage.deleted, [_session.id]);
      });
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

    test('syncs the daily usage after a successful analysis', () async {
      final cubit = buildCubit();
      await cubit.analyze();

      expect(usageRepository.syncCallCount, 1);
    });

    test('does not sync the daily usage after a failed analysis', () async {
      repository.answer = const Err(AnalysisServiceFailure());
      final cubit = buildCubit();
      await cubit.analyze();

      expect(usageRepository.syncCallCount, 0);
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

    group('analysis consent (F11-T02)', () {
      test('proceeds when the user has never touched the setting', () async {
        final cubit = buildCubit();
        await cubit.analyze();

        expect(repository.requests, hasLength(1));
        expect(cubit.state, isA<AnalysisResultReady>());
      });

      test('never sends the text when consent is declined', () async {
        await consentStore.writeConsent(false);
        final cubit = buildCubit();
        await cubit.analyze();

        expect(repository.requests, isEmpty);
        expect(
          cubit.state,
          AnalysisResultFailed(
            const AnalysisConsentDeclinedFailure(),
            _extraction.text.cleanedText,
          ),
        );
      });

      test('proceeds once consent is explicitly on', () async {
        await consentStore.writeConsent(true);
        final cubit = buildCubit();
        await cubit.analyze();

        expect(repository.requests, hasLength(1));
        expect(cubit.state, isA<AnalysisResultReady>());
      });
    });

    group('the daily limit for its page (F23-T06)', () {
      final resetAt = DateTime.utc(2026, 10, 1, 22);

      test('carries the cached limit with a daily-limit failure', () async {
        usageRepository.emit(usageWith(limit: 3, remaining: 0));
        repository.answer = Err(DailyLimitReachedFailure(resetAt));
        final cubit = buildCubit();
        await cubit.analyze();

        expect(
          cubit.state,
          AnalysisResultFailed(
            DailyLimitReachedFailure(resetAt),
            _extraction.text.cleanedText,
            dailyLimit: 3,
          ),
        );
      });

      test('leaves the limit out when nothing is cached', () async {
        usageRepository.emit(null);
        repository.answer = Err(DailyLimitReachedFailure(resetAt));
        final cubit = buildCubit();
        await cubit.analyze();

        final state = cubit.state as AnalysisResultFailed;
        expect(state.failure, DailyLimitReachedFailure(resetAt));
        expect(state.dailyLimit, isNull);
      });

      test('leaves the limit out when the cache cannot be read', () async {
        usageRepository.emitFailure();
        repository.answer = Err(DailyLimitReachedFailure(resetAt));
        final cubit = buildCubit();
        await cubit.analyze();

        expect((cubit.state as AnalysisResultFailed).dailyLimit, isNull);
      });

      test('does not read the usage for any other failure', () async {
        repository.answer = const Err(NoInternetFailure());
        final cubit = buildCubit();
        await cubit.analyze();

        expect(usageRepository.cachedReadCount, 0);
        expect((cubit.state as AnalysisResultFailed).dailyLimit, isNull);
      });

      test('emits nothing once closed while the usage is read', () async {
        final usage = _GatedUsageRepository();
        repository.answer = Err(DailyLimitReachedFailure(resetAt));
        final cubit = AnalysisResultCubit(
          session: _session,
          source: const OcrAnalysisSource(_extraction),
          getAnalysisConsent: GetAnalysisConsent(consentStore),
          analyzeDocument: AnalyzeDocument(repository),
          buildResult: const BuildAnalysisResult(),
          syncDailyUsage: SyncDailyUsage(usage),
          getDailyUsage: GetDailyUsage(usage),
          discardSession: DiscardAnalysisSession(FakeAnalysisSessionStorage()),
        );
        final states = <Object>[];
        final subscription = cubit.stream.listen(states.add);

        final pending = cubit.analyze();
        await usage.requested.future;
        await cubit.close();
        usage.gate.complete();
        await pending;
        await subscription.cancel();

        expect(states.whereType<AnalysisResultFailed>(), isEmpty);
      });
    });
  });
}

/// Holds [cachedUsage] open until [gate] completes, so a test can close the
/// cubit while the read is in flight.
final class _GatedUsageRepository implements UsageRepository {
  final requested = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<Result<DailyUsage?, AppFailure>> cachedUsage() async {
    requested.complete();
    await gate.future;
    return Ok(usageWith(limit: 3, remaining: 0));
  }

  @override
  Future<Result<DailyUsage, AppFailure>> syncUsage() =>
      throw UnimplementedError();

  @override
  Stream<Result<DailyUsage?, AppFailure>> watchUsage() =>
      throw UnimplementedError();
}
