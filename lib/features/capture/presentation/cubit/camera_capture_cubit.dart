import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/unit_rect.dart';
import '../../domain/usecases/capture_photo.dart';
import '../../domain/usecases/cleanup_capture_files.dart';
import '../../domain/usecases/crop_to_guide_box.dart';
import '../../domain/usecases/dispose_camera.dart';
import '../../domain/usecases/initialize_camera.dart';
import '../camera_preview_port.dart';
import 'camera_capture_state.dart';

/// Drives the viewfinder: open the camera, take one photo, crop it to the
/// guide box the user framed it in, release the camera.
///
/// Business actions go through use cases. The one thing that is not a use case
/// is [preview] — a pure UI port the screen uses to paint the live feed; it
/// shares the same underlying camera as the use cases (wired together in DI),
/// so what the user sees and what the shutter captures are the one device.
final class CameraCaptureCubit extends Cubit<CameraCaptureState> {
  CameraCaptureCubit({
    required this.preview,
    required InitializeCamera initializeCamera,
    required CapturePhoto capturePhoto,
    required CropToGuideBox cropToGuideBox,
    required DisposeCamera disposeCamera,
    required CleanupCaptureFiles cleanupFiles,
  }) : _initializeCamera = initializeCamera,
       _capturePhoto = capturePhoto,
       _cropToGuideBox = cropToGuideBox,
       _disposeCamera = disposeCamera,
       _cleanupFiles = cleanupFiles,
       super(const CameraInitializing());

  /// The live-preview port for the screen to render. Not business logic.
  final CameraPreviewPort preview;

  final InitializeCamera _initializeCamera;
  final CapturePhoto _capturePhoto;
  final CropToGuideBox _cropToGuideBox;
  final DisposeCamera _disposeCamera;
  final CleanupCaptureFiles _cleanupFiles;

  /// Advanced by every start/capture/suspend. An async action that finds the
  /// counter has moved on while it was awaiting drops its result silently, so a
  /// [suspend] (app backgrounded) can never be overwritten by a [start] or
  /// [capture] that was still in flight when it ran.
  int _generation = 0;

  /// Opens the camera. Also the retry path after an error and the re-open path
  /// when the app returns to the foreground.
  Future<void> start() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(const CameraInitializing());

    final result = await _initializeCamera();
    if (isClosed || generation != _generation) return;

    emit(result.fold((_) => const CameraReady(), CameraCaptureError.new));
  }

  /// Fires the shutter. Ignored unless the preview is live, so a stray tap
  /// during loading or a double-tap mid-capture cannot take a second photo.
  ///
  /// [guideBox] is the on-screen guide box's position, as a fraction of the
  /// live preview's own rect — measured by the screen from real widget
  /// geometry, since the cubit has no way to see layout itself. Passing
  /// [UnitRect.full] skips the crop entirely (the screen's fallback when it
  /// couldn't measure the geometry, F15-T03).
  Future<void> capture({required UnitRect guideBox}) async {
    if (isClosed || state is! CameraReady) return;
    final generation = ++_generation;
    emit(const CameraCapturing());

    final captureResult = await _capturePhoto();
    if (isClosed || generation != _generation) return;

    final photo = captureResult.valueOrNull;
    if (photo == null) {
      emit(CameraCaptureError(captureResult.failureOrNull!));
      return;
    }

    final cropResult = await _cropToGuideBox(photo, guideBox);
    if (isClosed || generation != _generation) return;

    // The raw pre-crop file is superseded the moment cropping produces a
    // genuinely new one (or the crop fails outright, in which case nothing
    // downstream will ever see or clean up this path) — never left as an
    // orphaned temp file (privacy §7). A no-op crop (region.isFull) returns
    // the same path, so there is nothing extra to delete there.
    final cropped = cropResult.valueOrNull;
    if (cropped == null || cropped.path != photo.path) {
      unawaited(_cleanupFiles([photo.path]));
    }

    emit(cropResult.fold(CameraCaptured.new, CameraCaptureError.new));
  }

  /// Releases the camera when the app leaves the foreground, so it is not held
  /// while another app (or the lock screen) wants it. The screen re-opens it
  /// with [start] on resume.
  Future<void> suspend() async {
    if (isClosed) return;
    _generation++;
    await _disposeCamera();
    if (isClosed) return;
    emit(const CameraInitializing());
  }

  @override
  Future<void> close() async {
    await _disposeCamera();
    return super.close();
  }
}
