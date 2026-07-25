import '../../../../core/storage/analysis_session.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/image_quality_result.dart';

/// Where the crop/rotate preview stands.
///
/// Every non-terminal state carries the current [quarterTurns] (0–3, clockwise)
/// so the screen can rotate the preview live without any pixel work — the
/// rotation is only baked into a file when the user confirms.
sealed class ImagePreviewState {
  const ImagePreviewState();

  /// Quarter-turns applied so far. Zero for terminal states.
  int get quarterTurns => 0;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is ImagePreviewState &&
      other.quarterTurns == quarterTurns;

  @override
  int get hashCode => Object.hash(runtimeType, quarterTurns);
}

/// Editing: the image is shown with the crop frame, controls are live.
final class ImagePreviewReady extends ImagePreviewState {
  const ImagePreviewReady(this.quarterTurns);

  @override
  final int quarterTurns;
}

/// Baking the rotation into a file after confirm. Controls are disabled so the
/// image cannot be rotated out from under the export.
final class ImagePreviewProcessing extends ImagePreviewState {
  const ImagePreviewProcessing(this.quarterTurns);

  @override
  final int quarterTurns;
}

/// The upright image is ready; the screen hands [photo] and [quality] to the
/// next stage. The router decides whether to proceed or show a quality warning
/// based on [quality.overall].
final class ImagePreviewConfirmed extends ImagePreviewState {
  const ImagePreviewConfirmed(this.photo, this.quality);

  final CapturedPhoto photo;
  final ImageQualityResult quality;

  @override
  bool operator ==(Object other) =>
      other is ImagePreviewConfirmed &&
      other.photo == photo &&
      other.quality == quality;

  @override
  int get hashCode => Object.hash(photo, quality);
}

/// Baking the rotation failed. The screen surfaces a message and drops back to
/// editing (same [quarterTurns]) so the user can try again.
final class ImagePreviewFailed extends ImagePreviewState {
  const ImagePreviewFailed(this.quarterTurns);

  @override
  final int quarterTurns;
}

/// Creating the session directory and copying the processed image into it.
/// The processing veil stays up until this completes.
final class ImagePreviewCreatingSession extends ImagePreviewState {
  const ImagePreviewCreatingSession();
}

/// Terminal: the session is ready for F04 (OCR + analysis).
final class ImagePreviewSessionCreated extends ImagePreviewState {
  const ImagePreviewSessionCreated(this.session);

  final AnalysisSession session;

  @override
  bool operator ==(Object other) =>
      other is ImagePreviewSessionCreated && other.session == session;

  @override
  int get hashCode => session.hashCode;
}
