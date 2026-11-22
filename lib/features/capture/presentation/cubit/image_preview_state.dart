import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/unit_rect.dart';

/// Where the crop/rotate preview stands.
///
/// Every non-terminal state carries the current [quarterTurns] (0–3, clockwise)
/// so the screen can rotate the preview live without any pixel work — the
/// rotation is only baked into a file when the user confirms.
sealed class ImagePreviewState {
  const ImagePreviewState();

  /// Quarter-turns applied so far. Zero for terminal states.
  int get quarterTurns => 0;

  /// The crop region the user has selected, as fractions of the (visually
  /// rotated) image. Full extents for terminal states.
  ///
  /// Lives on the base for the same reason [quarterTurns] does: the screen
  /// paints the overlay from whatever state is current, so a state that
  /// dropped the selection would snap it back to the whole image — visibly,
  /// mid-export — and [ImagePreviewCubit.confirm] reads it back when the user
  /// retries after a failure, which would silently discard their crop.
  UnitRect get cropRect => UnitRect.full;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is ImagePreviewState &&
      other.quarterTurns == quarterTurns &&
      other.cropRect == cropRect;

  @override
  int get hashCode => Object.hash(runtimeType, quarterTurns, cropRect);
}

/// Editing: the image is shown with the crop frame, controls are live.
///
/// [cropRect] tracks the user's manual crop selection (F15 locked decision #5).
/// Starts at [UnitRect.full] (the whole image); resets to full on rotate
/// (F15 locked decision #7).
final class ImagePreviewReady extends ImagePreviewState {
  const ImagePreviewReady(this.quarterTurns, {this.cropRect = UnitRect.full});

  @override
  final int quarterTurns;

  /// The drag-crop region the user has chosen, as fractions of the
  /// (visually rotated) image. Updated by [ImagePreviewCubit.updateCrop].
  @override
  final UnitRect cropRect;

  @override
  bool operator ==(Object other) =>
      other is ImagePreviewReady &&
      other.quarterTurns == quarterTurns &&
      other.cropRect == cropRect;

  @override
  int get hashCode => Object.hash(runtimeType, quarterTurns, cropRect);
}

/// Baking the rotation into a file after confirm. Controls are disabled so the
/// image cannot be rotated out from under the export.
///
/// Carries [cropRect] so the overlay keeps showing the selection being baked
/// instead of snapping open behind the processing veil.
final class ImagePreviewProcessing extends ImagePreviewState {
  const ImagePreviewProcessing(
    this.quarterTurns, {
    this.cropRect = UnitRect.full,
  });

  @override
  final int quarterTurns;

  @override
  final UnitRect cropRect;
}

/// The upright image is ready; the screen hands [photo] straight to the next
/// stage. A quality verdict used to ride along here and decide whether to
/// proceed or warn first (F35-T14 removed it) — confirming is now the whole
/// decision.
final class ImagePreviewConfirmed extends ImagePreviewState {
  const ImagePreviewConfirmed(
    this.photo, {
    this.quarterTurns = 0,
    this.cropRect = UnitRect.full,
    this.tempPaths = const [],
  });

  final CapturedPhoto photo;
  final List<String> tempPaths;

  /// The rotation and crop the user settled on.
  ///
  /// The screen never swaps to [photo] — it keeps showing the *source* image
  /// with these applied live. Dropping them here would flip the preview back
  /// to the raw photo for the frame between confirming and the session being
  /// created.
  @override
  final int quarterTurns;

  @override
  final UnitRect cropRect;

  // Equality stays on the result itself: [photo] already determines what the
  // rotation and crop produced, and every existing expectation compares
  // against a plain `ImagePreviewConfirmed(photo)`.
  @override
  bool operator ==(Object other) =>
      other is ImagePreviewConfirmed && other.photo == photo;

  @override
  int get hashCode => photo.hashCode;
}

/// Baking the rotation failed. The screen surfaces a message and drops back to
/// editing (same [quarterTurns] and [cropRect]) so the user can try again
/// without having to redo their crop.
final class ImagePreviewFailed extends ImagePreviewState {
  const ImagePreviewFailed(this.quarterTurns, {this.cropRect = UnitRect.full});

  @override
  final int quarterTurns;

  @override
  final UnitRect cropRect;
}
