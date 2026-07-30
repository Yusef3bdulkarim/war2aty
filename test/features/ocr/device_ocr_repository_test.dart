import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';
import 'package:war2aty/features/ocr/data/repositories/device_ocr_repository.dart';
import 'package:war2aty/features/ocr/domain/entities/ocr_result.dart';
import 'package:war2aty/features/ocr/domain/services/image_preprocessor.dart';
import 'package:war2aty/features/ocr/domain/services/ocr_engine.dart';

final class FakePreprocessor implements ImagePreprocessor {
  FakePreprocessor({this.result});
  Result<String, AppFailure>? result;
  String? lastPath;

  @override
  Future<Result<String, AppFailure>> preprocess(String imagePath) async {
    lastPath = imagePath;
    return result ?? Ok(imagePath);
  }
}

final class FakeOcrEngine implements OcrEngine {
  FakeOcrEngine({this.result});
  Result<OcrResult, AppFailure>? result;
  String? lastPath;

  @override
  Future<Result<OcrResult, AppFailure>> extractText(String imagePath) async {
    lastPath = imagePath;
    return result ??
        const Ok(
          OcrResult(originalText: 'default text', detectedLanguages: ['ar']),
        );
  }
}

void main() {
  late FakePreprocessor preprocessor;
  late FakeOcrEngine engine;
  late DeviceOcrRepository repository;

  setUp(() {
    preprocessor = FakePreprocessor();
    engine = FakeOcrEngine();
    repository = DeviceOcrRepository(
      preprocessor: preprocessor,
      engine: engine,
    );
  });

  group('DeviceOcrRepository', () {
    test('chains preprocessor output to engine input', () async {
      preprocessor.result = const Ok('/preprocessed/image.jpg');
      engine.result = const Ok(
        OcrResult(originalText: 'some text here', detectedLanguages: ['ar']),
      );

      await repository.recognizeText('/original/image.jpg');

      expect(preprocessor.lastPath, '/original/image.jpg');
      expect(engine.lastPath, '/preprocessed/image.jpg');
    });

    test('returns OcrResult on success', () async {
      const expected = OcrResult(
        originalText: 'فاتورة كهرباء',
        detectedLanguages: ['ar'],
      );
      engine.result = const Ok(expected);

      final result = await repository.recognizeText('/image.jpg');

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, expected);
    });

    test('returns failure early when preprocessor fails', () async {
      preprocessor.result = const Err(ImageProcessingFailure());

      final result = await repository.recognizeText('/image.jpg');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<ImageProcessingFailure>());
      expect(engine.lastPath, isNull);
    });

    test('returns failure when engine fails', () async {
      engine.result = const Err(OcrFailure());

      final result = await repository.recognizeText('/image.jpg');

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<OcrFailure>());
    });

    test(
      'passes original path when preprocessor returns it unchanged',
      () async {
        preprocessor.result = const Ok('/original/image.jpg');

        await repository.recognizeText('/original/image.jpg');

        expect(engine.lastPath, '/original/image.jpg');
      },
    );
  });
}
