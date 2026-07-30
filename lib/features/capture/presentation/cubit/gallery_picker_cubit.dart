import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/pick_image_from_gallery.dart';
import 'gallery_picker_state.dart';

/// Drives the one-shot gallery pick: open the system picker, then route on the
/// outcome.
final class GalleryPickerCubit extends Cubit<GalleryPickerState> {
  GalleryPickerCubit({required PickImageFromGallery pickImageFromGallery})
    : _pickImageFromGallery = pickImageFromGallery,
      super(const GalleryPickerPicking());

  final PickImageFromGallery _pickImageFromGallery;

  /// Opens the picker. Also the retry path after a failure.
  Future<void> pick() async {
    if (isClosed) return;
    emit(const GalleryPickerPicking());

    final result = await _pickImageFromGallery();
    if (isClosed) return;

    emit(
      result.fold(
        (photo) => photo == null
            ? const GalleryPickerCancelled()
            : GalleryPickerSelected(photo),
        GalleryPickerError.new,
      ),
    );
  }
}
