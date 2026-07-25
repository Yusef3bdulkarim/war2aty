import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/ocr_result.dart';
import '../repositories/ocr_repository.dart';

/// Minimum non-whitespace characters for the OCR output to be considered
/// usable. Below this threshold the result is treated as "no text found."
const int kMinUsableTextLength = 10;

/// Runs OCR on a processed image and validates that the result contains
/// enough text to be useful.
///
/// Returns [NoTextDetectedFailure] when the recognized text is too short
/// (fewer than [kMinUsableTextLength] non-whitespace characters).
final class ExtractDocumentText {
  const ExtractDocumentText(this._repository);

  final OcrRepository _repository;

  Future<Result<OcrResult, AppFailure>> call(String imagePath) async {
    final result = await _repository.recognizeText(imagePath);

    return result.when(
      ok: (ocrResult) {
        final usableLength = ocrResult.originalText
            .replaceAll(RegExp(r'\s'), '')
            .length;

        if (usableLength < kMinUsableTextLength) {
          return const Err(NoTextDetectedFailure());
        }
        return Ok(ocrResult);
      },
      err: Err.new,
    );
  }
}
