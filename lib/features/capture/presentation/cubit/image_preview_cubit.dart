import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/captured_photo.dart';
import '../../domain/usecases/assess_image_quality.dart';
import '../../domain/usecases/cleanup_capture_files.dart';
import '../../domain/usecases/create_analysis_session.dart';
import '../../domain/usecases/rotate_image.dart';
import 'image_preview_state.dart';

/// Drives the crop/rotate preview: track the chosen rotation, then on confirm
/// bake it into an upright file and assess its quality for OCR.
final class ImagePreviewCubit extends Cubit<ImagePreviewState> {
  ImagePreviewCubit({
    required CapturedPhoto source,
    required RotateImage rotate,
    required AssessImageQuality assessQuality,
    required CreateAnalysisSession createSession,
    required CleanupCaptureFiles cleanupFiles,
  }) : _source = source,
       _rotate = rotate,
       _assessQuality = assessQuality,
       _createSession = createSession,
       _cleanupFiles = cleanupFiles,
       super(const ImagePreviewReady(0));

  /// The image the user acquired (camera or gallery) before any rotation.
  final CapturedPhoto _source;
  final RotateImage _rotate;
  final AssessImageQuality _assessQuality;
  final CreateAnalysisSession _createSession;
  final CleanupCaptureFiles _cleanupFiles;

  /// Path of the rotated file produced by [confirm], when the rotation differs
  /// from the source. Tracked so [close] can delete it alongside the source.
  String? _rotatedPath;

  /// Turns the image 90° clockwise. Ignored while a confirm is in flight so the
  /// rotation cannot change under the export.
  void rotateClockwise() {
    if (isClosed || state is ImagePreviewProcessing) return;
    emit(ImagePreviewReady((state.quarterTurns + 1) % 4));
  }

  /// Bakes the current rotation into a file, assesses quality, and hands on.
  ///
  /// A no-op once already confirmed: the terminal state's [quarterTurns] reads
  /// as 0, so re-entering here would re-export the *un-rotated* source and hand
  /// back the wrong file. The guard keeps the confirmed result final.
  Future<void> confirm() async {
    if (isClosed ||
        state is ImagePreviewProcessing ||
        state is ImagePreviewConfirmed) {
      return;
    }
    final turns = state.quarterTurns;
    emit(ImagePreviewProcessing(turns));

    final rotateResult = await _rotate(_source, turns);
    if (isClosed) return;

    final photo = rotateResult.valueOrNull;
    if (photo == null) {
      emit(ImagePreviewFailed(turns));
      return;
    }

    if (photo.path != _source.path) _rotatedPath = photo.path;

    final qualityResult = await _assessQuality(photo);
    if (isClosed) return;

    emit(
      qualityResult.fold(
        (quality) => ImagePreviewConfirmed(photo, quality),
        (_) => ImagePreviewFailed(turns),
      ),
    );
  }

  /// Creates the analysis session after the quality decision is resolved.
  ///
  /// Only valid from [ImagePreviewConfirmed]; a no-op in any other state.
  Future<void> proceed() async {
    final current = state;
    if (isClosed || current is! ImagePreviewConfirmed) return;

    emit(const ImagePreviewCreatingSession());

    final result = await _createSession(current.photo);
    if (isClosed) return;

    emit(
      result.fold(
        ImagePreviewSessionCreated.new,
        (_) => const ImagePreviewFailed(0),
      ),
    );
  }

  @override
  Future<void> close() {
    final paths = <String>{_source.path};
    final rotated = _rotatedPath;
    if (rotated != null) paths.add(rotated);
    unawaited(_cleanupFiles(paths.toList()));
    return super.close();
  }
}
