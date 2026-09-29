import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/analysis/analysis_consent_store.dart';
import 'package:war2aty/core/analysis/usecases/get_analysis_consent.dart';
import 'package:war2aty/core/documents/document_analysis.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_image_request.dart';
import 'package:war2aty/features/analysis/domain/entities/analysis_request.dart';
import 'package:war2aty/features/analysis/domain/repositories/analysis_repository.dart';
import 'package:war2aty/features/analysis/domain/usecases/ocr_image.dart';
import 'package:war2aty/features/analysis/presentation/cubit/ocr_review_cubit.dart';
import 'package:war2aty/features/analysis/presentation/cubit/ocr_review_state.dart';
import 'package:war2aty/features/analysis/presentation/image_analysis_session_holder.dart';
import 'package:war2aty/features/capture/domain/entities/captured_photo.dart';
import 'package:war2aty/features/ocr/domain/entities/amount_candidate.dart';
import 'package:war2aty/features/ocr/domain/entities/date_candidate.dart';
import 'package:war2aty/features/ocr/domain/entities/extraction_result.dart';
import 'package:war2aty/features/ocr/domain/entities/normalized_ocr_text.dart';
import 'package:war2aty/features/ocr/domain/services/amount_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/date_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/phone_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/reference_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/text_normalizer.dart';
import 'package:war2aty/features/ocr/domain/services/time_extractor.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_candidates.dart';

const _session = AnalysisSession(id: 'session-1', imagePath: '/tmp/paper.jpg');
const _photo = CapturedPhoto('/tmp/corrected.jpg');

const _serverExtraction = ExtractionResult(
  text: NormalizedOcrText(
    originalText: 'فاتورة كهرباء 850 جنيه بتاريخ 15/04/2024',
    cleanedText: 'فاتورة كهرباء 850 جنيه بتاريخ 15/04/2024',
  ),
  detectedLanguages: ['ar'],
  dates: [DateCandidate(rawText: '15/04/2024')],
  amounts: [AmountCandidate(rawText: '850 جنيه', value: 850, currency: 'EGP')],
);

/// An answer that belongs to a request the user already left behind.
const _staleExtraction = ExtractionResult(
  text: NormalizedOcrText(
    originalText: 'نص قديم من طلب سابق',
    cleanedText: 'نص قديم من طلب سابق',
  ),
);

/// One trip round the event loop, so every pending microtask has run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Records what it was asked, answers what it was told to. [analyze] is
/// never exercised by [OcrReviewCubit] — it throws if hit, so a wiring
/// regression fails loudly instead of silently.
///
/// With [hold] set, each call parks on its own completer in [pending] until
/// the test answers it — so the order answers land in is the test's choice.
final class _FakeAnalysisRepository implements AnalysisRepository {
  Result<ExtractionResult, AppFailure>? ocrAnswer;
  final List<AnalysisImageRequest> ocrRequests = [];
  bool hold = false;
  final List<Completer<Result<ExtractionResult, AppFailure>>> pending = [];

  @override
  Future<Result<DocumentAnalysis, AppFailure>> analyze(
    AnalysisRequest request,
  ) => throw UnimplementedError('OcrReviewCubit never calls analyze');

  @override
  Future<Result<ExtractionResult, AppFailure>> ocrImage(
    AnalysisImageRequest request,
  ) async {
    ocrRequests.add(request);
    if (hold) {
      final answer = Completer<Result<ExtractionResult, AppFailure>>();
      pending.add(answer);
      return answer.future;
    }
    return ocrAnswer ?? const Ok(_serverExtraction);
  }
}

void main() {
  late _FakeAnalysisRepository repository;
  late AnalysisConsentStore consentStore;
  late ImageAnalysisSessionHolder imageHolder;
  late ExtractCandidates extractCandidates;

  setUp(() {
    repository = _FakeAnalysisRepository();
    consentStore = _FakeConsentStore();
    imageHolder = ImageAnalysisSessionHolder()..set(_session, _photo);
    extractCandidates = ExtractCandidates(
      normalizer: TextNormalizer(),
      dateExtractor: const DateExtractor(),
      timeExtractor: const TimeExtractor(),
      amountExtractor: const AmountExtractor(),
      phoneExtractor: const PhoneExtractor(),
      referenceExtractor: const ReferenceExtractor(),
    );
  });

  OcrReviewCubit buildCubit() => OcrReviewCubit(
    session: _session,
    photo: _photo,
    ocrImage: OcrImage(repository),
    extractCandidates: extractCandidates,
    getAnalysisConsent: GetAnalysisConsent(consentStore),
    imageHolder: imageHolder,
  );

  group('OcrReviewCubit', () {
    test('initial state is OcrReviewLoading', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<OcrReviewLoading>());
      cubit.close();
    });

    test(
      'runOcr emits Ready on success, seeded from the server text',
      () async {
        final cubit = buildCubit();

        final future = expectLater(
          cubit.stream,
          emitsInOrder([isA<OcrReviewLoading>(), isA<OcrReviewReady>()]),
        );

        await cubit.runOcr();
        await future;

        final ready = cubit.state as OcrReviewReady;
        expect(ready.originalOcrText, _serverExtraction.text.cleanedText);
        expect(ready.reviewedOcrText, _serverExtraction.text.cleanedText);
        expect(ready.isEdited, isFalse);
        expect(ready.serverCandidates, _serverExtraction);
        expect(ready.detectedLanguages, ['ar']);
        expect(ready.imagePath, _photo.path);
        expect(repository.ocrRequests.single.sessionId, 'session-1');
        expect(repository.ocrRequests.single.photo, _photo);
        await cubit.close();
      },
    );

    test('runOcr emits PoorQuality on empty OCR text', () async {
      repository.ocrAnswer = const Ok(
        ExtractionResult(
          text: NormalizedOcrText(originalText: '   ', cleanedText: '   '),
        ),
      );
      final cubit = buildCubit();

      final future = expectLater(
        cubit.stream,
        emitsInOrder([isA<OcrReviewLoading>(), isA<OcrReviewPoorQuality>()]),
      );

      await cubit.runOcr();
      await future;

      final poorQuality = cubit.state as OcrReviewPoorQuality;
      expect(poorQuality.imagePath, _photo.path);
      await cubit.close();
    });

    test('runOcr emits Failed on a repository error', () async {
      repository.ocrAnswer = const Err(AnalysisServiceFailure());
      final cubit = buildCubit();

      final future = expectLater(
        cubit.stream,
        emitsInOrder([isA<OcrReviewLoading>(), isA<OcrReviewFailed>()]),
      );

      await cubit.runOcr();
      await future;

      expect(
        (cubit.state as OcrReviewFailed).failure,
        isA<AnalysisServiceFailure>(),
      );
      await cubit.close();
    });

    test(
      'runOcr emits Failed without calling the service when consent is declined',
      () async {
        consentStore = _FakeConsentStore(false);
        final cubit = buildCubit();

        final future = expectLater(
          cubit.stream,
          emitsInOrder([isA<OcrReviewLoading>(), isA<OcrReviewFailed>()]),
        );

        await cubit.runOcr();
        await future;

        expect(
          (cubit.state as OcrReviewFailed).failure,
          isA<AnalysisConsentDeclinedFailure>(),
        );
        expect(repository.ocrRequests, isEmpty);
        await cubit.close();
      },
    );

    test(
      'updateOcrText replaces reviewedOcrText, leaves originalOcrText alone',
      () async {
        final cubit = buildCubit();
        await cubit.runOcr();

        cubit.updateOcrText('نص معدّل من المستخدم');

        final ready = cubit.state as OcrReviewReady;
        expect(ready.reviewedOcrText, 'نص معدّل من المستخدم');
        expect(ready.originalOcrText, _serverExtraction.text.cleanedText);
        expect(ready.isEdited, isTrue);
        await cubit.close();
      },
    );

    test('updateOcrText is a no-op outside OcrReviewReady', () {
      final cubit = buildCubit();

      cubit.updateOcrText('too early');

      expect(cubit.state, isA<OcrReviewLoading>());
      cubit.close();
    });

    test('buildReviewedResult re-extracts candidates from the edited text, '
        'not the stale server candidates', () async {
      final cubit = buildCubit();
      await cubit.runOcr();

      // The server said 850 جنيه — the user corrects it to 1800.
      cubit.updateOcrText('فاتورة كهرباء 1800 جنيه بتاريخ 20/08/2026');

      final rebuilt = cubit.buildReviewedResult();

      expect(rebuilt.text.cleanedText, contains('1800'));
      expect(rebuilt.amounts, isNotEmpty);
      expect(rebuilt.amounts.single.value, 1800);
      // Not the server's 850 — buildReviewedResult must not fall back to
      // OcrReviewReady.serverCandidates.
      expect(rebuilt.amounts.single.value, isNot(850));
      await cubit.close();
    });

    test('buildReviewedResult throws outside OcrReviewReady', () {
      final cubit = buildCubit();

      expect(cubit.buildReviewedResult, throwsStateError);
      cubit.close();
    });

    test('cleanupImage clears the image holder', () async {
      final cubit = buildCubit();
      await cubit.runOcr();

      cubit.cleanupImage();

      expect(imageHolder.session, isNull);
      expect(imageHolder.photo, isNull);
      await cubit.close();
    });

    test('close() clears the image holder as a safety net', () async {
      final cubit = buildCubit();
      await cubit.runOcr();

      await cubit.close();

      expect(imageHolder.session, isNull);
      expect(imageHolder.photo, isNull);
    });

    test('does not emit after close', () async {
      final cubit = buildCubit();
      await cubit.close();

      await cubit.runOcr();

      expect(cubit.state, isA<OcrReviewLoading>());
    });
  });

  group('stale requests (F20 §4)', () {
    late List<OcrReviewState> emitted;
    late StreamSubscription<OcrReviewState> subscription;

    OcrReviewCubit watchedCubit() {
      final cubit = buildCubit();
      emitted = [];
      subscription = cubit.stream.listen(emitted.add);
      return cubit;
    }

    tearDown(() => subscription.cancel());

    test('Retake mid-flight: the late answer is discarded', () async {
      repository.hold = true;
      final cubit = watchedCubit();

      final run = cubit.runOcr();
      await _settle();
      expect(repository.pending, hasLength(1));

      // What the Retake / Pick-another handlers call before navigating.
      cubit.cleanupImage();
      repository.pending.single.complete(const Ok(_serverExtraction));
      await run;

      expect(cubit.state, isA<OcrReviewLoading>());
      await _settle();
      expect(emitted, everyElement(isA<OcrReviewLoading>()));
      expect(imageHolder.photo, isNull);
      await cubit.close();
    });

    test('Retake during the consent check: nothing is sent', () async {
      final store = _FakeConsentStore()..gate = Completer<void>();
      consentStore = store;
      final cubit = watchedCubit();

      final run = cubit.runOcr();
      await _settle();

      cubit.cleanupImage();
      store.gate!.complete();
      await run;

      expect(repository.ocrRequests, isEmpty);
      await _settle();
      expect(emitted, everyElement(isA<OcrReviewLoading>()));
      await cubit.close();
    });

    test('double retry: only the newest request may emit', () async {
      repository.hold = true;
      final cubit = watchedCubit();

      final first = cubit.runOcr();
      await _settle();
      final second = cubit.runOcr();
      await _settle();
      expect(repository.pending, hasLength(2));

      // The older answer lands first — it must not pre-empt the newer one.
      repository.pending[0].complete(const Ok(_staleExtraction));
      await first;
      expect(cubit.state, isA<OcrReviewLoading>());

      repository.pending[1].complete(const Ok(_serverExtraction));
      await second;

      final ready = cubit.state as OcrReviewReady;
      expect(ready.originalOcrText, _serverExtraction.text.cleanedText);
      await _settle();
      expect(emitted.whereType<OcrReviewReady>(), hasLength(1));
      await cubit.close();
    });

    test('a late stale result never overwrites the current one', () async {
      repository.hold = true;
      final cubit = watchedCubit();

      final first = cubit.runOcr();
      await _settle();
      final second = cubit.runOcr();
      await _settle();

      repository.pending[1].complete(const Ok(_serverExtraction));
      await second;
      expect(cubit.state, isA<OcrReviewReady>());

      // The superseded request finally answers — with a failure, which would
      // otherwise replace the review the user is already reading.
      repository.pending[0].complete(const Err(OnlineOcrUnavailableFailure()));
      await first;

      final ready = cubit.state as OcrReviewReady;
      expect(ready.originalOcrText, _serverExtraction.text.cleanedText);
      await _settle();
      expect(emitted.whereType<OcrReviewFailed>(), isEmpty);
      await cubit.close();
    });

    test(
      'close mid-call: the answer lands without emitting or throwing',
      () async {
        repository.hold = true;
        final cubit = watchedCubit();

        final run = cubit.runOcr();
        await _settle();

        await cubit.close();
        repository.pending.single.complete(const Ok(_serverExtraction));

        // An emit after close would throw a StateError out of this future.
        await expectLater(run, completes);
        await _settle();
        expect(emitted, everyElement(isA<OcrReviewLoading>()));
        expect(imageHolder.photo, isNull);
      },
    );
  });
}

/// In-memory [AnalysisConsentStore] — `null`/`true` both mean "allowed"
/// ([GetAnalysisConsent] defaults on), same as F11-T02's real store.
///
/// With [gate] set, the read waits for it, so a test can act mid-check.
final class _FakeConsentStore implements AnalysisConsentStore {
  _FakeConsentStore([this._consent]);

  bool? _consent;
  Completer<void>? gate;

  @override
  Future<bool?> readConsent() async {
    await gate?.future;
    return _consent;
  }

  @override
  Future<void> writeConsent(bool consent) async => _consent = consent;
}
