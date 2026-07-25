import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/captured_photo.dart';

/// The system photo picker, as the capture flow needs it.
///
/// Pure Dart: no plugin, no Flutter. Cancelling is a normal outcome, not an
/// error — `Ok(null)` means the user backed out of the picker, while an
/// `Err` is a real failure opening it. Only a single image is ever requested.
abstract interface class ImagePickerService {
  /// Opens the OS picker for one image and returns the chosen photo, or `null`
  /// when the user cancelled.
  Future<Result<CapturedPhoto?, AppFailure>> pickSingleImage();
}
