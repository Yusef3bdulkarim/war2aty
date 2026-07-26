import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';

/// Bakes a quarter-turn rotation into an image file.
///
/// Pure Dart: no plugin, no Flutter. The preview shows rotation live with a
/// cheap widget transform; this is only called once, on confirm, to write the
/// upright image the rest of the pipeline (OCR) will read. `quarterTurns == 0`
/// is a no-op that returns the original photo untouched.
abstract interface class ImageRotator {
  /// Returns a photo rotated [quarterTurns] × 90° clockwise. [quarterTurns] is
  /// taken modulo 4, so any integer is valid.
  Future<Result<CapturedPhoto, AppFailure>> rotate(
    CapturedPhoto photo,
    int quarterTurns,
  );
}
