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
/// [proceed] is also where the F13/F15 pipeline split happens: `doclens`
/// perspective-corrects the confirmed photo on **both** routes (F15 locked
/// decision #4), then [decideRoute] picks offline (hands the corrected
/// image's session off to F04's OCR screen) or online (hands the corrected
/// image straight to the analysis result screen, skipping OCR entirely).
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

  /// Set to `true` once [proceed] successfully hands off to the online
  /// analysis pipeline. When set, [close] skips file cleanup entirely —
  /// ownership of every temp file transfers to [_onlineHandoff], which
  /// deletes them after the analysis repository has read the image bytes.
  /// This prevents a race where `pushReplacement` disposes this cubit (and
  /// its cleanup fires) in the same frame the result route reads the file.
  bool _handedOffToOnline = false;

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

    emit(const ImagePreviewCreatingSession());

    // A previous run's hand-off may still be sitting in either holder if it
    // was never consumed — clear both so the result route can't pick up
    // stale data from an earlier session once this run populates its own.
    _ocrHandoff.clear();
    _onlineHandoff.clear();

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
      emit(ImagePreviewSessionCreated(session));
      return;
    }

    // Online: OCR never runs on this route (F13 locked decision #2 — a
    // failure here fails outright rather than dropping back to offline).
    // Collect every temp file this capture flow produced. Ownership transfers
    // to the holder — close() will skip its own cleanup (see _handedOffToOnline).
    final cleanupPaths = <String>{_source.path};
    final rotated = _rotatedPath;
    if (rotated != null) cleanupPaths.add(rotated);
    final correctedP = _correctedPath;
    if (correctedP != null) cleanupPaths.add(correctedP);

    _onlineHandoff.set(session, corrected, cleanupPaths: cleanupPaths.toList());
    _handedOffToOnline = true;
    emit(ImagePreviewOnlineReady(session));
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
      final corrected = _correctedPath;
      if (corrected != null) paths.add(corrected);
      unawaited(_cleanupFiles(paths.toList()));
    }
    return super.close();
  }
}
