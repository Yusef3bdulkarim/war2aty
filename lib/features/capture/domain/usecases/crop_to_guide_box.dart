import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../entities/unit_rect.dart';
import 'crop_image.dart';

/// Crops a freshly-captured photo to the on-screen guide box the user framed
/// it in, expanded by a safety margin so imperfect alignment doesn't clip the
/// document before `doclens` gets a chance to find its real edges (F15
/// locked decisions #1-#2).
///
/// Camera-only: gallery picks never call this, since no guide box exists for
/// them. [guideBox] is computed by the camera screen from real widget
/// geometry — this use case only owns the margin math and the delegation to
/// [CropImage].
final class CropToGuideBox {
  const CropToGuideBox(this._cropImage);

  final CropImage _cropImage;

  /// Extra padding kept on every side beyond the visible guide box.
  static const double margin = 0.2;

  Future<Result<CapturedPhoto, AppFailure>> call(
    CapturedPhoto photo,
    UnitRect guideBox,
  ) => _cropImage(photo, guideBox.expanded(margin));
}
