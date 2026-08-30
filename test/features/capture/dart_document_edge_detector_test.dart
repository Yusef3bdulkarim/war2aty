import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/features/capture/data/services/dart_document_edge_detector.dart';
import 'package:war2aty/features/capture/data/services/detector_tuning.dart';
import 'package:war2aty/features/capture/data/services/document_edge_algorithm.dart';
import 'package:war2aty/features/capture/domain/entities/camera_frame.dart';

import 'support/synthetic_luma.dart';

void main() {
  const detector = DartDocumentEdgeDetector();

  test('returns the quad the algorithm found, across the isolate', () async {
    final frame = syntheticFrame();

    final result = await detector.detect(frame);

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, DocumentEdgeAlgorithm.detect(frame));
  });

  test('an empty scene is Ok(null), not a failure', () async {
    final result = await detector.detect(syntheticFrame(withPage: false));

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, isNull);
  });

  test('a frame whose bytes contradict its dimensions fails', () async {
    final small = syntheticFrame(width: 64, height: 48);
    final broken = CameraFrame(
      bytes: small.bytes,
      width: 640,
      height: 480,
      bytesPerRow: 640,
      format: CameraFrameFormat.luma8,
    );

    final result = await detector.detect(broken);

    expect(result.isErr, isTrue);
    expect(result.failureOrNull, const ImageProcessingFailure());
  });

  test('tuning is carried into the isolate', () async {
    final frame = syntheticFrame();

    const strict = DartDocumentEdgeDetector(
      tuning: DetectorTuning(minAreaFraction: 0.9),
    );
    final result = await strict.detect(frame);

    expect(result.isOk, isTrue);
    expect(result.valueOrNull, isNull);
  });
}
