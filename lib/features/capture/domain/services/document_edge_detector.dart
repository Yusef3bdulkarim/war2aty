import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/camera_frame.dart';
import '../entities/document_quad.dart';

/// Finds the document in a live camera frame, so the viewfinder can put its
/// guide on the paper instead of asking the user to move the paper to the
/// guide.
///
/// This is guidance only (F16 locked decision #1) — the quad drives what is
/// *drawn*, while `doclens` ([PerspectiveCorrector]) keeps doing the real
/// edge-detect/dewarp on the captured file. The detector therefore only has to
/// be good enough to aim the user.
///
/// Implementations run in a background isolate and never touch the disk
/// (locked decision #3). Mirrors [PerspectiveCorrector]'s shape: interface
/// here, implementation in `data/services`, reached from the cubit through a
/// use case and never from a widget (locked decision #5).
abstract interface class DocumentEdgeDetector {
  /// Returns the document's corners in [frame]'s own normalised coordinates.
  ///
  /// `Ok(null)` means **no document in this frame** — the ordinary, frequent
  /// case, not a failure: the viewfinder simply keeps showing its static box
  /// (locked decision #4). `Err` is reserved for a frame that could not be
  /// processed at all, such as one whose byte length contradicts its
  /// dimensions; it is likewise never surfaced to the user.
  Future<Result<DocumentQuad?, AppFailure>> detect(CameraFrame frame);
}
