import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/connectivity/analysis_route.dart';
import '../../../analysis/presentation/image_analysis_session_holder.dart';
import '../../../ocr/presentation/ocr_session_holder.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/unit_rect.dart';
import '../../domain/usecases/assess_image_quality.dart';
import '../../domain/usecases/cleanup_capture_files.dart';
import '../../domain/usecases/correct_perspective.dart';
import '../../domain/usecases/create_analysis_session.dart';
import '../../domain/usecases/crop_image.dart';
import '../../domain/usecases/decide_analysis_route.dart';
import '../../domain/usecases/rotate_image.dart';
import 'image_preview_state.dart';

/// Drives the crop/rotate preview: track the chosen rotation, then on confirm
/// bake it into an upright file and assess its quality for OCR.
///
/// [proceed] is also where the F13/F15 pipeline split happens: `doclens`
/// perspective-corrects the confirmed photo on **both** routes (F15 locked
/// decision #4), then [decideRoute] picks offline (hands the corrected
/// image's session off to F04's OCR screen) or online (hands the corrected
/// image straight to the analysis result screen, skipping OCR entirely).
final class ImagePreviewCubit extends Cubit<ImagePreviewState> {
  ImagePreviewCubit({
    required CapturedPhoto source,
    required RotateImage rotate,
    required CropImage cropImage,
    required AssessImageQuality assessQuality,
    required DecideAnalysisRoute decideRoute,
    required CorrectPerspective correctPerspective,
    required CreateAnalysisSession createSession,
    required ImageAnalysisSessionHolder onlineHandoff,
    required OcrSessionHolder ocrHandoff,
    required CleanupCaptureFiles cleanupFiles,
  }) : _source = source,
       _rotate = rotate,
       _cropImage = cropImage,
       _assessQuality = assessQuality,
       _decideRoute = decideRoute,
       _correctPerspective = correctPerspective,
       _createSession = createSession,
       _onlineHandoff = onlineHandoff,
       _ocrHandoff = ocrHandoff,
       _cleanupFiles = cleanupFiles,
       super(const ImagePreviewReady(0));

  /// The image the user acquired (camera or gallery) before any rotation.
  final CapturedPhoto _source;
  final RotateImage _rotate;
  final CropImage _cropImage;
  final AssessImageQuality _assessQuality;
  final DecideAnalysisRoute _decideRoute;
  final CorrectPerspective _correctPerspective;
  final CreateAnalysisSession _createSession;
  final ImageAnalysisSessionHolder _onlineHandoff;
  final OcrSessionHolder _ocrHandoff;
  final CleanupCaptureFiles _cleanupFiles;

  /// Path of the rotated file produced by [confirm], when the rotation differs
  /// from the source. Tracked so [close] can delete it alongside the source.
  String? _rotatedPath;

  /// Path of the manually-cropped file produced by [confirm] when the user
  /// dragged the crop handles (F15 locked decision #5). Tracked for the same
  /// reason as [_rotatedPath] — an unencrypted temp copy of the user's
  /// document must not survive past this screen (CLAUDE.md §7).
  String? _croppedPath;

  /// Path of the perspective-corrected file produced by [proceed] on the
  /// online route, when it differs from the confirmed photo. Tracked for the
  /// same reason as [_rotatedPath] — an unencrypted temp copy of the user's
  /// document must not survive past this screen (CLAUDE.md §7).
  String? _correctedPath;

  /// Set to `true` once [proceed] successfully hands off to the online
  /// analysis pipeline. When set, [close] skips file cleanup entirely —
  /// ownership of every temp file transfers to [_onlineHandoff], which
  /// deletes them after the analysis repository has read the image bytes.
  /// This prevents a race where `pushReplacement` disposes this cubit (and
  /// its cleanup fires) in the same frame the result route reads the file.
  bool _handedOffToOnline = false;

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

  /// Bakes rotation and crop into a file, assesses quality, and hands on.
  ///
  /// The pipeline is: rotate → crop → quality-check (F15 locked decision #8).
  /// Both steps are no-ops when the user left them at the default (0 turns,
  /// full crop rect), and the quality check runs on the *final* image — not
  /// the pre-crop rotation.
  ///
  /// A no-op once already confirmed — re-entering would export a second copy
  /// of the same framing and hand back a different file than the one the
  /// quality sheet is asking about. The guard keeps the confirmed result final.
  Future<void> confirm() async {
    if (isClosed ||
        state is ImagePreviewProcessing ||
        state is ImagePreviewConfirmed) {
      return;
    }
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

    // 3. Quality-check on the final (rotated + cropped) image. Produces no
    // new file, so there is nothing extra to clean up if this races close().
    final qualityResult = await _assessQuality(cropped);
    if (isClosed) return;

    emit(
      qualityResult.fold(
        (quality) => ImagePreviewConfirmed(
          cropped,
          quality,
          quarterTurns: turns,
          cropRect: cropRect,
        ),
        (_) => ImagePreviewFailed(turns, cropRect: cropRect),
      ),
    );
  }

  /// Perspective-corrects, creates the analysis session from that corrected
  /// image, then routes to the offline or online pipeline.
  ///
  /// `doclens` runs on **both** routes (F15 locked decision #4, amending F13
  /// locked decision #1 which was online-only) and *before* session creation
  /// on both — `AnalysisSession.imagePath` is a copy of whatever photo
  /// [_createSession] is given, and that copy is exactly what F04's offline
  /// OCR reads, so the corrected image has to exist before that copy is made.
  ///
  /// Only valid from [ImagePreviewConfirmed]; a no-op in any other state.
  Future<void> proceed() async {
    final current = state;
    if (isClosed || current is! ImagePreviewConfirmed) return;

    // The preview stays on screen under the veil, so it keeps the framing
    // the user confirmed instead of springing back to the raw photo.
    final turns = current.quarterTurns;
    final cropRect = current.cropRect;
    emit(ImagePreviewCreatingSession(quarterTurns: turns, cropRect: cropRect));

    // A previous run's hand-off may still be sitting in either holder if it
    // was never consumed — clear both so the result route can't pick up
    // stale data from an earlier session once this run populates its own.
    _ocrHandoff.clear();
    _onlineHandoff.clear();

    final correctedResult = await _correctPerspective(current.photo);
    final corrected = correctedResult.valueOrNull;
    if (isClosed) {
      // Same reasoning as confirm()'s rotate/crop steps: an untracked file
      // produced after close() already swept must be cleaned up here.
      if (corrected != null && corrected.path != current.photo.path) {
        unawaited(_cleanupFiles([corrected.path]));
      }
      return;
    }

    if (corrected == null) {
      emit(const ImagePreviewFailed(0));
      return;
    }

    // Same reasoning as the rotated file: doclens may hand back the input
    // unchanged (no quad detected), in which case there is nothing new to
    // clean up — only a genuinely new file is tracked.
    if (corrected.path != current.photo.path) _correctedPath = corrected.path;

    final sessionResult = await _createSession(corrected);
    if (isClosed) return;

    final session = sessionResult.valueOrNull;
    if (session == null) {
      emit(const ImagePreviewFailed(0));
      return;
    }

    final route = await _decideRoute();
    if (isClosed) return;

    if (route == AnalysisRoute.offline) {
      emit(
        ImagePreviewSessionCreated(
          session,
          quarterTurns: turns,
          cropRect: cropRect,
        ),
      );
      return;
    }

    // Online: OCR never runs on this route (F13 locked decision #2 — a
    // failure here fails outright rather than dropping back to offline).
    // Collect every temp file this capture flow produced. Ownership transfers
    // to the holder — close() will skip its own cleanup (see _handedOffToOnline).
    final cleanupPaths = <String>{_source.path};
    final rotated = _rotatedPath;
    if (rotated != null) cleanupPaths.add(rotated);
    final manuallyCropped = _croppedPath;
    if (manuallyCropped != null) cleanupPaths.add(manuallyCropped);
    final correctedP = _correctedPath;
    if (correctedP != null) cleanupPaths.add(correctedP);

    _onlineHandoff.set(session, corrected, cleanupPaths: cleanupPaths.toList());
    _handedOffToOnline = true;
    emit(
      ImagePreviewOnlineReady(session, quarterTurns: turns, cropRect: cropRect),
    );
  }

  @override
  Future<void> close() {
    // When the online handoff succeeded, every temp file is now owned by the
    // ImageAnalysisSessionHolder — it deletes them in clear() after the
    // analysis repository has read the image bytes. Deleting here would race
    // against that read (pushReplacement disposes this cubit in the same
    // frame the result route reads the file).
    if (!_handedOffToOnline) {
      final paths = <String>{_source.path};
      final rotated = _rotatedPath;
      if (rotated != null) paths.add(rotated);
      final manuallyCropped = _croppedPath;
      if (manuallyCropped != null) paths.add(manuallyCropped);
      final corrected = _correctedPath;
      if (corrected != null) paths.add(corrected);
      unawaited(_cleanupFiles(paths.toList()));
    }
    return super.close();
  }
}
