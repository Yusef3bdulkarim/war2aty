import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/ocr_result.dart';

/// Contract for the OCR pipeline: preprocess the image then run text
/// recognition.
///
/// The implementation chains [ImagePreprocessor] → [OcrEngine] and maps
/// any exception to a typed [AppFailure].
abstract interface class OcrRepository {
  Future<Result<OcrResult, AppFailure>> recognizeText(String imagePath);
}
