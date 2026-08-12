import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/connectivity/analysis_route.dart';
import '../../../analysis/presentation/image_analysis_session_holder.dart';
import '../../../ocr/presentation/ocr_session_holder.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/usecases/assess_image_quality.dart';
import '../../domain/usecases/cleanup_capture_files.dart';
import '../../domain/usecases/correct_perspective.dart';
import '../../domain/usecases/create_analysis_session.dart';
import '../../domain/usecases/decide_analysis_route.dart';
import '../../domain/usecases/rotate_image.dart';
import 'image_preview_state.dart';

/// Drives the crop/rotate preview: track the chosen rotation, then on confirm
/// bake it into an upright file and assess its quality for OCR.
///
/// [proceed] is also where the F13 pipeline split happens: once the session
/// is created, [decideRoute] picks offline (unchanged — hands off to F04's
/// OCR screen) or online (perspective-correct, then hand off straight to the
/// analysis result screen, skipping OCR entirely).
final class ImagePreviewCubit extends Cubit<ImagePreviewState> {
  ImagePreviewCubit({
    required CapturedPhoto source,
    required RotateImage rotate,
    required AssessImageQuality assessQuality,
    required DecideAnalysisRoute decideRoute,
    required CorrectPerspective correctPerspective,
    required CreateAnalysisSession createSession,
    required ImageAnalysisSessionHolder onlineHandoff,
    required OcrSessionHolder ocrHandoff,
    required CleanupCaptureFiles cleanupFiles,
  }) : _source = source,
       _rotate = rotate,
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

  /// Path of the perspective-corrected file produced by [proceed] on the
  /// online route, when it differs from the confirmed photo. Tracked for the
  /// same reason as [_rotatedPath] — an unencrypted temp copy of the user's
  /// document must not survive past this screen (CLAUDE.md §7).
  String? _correctedPath;

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

  /// Creates the analysis session after the quality decision is resolved,
  /// then routes to the offline or online pipeline (F13 locked decision #1).
  ///
  /// Only valid from [ImagePreviewConfirmed]; a no-op in any other state.
  Future<void> proceed() async {
    final current = state;
    if (isClosed || current is! ImagePreviewConfirmed) return;

    emit(const ImagePreviewCreatingSession());

    // A previous run's hand-off may still be sitting in either holder if it
    // was never consumed — clear both so the result route can't pick up
    // stale data from an earlier session once this run populates its own.
    _ocrHandoff.clear();
    _onlineHandoff.clear();

    final sessionResult = await _createSession(current.photo);
    if (isClosed) return;

    final session = sessionResult.valueOrNull;
    if (session == null) {
      emit(const ImagePreviewFailed(0));
      return;
    }

    final route = await _decideRoute();
    if (isClosed) return;

    if (route == AnalysisRoute.offline) {
      emit(ImagePreviewSessionCreated(session));
      return;
    }

    // Online: OCR never runs on this route (F13 locked decision #2 — a
    // failure here fails outright rather than dropping back to offline).
    final correctedResult = await _correctPerspective(current.photo);
    if (isClosed) return;

    final corrected = correctedResult.valueOrNull;
    if (corrected == null) {
      emit(const ImagePreviewFailed(0));
      return;
    }

    // Same reasoning as the rotated file: doclens may hand back the input
    // unchanged (no quad detected), in which case there is nothing new to
    // clean up — only a genuinely new file is tracked.
    if (corrected.path != current.photo.path) _correctedPath = corrected.path;

    _onlineHandoff.set(session, corrected);
    emit(ImagePreviewOnlineReady(session));
  }

  @override
  Future<void> close() {
    final paths = <String>{_source.path};
    final rotated = _rotatedPath;
    if (rotated != null) paths.add(rotated);
    final corrected = _correctedPath;
    if (corrected != null) paths.add(corrected);
    unawaited(_cleanupFiles(paths.toList()));
    return super.close();
  }
}
