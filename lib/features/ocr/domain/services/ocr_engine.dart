import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/ocr_result.dart';

/// Contract for on-device text recognition.
///
/// Implementations wrap a specific OCR backend (ML Kit, Tesseract, etc.)
/// behind this interface so the rest of the app never couples to a concrete
/// engine. The cubit reaches the engine only through [OcrRepository] and
/// use cases — never directly.
abstract interface class OcrEngine {
  /// Recognizes text in the image at [imagePath].
  ///
  /// Returns the raw recognized text and detected languages. The caller is
  /// responsible for normalization and candidate extraction.
  ///
  /// Failures:
  /// - [OcrInitializationFailure] — the engine could not be set up.
  /// - [OcrFailure] — recognition ran but failed.
  Future<Result<OcrResult, AppFailure>> extractText(String imagePath);
}
