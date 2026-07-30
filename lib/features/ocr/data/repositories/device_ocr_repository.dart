import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/ocr_result.dart';
import '../../domain/repositories/ocr_repository.dart';
import '../../domain/services/image_preprocessor.dart';
import '../../domain/services/ocr_engine.dart';

/// Filesystem + ML Kit backed [OcrRepository].
///
/// Chains preprocessing (resize) → OCR engine. Each step returns a [Result],
/// so failures propagate cleanly without exceptions crossing the boundary.
final class DeviceOcrRepository implements OcrRepository {
  const DeviceOcrRepository({
    required ImagePreprocessor preprocessor,
    required OcrEngine engine,
  }) : _preprocessor = preprocessor,
       _engine = engine;

  final ImagePreprocessor _preprocessor;
  final OcrEngine _engine;

  @override
  Future<Result<OcrResult, AppFailure>> recognizeText(String imagePath) async {
    final prepResult = await _preprocessor.preprocess(imagePath);
    if (prepResult.isErr) return Err(prepResult.failureOrNull!);

    return _engine.extractText(prepResult.valueOrNull!);
  }
}
