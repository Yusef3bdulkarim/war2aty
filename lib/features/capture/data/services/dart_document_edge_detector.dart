import 'dart:isolate';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/camera_frame.dart';
import '../../domain/entities/document_quad.dart';
import '../../domain/services/document_edge_detector.dart';
import 'detector_tuning.dart';
import 'document_edge_algorithm.dart';

/// [DocumentEdgeDetector] on top of [DocumentEdgeAlgorithm] — pure Dart, no new
/// package (F16 locked decision #2).
///
/// This class is only the isolate hop and the failure mapping; all the pixel
/// work lives in the algorithm, which is why the isolate strategy can change in
/// F16-T09 without touching tested logic. The pixels are shipped as
/// [TransferableTypedData] so the frame moves to the isolate rather than being
/// copied into it.
///
/// Nothing here writes to disk and nothing is ever logged (F16 locked decision
/// #3, privacy §7).
final class DartDocumentEdgeDetector implements DocumentEdgeDetector {
  const DartDocumentEdgeDetector({
    DetectorTuning tuning = const DetectorTuning(),
  }) : _tuning = tuning;

  final DetectorTuning _tuning;

  @override
  Future<Result<DocumentQuad?, AppFailure>> detect(CameraFrame frame) async {
    // A frame whose bytes contradict its own dimensions is the one thing that
    // is a real failure rather than "no document" — it means the stream is
    // handing us something we cannot read at all.
    if (!frame.isConsistent) return const Err(ImageProcessingFailure());

    try {
      final transferable = TransferableTypedData.fromList([frame.bytes]);
      final width = frame.width;
      final height = frame.height;
      final bytesPerRow = frame.bytesPerRow;
      final format = frame.format;
      final sensorOrientation = frame.sensorOrientation;
      final isMirrored = frame.isMirrored;
      final tuning = _tuning;

      final quad = await Isolate.run(() {
        final rebuilt = CameraFrame(
          bytes: transferable.materialize().asUint8List(),
          width: width,
          height: height,
          bytesPerRow: bytesPerRow,
          format: format,
          sensorOrientation: sensorOrientation,
          isMirrored: isMirrored,
        );
        return DocumentEdgeAlgorithm.detect(rebuilt, tuning);
      });

      return Ok(quad);
    } on Object {
      return const Err(ImageProcessingFailure());
    }
  }
}
