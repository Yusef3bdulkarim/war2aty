import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/ocr/data/repositories/device_ocr_repository.dart';
import 'package:war2aty/features/ocr/domain/entities/ocr_result.dart';
import 'package:war2aty/features/ocr/domain/services/image_preprocessor.dart';
import 'package:war2aty/features/ocr/domain/services/ocr_engine.dart';
import 'package:war2aty/features/ocr/domain/usecases/extract_document_text.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

final class FakePreprocessor implements ImagePreprocessor {
  FakePreprocessor({this.result});
  Result<String, AppFailure>? result;

  @override
  Future<Result<String, AppFailure>> preprocess(String imagePath) async =>
      result ?? Ok(imagePath);
}

final class FakeOcrEngine implements OcrEngine {
  FakeOcrEngine({this.result});
  Result<OcrResult, AppFailure>? result;

  @override
  Future<Result<OcrResult, AppFailure>> extractText(String imagePath) async =>
      result ??
      const Ok(
        OcrResult(
          originalText: 'default text that is long enough',
          detectedLanguages: ['ar'],
        ),
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakePreprocessor preprocessor;
  late FakeOcrEngine engine;
  late ExtractDocumentText useCase;

  setUp(() {
    preprocessor = FakePreprocessor();
    engine = FakeOcrEngine();
    useCase = ExtractDocumentText(
      DeviceOcrRepository(preprocessor: preprocessor, engine: engine),
    );
  });

  group('ExtractDocumentText', () {
    test('returns OcrResult when text is long enough', () async {
      engine.result = const Ok(
        OcrResult(
          originalText: 'هذا نص طويل كفاية للاختبار',
          detectedLanguages: ['ar'],
        ),
      );

      final result = await useCase('/fake/image.jpg');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.originalText, contains('نص'));
    });

    test('returns NoTextDetectedFailure when text is too short', () async {
      engine.result = const Ok(OcrResult(originalText: 'abc'));

      final result = await useCase('/fake/image.jpg');
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NoTextDetectedFailure>());
    });

    test(
      'returns NoTextDetectedFailure when text is only whitespace',
      () async {
        engine.result = const Ok(OcrResult(originalText: '   \n  \t  '));

        final result = await useCase('/fake/image.jpg');
        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isA<NoTextDetectedFailure>());
      },
    );

    test('returns NoTextDetectedFailure when text is empty', () async {
      engine.result = const Ok(OcrResult(originalText: ''));

      final result = await useCase('/fake/image.jpg');
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NoTextDetectedFailure>());
    });

    test('passes exactly 10 characters', () async {
      engine.result = const Ok(OcrResult(originalText: '1234567890'));

      final result = await useCase('/fake/image.jpg');
      expect(result.isOk, isTrue);
    });

    test('fails at 9 characters', () async {
      engine.result = const Ok(OcrResult(originalText: '123456789'));

      final result = await useCase('/fake/image.jpg');
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NoTextDetectedFailure>());
    });

    test('propagates OcrFailure from engine', () async {
      engine.result = const Err(OcrFailure());

      final result = await useCase('/fake/image.jpg');
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<OcrFailure>());
    });

    test('propagates ImageProcessingFailure from preprocessor', () async {
      preprocessor.result = const Err(ImageProcessingFailure());

      final result = await useCase('/fake/image.jpg');
      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<ImageProcessingFailure>());
    });
  });
}
