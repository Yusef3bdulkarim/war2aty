import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../entities/unit_rect.dart';

/// Crops a photo to an arbitrary fractional region of itself.
///
/// The single pixel-cropping mechanism shared by the capture-time guide-box
/// crop (applied with a safety margin) and the preview screen's manual
/// drag-crop — both compute a [UnitRect] their own way and hand it to the
/// same implementation. Pure file operation: no plugin, no Flutter.
abstract interface class ImageCropper {
  /// Returns [photo] cropped to [region]. A [region] covering the whole image
  /// ([UnitRect.isFull]) is a no-op that returns the original photo.
  Future<Result<CapturedPhoto, AppFailure>> crop(
    CapturedPhoto photo,
    UnitRect region,
  );
}
