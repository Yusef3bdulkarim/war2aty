import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';

/// Detects a document's edges in a captured photo and crops/dewarps it to a
/// flat, upright rectangle.
///
/// Online-pipeline only (F13 locked decision #1: capture → rotate →
/// perspective-correct → quality-check → Azure). Offline/Tesseract capture is
/// untouched — this step never runs on that path. When no document-like quad
/// is found, implementations return the original photo unchanged rather than
/// forcing a bad crop.
abstract interface class PerspectiveCorrector {
  /// Returns [photo] cropped to its detected document quad, perspective-
  /// corrected to a flat rectangle. Returns [photo] itself, untouched, when
  /// no quad is detected.
  Future<Result<CapturedPhoto, AppFailure>> correct(CapturedPhoto photo);
}
