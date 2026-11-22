import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/voice/usecases/speak_fixed_line.dart';
import '../../../../core/voice/voice_line.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/unit_rect.dart';
import '../../domain/usecases/cleanup_capture_files.dart';
import '../../domain/usecases/crop_image.dart';
import '../../domain/usecases/rotate_image.dart';
import 'image_preview_state.dart';

/// Drives the crop/rotate preview: track the chosen rotation, then on confirm
/// bake it into an upright file and hand it on.
///
/// The confirmed image is read exactly as the user framed it — there is no
/// automatic document crop (F15 locked decision #4, amended). From F39/F40-T21
/// the confirmed photo goes straight to the explain pipeline
/// (`PaperExplainRunner`, wired by the router) — the F13/F15 offline/online
/// split this cubit used to decide is gone from here.
final class ImagePreviewCubit extends Cubit<ImagePreviewState> {
  ImagePreviewCubit({
    required CapturedPhoto source,
    required RotateImage rotate,
    required CropImage cropImage,
    required CleanupCaptureFiles cleanupFiles,
    required SpeakFixedLine speakFixedLine,
  }) : _source = source,
       _rotate = rotate,
       _cropImage = cropImage,
       _cleanupFiles = cleanupFiles,
       _speakFixedLine = speakFixedLine,
       super(const ImagePreviewReady(0)) {
    unawaited(_speakFixedLine(VoiceLine.cropContinue));
  }

  /// The image the user acquired (camera or gallery) before any rotation.
  final CapturedPhoto _source;
  final RotateImage _rotate;
  final CropImage _cropImage;
  final CleanupCaptureFiles _cleanupFiles;
  final SpeakFixedLine _speakFixedLine;

  /// Path of the rotated file produced by [confirm], when the rotation differs
  /// from the source. Tracked so [close] can delete it alongside the source.
  String? _rotatedPath;

  /// Path of the manually-cropped file produced by [confirm] when the user
  /// dragged the crop handles (F15 locked decision #5). Tracked for the same
  /// reason as [_rotatedPath] — an unencrypted temp copy of the user's
  /// document must not survive past this screen (CLAUDE.md §7).
  String? _croppedPath;

  bool _filesTransferred = false;

  /// Turns the image 90° clockwise. Ignored while a confirm is in flight so the
  /// rotation cannot change under the export. Resets the crop rect to full
  /// extents rather than remapping it across the turn (F15 locked decision #7).
  void rotateClockwise() {
    if (isClosed || state is ImagePreviewProcessing) return;
    emit(ImagePreviewReady((state.quarterTurns + 1) % 4));
  }

  /// Stores the crop rect the user set by dragging the preview screen's
  /// handles (F15 locked decision #5). Called on drag end (not every frame)
  /// to avoid flooding the state stream.
  ///
  /// Also accepted from [ImagePreviewFailed] — the handles are live again in
  /// that state (the screen only disables them while exporting), so ignoring
  /// the drag would leave them moving under the finger and springing back.
  /// The failure has already been surfaced by then, so returning to editing
  /// is the right resting place.
  void updateCrop(UnitRect rect) {
    if (isClosed) return;
    final turns = switch (state) {
      ImagePreviewReady(:final quarterTurns) => quarterTurns,
      ImagePreviewFailed(:final quarterTurns) => quarterTurns,
      _ => null,
    };
    if (turns == null) return;
    emit(ImagePreviewReady(turns, cropRect: rect));
  }

  /// Bakes rotation and crop into a file and hands it on.
  ///
  /// The pipeline is: rotate → crop → hand off. Both steps are no-ops when
  /// the user left them at the default (0 turns, full crop rect). A quality
  /// assessment used to sit at the end and could send the user back to retake
  /// (F35-T14 removed it).
  ///
  /// A no-op once already confirmed — re-entering would export a second copy
  /// of the same framing and hand back a different file than the confirmed
  /// one. The guard keeps the confirmed result final.
  Future<void> confirm() async {
    if (isClosed ||
        state is ImagePreviewProcessing ||
        state is ImagePreviewConfirmed) {
      return;
    }
    unawaited(_speakFixedLine.stop());
    final turns = state.quarterTurns;
    final cropRect = state.cropRect;
    emit(ImagePreviewProcessing(turns, cropRect: cropRect));

    // 1. Rotate.
    final rotateResult = await _rotate(_source, turns);
    final rotated = rotateResult.valueOrNull;
    if (isClosed) {
      // close() already ran its cleanup sweep with whatever paths were
      // tracked *before* this await started — a file produced after that
      // point is untracked and would survive as an orphaned temp copy
      // unless it's cleaned up right here (privacy §7).
      if (rotated != null && rotated.path != _source.path) {
        unawaited(_cleanupFiles([rotated.path]));
      }
      return;
    }

    if (rotated == null) {
      emit(ImagePreviewFailed(turns, cropRect: cropRect));
      return;
    }

    if (rotated.path != _source.path) _rotatedPath = rotated.path;

    // 2. Crop (no-op when the user left the handles at full extents).
    final cropResult = await _cropImage(rotated, cropRect);
    final cropped = cropResult.valueOrNull;
    if (isClosed) {
      if (cropped != null && cropped.path != rotated.path) {
        unawaited(_cleanupFiles([cropped.path]));
      }
      return;
    }

    if (cropped == null) {
      emit(ImagePreviewFailed(turns, cropRect: cropRect));
      return;
    }

    if (cropped.path != rotated.path) _croppedPath = cropped.path;

    final tempPaths = [_source.path];
    if (_rotatedPath != null) tempPaths.add(_rotatedPath!);
    if (_croppedPath != null) tempPaths.add(_croppedPath!);

    emit(
      ImagePreviewConfirmed(
        cropped,
        quarterTurns: turns,
        cropRect: cropRect,
        tempPaths: tempPaths,
      ),
    );
  }

  /// Hands the confirmed photo's path on to the router, which starts the
  /// explain pipeline (`PaperExplainRunner`) with it.
  ///
  /// `ExplainAndSavePaper` owns the confirmed photo's file from here —
  /// it deletes it (and its own downscaled copy) once the explanation is
  /// done (CLAUDE.md §7). Any *other* temp file this screen produced (the
  /// original source, an intermediate rotated copy) is never touched by
  /// that pipeline, so it is cleaned up here, once, at the same hand-off.
  ///
  /// Only valid from [ImagePreviewConfirmed]; a no-op in any other state,
  /// including a repeat call — file ownership transfers exactly once.
  void handOffToExplain() {
    final current = state;
    if (isClosed || current is! ImagePreviewConfirmed || _filesTransferred) {
      return;
    }
    _filesTransferred = true;

    final finalPath = current.photo.path;
    final leftover = current.tempPaths.where((path) => path != finalPath);
    if (leftover.isNotEmpty) unawaited(_cleanupFiles(leftover.toList()));
  }

  @override
  Future<void> close() async {
    await _speakFixedLine.stop();
    // When the confirmed photo was handed off to the explain pipeline, its
    // own cleanup already ran in handOffToExplain() — repeating it here would
    // just be a no-op delete, but the flag also means ownership transferred.
    if (!_filesTransferred) {
      final paths = <String>{_source.path};
      final rotated = _rotatedPath;
      if (rotated != null) paths.add(rotated);
      final manuallyCropped = _croppedPath;
      if (manuallyCropped != null) paths.add(manuallyCropped);
      unawaited(_cleanupFiles(paths.toList()));
    }
    return super.close();
  }
}
