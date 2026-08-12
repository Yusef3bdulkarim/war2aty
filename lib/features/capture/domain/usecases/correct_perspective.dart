import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';
import '../services/perspective_corrector.dart';

/// Online-route-only step between rotate and quality-check (F13 locked
/// decision #1): detects and dewarps the document in [photo], or hands it
/// back unchanged when no document-like quad is found.
final class CorrectPerspective {
  const CorrectPerspective(this._corrector);

  final PerspectiveCorrector _corrector;

  Future<Result<CapturedPhoto, AppFailure>> call(CapturedPhoto photo) {
    return _corrector.correct(photo);
  }
}
