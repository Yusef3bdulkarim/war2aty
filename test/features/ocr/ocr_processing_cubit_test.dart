import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/core/storage/analysis_session.dart';
import 'package:war2aty/features/ocr/domain/entities/ocr_result.dart';
import 'package:war2aty/features/ocr/domain/repositories/ocr_repository.dart';
import 'package:war2aty/features/ocr/domain/services/amount_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/date_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/phone_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/reference_extractor.dart';
import 'package:war2aty/features/ocr/domain/services/text_normalizer.dart';
import 'package:war2aty/features/ocr/domain/services/time_extractor.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_candidates.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_document_text.dart';
import 'package:war2aty/features/ocr/presentation/cubit/ocr_processing_cubit.dart';
import 'package:war2aty/features/ocr/presentation/cubit/ocr_processing_state.dart';
import 'package:war2aty/features/ocr/presentation/ocr_session_holder.dart';

const _session = AnalysisSession(id: 'test-id', imagePath: '/test/image.jpg');

final class FakeOcrRepository implements OcrRepository {
  Result<OcrResult, AppFailure>? result;

  @override
  Future<Result<OcrResult, AppFailure>> recognizeText(String imagePath) async =>
      result ??
      const Ok(
        OcrResult(
          originalText: 'فاتورة كهرباء بمبلغ كبير جدا يكفي للاختبار',
          detectedLanguages: ['ar'],
        ),
      );
}

void main() {
  late FakeOcrRepository fakeRepo;
  late ExtractDocumentText extractText;
  late ExtractCandidates extractCandidates;
  late OcrSessionHolder sessionHolder;

  setUp(() {
    fakeRepo = FakeOcrRepository();
    extractText = ExtractDocumentText(fakeRepo);
    extractCandidates = ExtractCandidates(
      normalizer: TextNormalizer(),
      dateExtractor: const DateExtractor(),
      timeExtractor: const TimeExtractor(),
      amountExtractor: const AmountExtractor(),
      phoneExtractor: const PhoneExtractor(),
      referenceExtractor: const ReferenceExtractor(),
    );
    sessionHolder = OcrSessionHolder();
  });

  OcrProcessingCubit buildCubit() => OcrProcessingCubit(
    session: _session,
    extractText: extractText,
    extractCandidates: extractCandidates,
    sessionHolder: sessionHolder,
  );

  group('OcrProcessingCubit', () {
    test('initial state is OcrProcessing', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<OcrProcessing>());
      cubit.close();
    });

    test('emits OcrCompleted on successful OCR', () async {
      final cubit = buildCubit();

      final future = expectLater(
        cubit.stream,
        emitsInOrder([isA<OcrProcessing>(), isA<OcrCompleted>()]),
      );

      await cubit.process();
      await future;
      await cubit.close();
    });

    test('emits OcrNoText when NoTextDetectedFailure', () async {
      fakeRepo.result = const Err(NoTextDetectedFailure());
      final cubit = buildCubit();

      final future = expectLater(
        cubit.stream,
        emitsInOrder([isA<OcrProcessing>(), isA<OcrNoText>()]),
      );

      await cubit.process();
      await future;
      await cubit.close();
    });

    test('emits OcrError on OcrFailure', () async {
      fakeRepo.result = const Err(OcrFailure());
      final cubit = buildCubit();

      final future = expectLater(
        cubit.stream,
        emitsInOrder([isA<OcrProcessing>(), isA<OcrError>()]),
      );

      await cubit.process();
      await future;
      await cubit.close();
    });

    test('emits OcrError on ImageProcessingFailure', () async {
      fakeRepo.result = const Err(ImageProcessingFailure());
      final cubit = buildCubit();

      final future = expectLater(
        cubit.stream,
        emitsInOrder([isA<OcrProcessing>(), isA<OcrError>()]),
      );

      await cubit.process();
      await future;
      await cubit.close();
    });

    test(
      'OcrCompleted carries ExtractionResult with normalized text',
      () async {
        fakeRepo.result = const Ok(
          OcrResult(
            originalText: '١٥/٠٧/٢٠٢٦ مبلغ ١٠٠ ج.م.',
            detectedLanguages: ['ar'],
          ),
        );
        final cubit = buildCubit();

        final future = expectLater(
          cubit.stream,
          emitsInOrder([isA<OcrProcessing>(), isA<OcrCompleted>()]),
        );

        await cubit.process();
        await future;

        final completed = cubit.state as OcrCompleted;
        expect(completed.result.text.cleanedText, contains('15/07/2026'));
        expect(completed.result.dates, isNotEmpty);
        expect(completed.result.amounts, isNotEmpty);
        await cubit.close();
      },
    );

    test('does not emit after close', () async {
      final cubit = buildCubit();
      await cubit.close();

      await cubit.process();

      expect(cubit.state, isA<OcrProcessing>());
    });

    test('confirm() stores result in session holder', () async {
      final cubit = buildCubit();

      final future = expectLater(
        cubit.stream,
        emitsInOrder([isA<OcrProcessing>(), isA<OcrCompleted>()]),
      );

      await cubit.process();
      await future;

      cubit.confirm();

      expect(sessionHolder.session, _session);
      expect(sessionHolder.result, isNotNull);
      await cubit.close();
    });

    test('confirm() does nothing when state is not OcrCompleted', () {
      final cubit = buildCubit();

      cubit.confirm();

      expect(sessionHolder.session, isNull);
      expect(sessionHolder.result, isNull);
      cubit.close();
    });
  });
}
