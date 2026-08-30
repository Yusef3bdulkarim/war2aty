import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../entities/camera_frame.dart';
import '../entities/document_quad.dart';
import '../services/document_edge_detector.dart';

/// Finds the document in one preview frame, so the viewfinder can aim its
/// guide at the paper (F16).
///
/// The cubit reaches the detector only through here (F16 locked decision #5) —
/// never the service, and never a widget.
final class DetectDocumentEdges {
  const DetectDocumentEdges(this._detector);

  final DocumentEdgeDetector _detector;

  /// `Ok(null)` means no document in this frame — the ordinary case, not a
  /// failure.
  Future<Result<DocumentQuad?, AppFailure>> call(CameraFrame frame) =>
      _detector.detect(frame);
}
