import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';

/// Prepares a captured image for OCR.
///
/// For the MVP this is resize-only: images wider or taller than
/// [maxDimension] are scaled down so the OCR engine does not run out of
/// memory. Images already within bounds are returned untouched.
abstract interface class ImagePreprocessor {
  /// Returns the path to the preprocessed image. When no resize is needed the
  /// returned path may be the same as [imagePath].
  Future<Result<String, AppFailure>> preprocess(String imagePath);
}
