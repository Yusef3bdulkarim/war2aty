import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/focus_point.dart';
import '../../domain/usecases/capture_photo.dart';
import '../../domain/usecases/cleanup_capture_files.dart';
import '../../domain/usecases/dispose_camera.dart';
import '../../domain/usecases/focus_camera.dart';
import '../../domain/usecases/initialize_camera.dart';
import '../../domain/usecases/set_camera_flash.dart';
import '../camera_preview_port.dart';
import 'camera_capture_state.dart';

/// Drives the viewfinder: open the camera, set the flash, focus where the user
/// taps, take one photo, release the camera.
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
    required SetCameraFlash setCameraFlash,
    required FocusCamera focusCamera,
    required DisposeCamera disposeCamera,
    required CleanupCaptureFiles cleanupFiles,
  }) : _initializeCamera = initializeCamera,
       _capturePhoto = capturePhoto,
       _setCameraFlash = setCameraFlash,
       _focusCamera = focusCamera,
       _disposeCamera = disposeCamera,
       _cleanupFiles = cleanupFiles,
       super(const CameraInitializing());

  /// The live-preview port for the screen to render. Not business logic.
  final CameraPreviewPort preview;

  final InitializeCamera _initializeCamera;
  final CapturePhoto _capturePhoto;
  final SetCameraFlash _setCameraFlash;
  final FocusCamera _focusCamera;
  final DisposeCamera _disposeCamera;
  final CleanupCaptureFiles _cleanupFiles;

  /// Advanced by every start/capture/suspend. An async action that finds the
  /// counter has moved on while it was awaiting drops its result silently, so a
  /// [suspend] (app backgrounded) can never be overwritten by a [start] or
  /// [capture] that was still in flight when it ran.
  int _generation = 0;

  /// Set while a flash change is with the camera, so a quick second tap cannot
  /// read the same starting mode and skip a step (F24).
  bool _changingFlash = false;

  /// Opens the camera. Also the retry path after an error, the re-open path
  /// when the app returns to the foreground, and — since it lands on the flash
  /// off — what resets the flash after a retake (F24).
  Future<void> start() async {
    if (isClosed) return;
    final generation = ++_generation;
    emit(const CameraInitializing());

    final result = await _initializeCamera();
    if (isClosed || generation != _generation) return;

    emit(
      result.fold(
        (capabilities) => CameraReady(capabilities: capabilities),
        CameraCaptureError.new,
      ),
    );
  }

  /// Moves the flash one step: off → auto → on → off.
  ///
  /// Ignored unless the preview is armed and the lens has a flash. The new
  /// mode is shown once the camera has taken it; if the camera refuses, the
  /// old mode stays — the flash is an aid, so a refusal is not an error page.
  Future<void> cycleFlash() async {
    final current = state;
    if (isClosed || _changingFlash || current is! CameraReady) return;
    if (!current.capabilities.hasFlash) return;
    final generation = _generation;
    final next = current.flashMode.next;

    _changingFlash = true;
    final Result<void, AppFailure> result;
    try {
      result = await _setCameraFlash(next);
    } finally {
      _changingFlash = false;
    }
    if (isClosed || generation != _generation || state != current) return;
    if (result.isErr) return;

    emit(CameraReady(flashMode: next, capabilities: current.capabilities));
  }

  /// Focuses where the user tapped the preview.
  ///
  /// Ignored unless the preview is armed and the lens can focus on a point.
  /// The outcome is not reported: focusing only helps the shot, so a lens that
  /// declines leaves nothing for the user to act on.
  Future<void> focusAt(FocusPoint point) async {
    final current = state;
    if (isClosed || current is! CameraReady) return;
    if (!current.capabilities.canFocus) return;
    await _focusCamera(point);
  }

  /// Fires the shutter. Ignored unless the preview is live, so a stray tap
  /// during loading or a double-tap mid-capture cannot take a second photo.
  ///
  /// The whole frame is kept: the user's own crop on the preview screen is
  /// the only crop.
  Future<void> capture() async {
    final current = state;
    if (isClosed || current is! CameraReady) return;
    final generation = ++_generation;
    emit(
      CameraCapturing(
        flashMode: current.flashMode,
        capabilities: current.capabilities,
      ),
    );

    final result = await _capturePhoto();
    if (isClosed || generation != _generation) {
      // A stray suspend()/close() during the shutter itself made this run
      // stale — nothing downstream will ever see this file, so it has to be
      // cleaned up right here or it survives as an orphaned temp copy
      // (privacy §7).
      final orphan = result.valueOrNull;
      if (orphan != null) unawaited(_cleanupFiles([orphan.path]));
      return;
    }

    emit(result.fold(CameraCaptured.new, CameraCaptureError.new));
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
