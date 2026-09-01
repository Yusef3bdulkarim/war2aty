import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/camera_frame.dart';
import '../../domain/entities/unit_rect.dart';
import '../../domain/usecases/capture_photo.dart';
import '../../domain/usecases/cleanup_capture_files.dart';
import '../../domain/usecases/crop_to_guide_box.dart';
import '../../domain/usecases/detect_document_edges.dart';
import '../../domain/usecases/dispose_camera.dart';
import '../../domain/usecases/initialize_camera.dart';
import '../../domain/usecases/start_frame_stream.dart';
import '../../domain/usecases/stop_frame_stream.dart';
import '../camera_preview_port.dart';
import '../models/detected_document.dart';
import 'camera_capture_state.dart';
import 'detection_budget.dart';

/// Drives the viewfinder: open the camera, take one photo, release the camera.
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
    required StartFrameStream startFrameStream,
    required StopFrameStream stopFrameStream,
    required DetectDocumentEdges detectDocumentEdges,
    DetectionBudget? detectionBudget,
  }) : _budget = detectionBudget ?? DetectionBudget(),
       _initializeCamera = initializeCamera,
       _capturePhoto = capturePhoto,
       _cropToGuideBox = cropToGuideBox,
       _disposeCamera = disposeCamera,
       _cleanupFiles = cleanupFiles,
       _startFrameStream = startFrameStream,
       _stopFrameStream = stopFrameStream,
       _detectDocumentEdges = detectDocumentEdges,
       super(const CameraInitializing());

  /// The live-preview port for the screen to render. Not business logic.
  final CameraPreviewPort preview;

  final InitializeCamera _initializeCamera;
  final CapturePhoto _capturePhoto;
  final CropToGuideBox _cropToGuideBox;
  final DisposeCamera _disposeCamera;
  final CleanupCaptureFiles _cleanupFiles;
  final StartFrameStream _startFrameStream;
  final StopFrameStream _stopFrameStream;
  final DetectDocumentEdges _detectDocumentEdges;

  /// How many detections in a row may come back empty before the guide lets
  /// go of the last document it saw.
  ///
  /// A page is not lost because one frame blurred as the hand moved; without
  /// this the guide would blink off the paper on every wobble. At F16-T04's
  /// ~120 ms throttle this is roughly half a
  /// second of grace. Policy with a time constant, so it lives here rather
  /// than in the widget, where it could only be tested by pumping frames.
  static const int maxMisses = 5;

  int _missStreak = 0;

  /// Watches how long detection is taking and says when to stop (F16-T09).
  final DetectionBudget _budget;

  /// Latched once this session's detection has been abandoned, so no further
  /// frame is even handed to the detector. Cleared by [start], since a phone
  /// that has cooled down deserves another try.
  bool _detectionDisabled = false;

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

    _missStreak = 0;
    _detectionDisabled = false;
    _budget.reset();
    emit(result.fold((_) => const CameraReady(), CameraCaptureError.new));
    if (result.isErr) return;

    // Live edge detection is guidance, not a prerequisite: if the stream will
    // not start, the viewfinder simply draws no guide and the user is told
    // nothing (F16 locked decision #4).
    final streamed = await _startFrameStream(_onFrame);
    if (isClosed || generation != _generation) {
      if (streamed.isOk) await _stopFrameStream();
    }
  }

  /// One preview frame. Called by the camera service, which admits a single
  /// frame at a time and drops the rest, so there is no backlog to manage
  /// here (F16-T04).
  Future<void> _onFrame(CameraFrame frame) async {
    if (isClosed || _detectionDisabled || state is! CameraReady) return;
    final generation = _generation;

    final stopwatch = Stopwatch()..start();
    final result = await _detectDocumentEdges(frame);
    stopwatch.stop();
    if (isClosed || generation != _generation || state is! CameraReady) return;

    _budget.record(stopwatch.elapsed);
    if (_budget.shouldDisable) {
      await _disableDetection();
      return;
    }

    final quad = result.valueOrNull;
    if (quad == null) {
      // A failed detection and an empty one are the same thing to the user:
      // no guide to draw. Nothing here can produce a CameraCaptureError.
      _missStreak++;
      if (_missStreak >= maxMisses) _publish(null);
      return;
    }

    _missStreak = 0;
    _publish(
      DetectedDocument(
        quad: quad,
        sensorOrientation: frame.sensorOrientation,
        isMirrored: frame.isMirrored,
        frameAspect: frame.height == 0 ? 1 : frame.width / frame.height,
      ),
    );
  }

  /// Gives up on live detection for this session, silently: the stream stops,
  /// the guide disappears, and nothing is shown or logged about it (F16
  /// locked decision #4). Reopening the camera clears this.
  Future<void> _disableDetection() async {
    _detectionDisabled = true;
    _missStreak = 0;
    _publish(null);
    await _stopFrameStream();
  }

  /// Emits only when the detection actually changed, so a phone held still
  /// does not rebuild the viewfinder several times a second.
  void _publish(DetectedDocument? document) {
    final current = state;
    if (current is! CameraReady || current.document == document) return;
    emit(CameraReady(document: document));
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

    // Detection is over for this session the moment the shutter is pressed:
    // its frames would only compete with the capture, and the guide is no
    // longer on screen to move.
    await _stopFrameStream();
    if (isClosed || generation != _generation) return;

    final captureResult = await _capturePhoto();
    if (isClosed || generation != _generation) {
      // A stray suspend()/close() during the shutter itself made this run
      // stale — nothing downstream will ever see this file, so it has to be
      // cleaned up right here or it survives as an orphaned temp copy.
      final orphan = captureResult.valueOrNull;
      if (orphan != null) unawaited(_cleanupFiles([orphan.path]));
      return;
    }

    final photo = captureResult.valueOrNull;
    if (photo == null) {
      emit(CameraCaptureError(captureResult.failureOrNull!));
      return;
    }

    final cropResult = await _cropToGuideBox(photo, guideBox);
    if (isClosed || generation != _generation) {
      // Same reasoning, one step later: clean up whatever this stale run
      // produced — the raw photo, and the cropped file if it's a distinct one.
      final cropped = cropResult.valueOrNull;
      final orphans = <String>{photo.path};
      if (cropped != null && cropped.path != photo.path) {
        orphans.add(cropped.path);
      }
      unawaited(_cleanupFiles(orphans.toList()));
      return;
    }

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
    _missStreak = 0;
    await _stopFrameStream();
    await _disposeCamera();
    if (isClosed) return;
    emit(const CameraInitializing());
  }

  @override
  Future<void> close() async {
    await _stopFrameStream();
    await _disposeCamera();
    return super.close();
  }
}
