import 'package:image_picker/image_picker.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/services/image_picker_service.dart';

/// Bounding box a picked gallery photo is downscaled into, preserving aspect
/// ratio. Unlike a camera capture (already capped by [ResolutionPreset.high]
/// in `PlatformCameraService`), a gallery photo has no size ceiling of its
/// own — a modern phone's camera roll can hand back a 12+ MP original. Left
/// uncapped, that same file gets decoded again just to display the crop
/// preview at a few hundred logical pixels wide, wasting memory and risking
/// jank on the very next screen for no visual benefit. 4096 matches
/// `kMaxOcrDimension` (`dart_image_preprocessor.dart`) — the ceiling OCR
/// itself resizes down to later — so this loses no recognition quality, only
/// the wasted read/decode/store of pixels nothing downstream ever uses.
const double _maxPickedDimension = 4096;

/// [ImagePickerService] on top of the `image_picker` plugin.
///
/// The only place that plugin is touched. On iOS 14+ and modern Android this
/// is the system Photos picker, which needs no runtime permission — the OS
/// hands back only the one image the user chose, and nothing else is read.
/// A `null` return is a cancellation; any thrown error becomes a typed
/// [GalleryAccessFailure] here, at the boundary.
final class SystemImagePickerService implements ImagePickerService {
  SystemImagePickerService([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Result<CapturedPhoto?, AppFailure>> pickSingleImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxPickedDimension,
        maxHeight: _maxPickedDimension,
      );
      return Ok(file == null ? null : CapturedPhoto(file.path));
    } on Object {
      return const Err(GalleryAccessFailure());
    }
  }
}
