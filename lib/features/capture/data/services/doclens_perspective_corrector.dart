// Deliberately not `package:doclens/doclens.dart` — that barrel also exports
// the package's live-camera scanner widgets (`doclens_screen.dart` etc.),
// which fail to compile against this project's Flutter SDK (doclens 0.0.8
// calls a `ReorderableListView.builder` parameter removed since its
// `flutter: ">=3.16.0"` floor). We never use that camera UI (F13 locked
// decision #10), so importing only the platform interface we actually call
// sidesteps the incompatibility entirely.
// ignore: implementation_imports
import 'package:doclens/src/platform_interface.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/services/perspective_corrector.dart';

/// [PerspectiveCorrector] backed by the `doclens` plugin.
///
/// Only ever calls [DoclensPlatform.detectInImage]/`warpImage` — both pure
/// file operations that need no camera session or `initialize()` call.
/// `doclens`'s live-camera scanner UI is never used (it has no RTL support;
/// F13 locked decision #10) — the existing capture screen stays untouched.
final class DoclensPerspectiveCorrector implements PerspectiveCorrector {
  DoclensPerspectiveCorrector({DoclensPlatform? platform})
    : _platform = platform ?? DoclensPlatform.instance;

  final DoclensPlatform _platform;

  @override
  Future<Result<CapturedPhoto, AppFailure>> correct(CapturedPhoto photo) async {
    try {
      final detection = await _platform.detectInImage(imagePath: photo.path);
      // `null` means the file itself could not be read — a real failure, not
      // "no document found" (that case is a non-null detection with a null
      // quad, handled below).
      if (detection == null) return const Err(ImageProcessingFailure());

      final quad = detection.quad;
      if (quad == null) return Ok(photo);

      final warpedPath = await _platform.warpImage(
        rawImagePath: photo.path,
        quad: quad.scaleToSize(detection.imageSize),
        // The one re-encode the OCR path cannot avoid — the warp has to write
        // new pixels — so it is pinned at the maximum rather than left to
        // `doclens`'s default, which a version bump could quietly lower
        // (F17-T07). It is also the lever F17-T10 turns if the payload has to
        // be brought under `max_image_bytes`: trading quality is cheaper than
        // throwing away the resolution F17-T06 just added.
        jpegQuality: 100,
      );
      return Ok(CapturedPhoto(warpedPath));
    } on Object {
      return const Err(ImageProcessingFailure());
    }
  }
}
