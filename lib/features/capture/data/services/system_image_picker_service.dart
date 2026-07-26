import 'package:image_picker/image_picker.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/services/image_picker_service.dart';

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
      final file = await _picker.pickImage(source: ImageSource.gallery);
      return Ok(file == null ? null : CapturedPhoto(file.path));
    } on Object {
      return const Err(GalleryAccessFailure());
    }
  }
}
