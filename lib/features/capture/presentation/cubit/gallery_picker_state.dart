import '../../../../core/error/app_failure.dart';
import '../../domain/entities/captured_photo.dart';

/// Where the gallery pick stands.
///
/// Sealed so the screen handles every outcome — a pick can succeed, be
/// cancelled, or fail, and each leads somewhere different.
sealed class GalleryPickerState {
  const GalleryPickerState();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The OS picker is open (or about to be). The screen shows a neutral wait
/// behind it.
final class GalleryPickerPicking extends GalleryPickerState {
  const GalleryPickerPicking();
}

/// The user chose a photo; the screen hands [photo] to the next stage.
final class GalleryPickerSelected extends GalleryPickerState {
  const GalleryPickerSelected(this.photo);

  final CapturedPhoto photo;

  @override
  bool operator ==(Object other) =>
      other is GalleryPickerSelected && other.photo == photo;

  @override
  int get hashCode => photo.hashCode;
}

/// The user backed out of the picker without choosing. The screen leaves the
/// capture flow.
final class GalleryPickerCancelled extends GalleryPickerState {
  const GalleryPickerCancelled();
}

/// The picker could not be opened. The screen shows the error with a retry.
final class GalleryPickerError extends GalleryPickerState {
  const GalleryPickerError(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is GalleryPickerError && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
