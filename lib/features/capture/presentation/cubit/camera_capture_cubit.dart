import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/capture_photo.dart';
import '../../domain/usecases/dispose_camera.dart';
import '../../domain/usecases/initialize_camera.dart';
import '../camera_preview_port.dart';
import 'camera_capture_state.dart';

/// Drives the viewfinder: open the camera, take one photo, release it.
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
    required DisposeCamera disposeCamera,
  }) : _initializeCamera = initializeCamera,
       _capturePhoto = capturePhoto,
       _disposeCamera = disposeCamera,
       super(const CameraInitializing());

  /// The live-preview port for the screen to render. Not business logic.
  final CameraPreviewPort preview;

  final InitializeCamera _initializeCamera;
  final CapturePhoto _capturePhoto;
  final DisposeCamera _disposeCamera;

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
  Future<void> capture() async {
    if (isClosed || state is! CameraReady) return;
    final generation = ++_generation;
    emit(const CameraCapturing());

    final result = await _capturePhoto();
    if (isClosed || generation != _generation) return;

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
