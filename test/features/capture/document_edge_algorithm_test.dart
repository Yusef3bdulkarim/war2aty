import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/features/capture/data/services/detector_tuning.dart';
import 'package:war2aty/features/capture/data/services/document_edge_algorithm.dart';
import 'package:war2aty/features/capture/domain/entities/camera_frame.dart';

import 'support/synthetic_luma.dart';

void main() {
  group('DocumentEdgeAlgorithm · a page it should find', () {
    test('finds a clean page on a dark background', () {
      final frame = syntheticFrame();

      final quad = DocumentEdgeAlgorithm.detect(frame);

      expect(quad, isNotNull);
      final rect = quad!.boundingRect;
      expect(rect.left, closeTo(0.2, 0.05));
      expect(rect.top, closeTo(0.2, 0.05));
      expect(rect.right, closeTo(0.8, 0.05));
      expect(rect.bottom, closeTo(0.8, 0.05));
      expect(quad.isValid(), isTrue);
    });

    test('finds a page rotated 15°', () {
      final frame = syntheticFrame(rotationDegrees: 15);

      final quad = DocumentEdgeAlgorithm.detect(frame);

      expect(quad, isNotNull);
      // A rotated page's bounding box is wider than the page itself, but its
      // centre stays put.
      final rect = quad!.boundingRect;
      expect((rect.left + rect.right) / 2, closeTo(0.5, 0.05));
      expect((rect.top + rect.bottom) / 2, closeTo(0.5, 0.05));
      expect(quad.isConvex, isTrue);
    });

    test('finds a page rotated 35°', () {
      final frame = syntheticFrame(rotationDegrees: 35);

      final quad = DocumentEdgeAlgorithm.detect(frame);

      expect(quad, isNotNull);
      expect(quad!.isConvex, isTrue);
      expect(quad.area, greaterThan(0.2));
    });

    test('finds a receipt — narrow, and much smaller than the frame', () {
      final frame = syntheticFrame(
        pageLeft: 0.38,
        pageRight: 0.62,
        pageTop: 0.15,
        pageBottom: 0.85,
      );

      final quad = DocumentEdgeAlgorithm.detect(frame);

      expect(quad, isNotNull);
      final rect = quad!.boundingRect;
      expect(rect.right - rect.left, closeTo(0.24, 0.06));
      expect(rect.bottom - rect.top, closeTo(0.7, 0.06));
    });

    test('survives moderate sensor noise', () {
      final frame = syntheticFrame(noise: 8);

      final quad = DocumentEdgeAlgorithm.detect(frame);

      expect(quad, isNotNull);
      expect(quad!.boundingRect.left, closeTo(0.2, 0.06));
    });
  });

  group('DocumentEdgeAlgorithm · nothing to find', () {
    test('a flat frame yields no quad', () {
      final frame = syntheticFrame(withPage: false);

      expect(DocumentEdgeAlgorithm.detect(frame), isNull);
    });

    test('a noisy but featureless frame yields no quad', () {
      final frame = syntheticFrame(withPage: false, noise: 10);

      expect(DocumentEdgeAlgorithm.detect(frame), isNull);
    });

    test('a white page on a near-white desk is not detected — the documented '
        'weak point (F16 Risks), which locked decision #4 turns into the '
        'static box rather than a failure', () {
      final frame = syntheticFrame(backgroundLuma: 185, pageLuma: 195);

      expect(DocumentEdgeAlgorithm.detect(frame), isNull);
    });

    test(
      'a page bleeding past every border is rejected as the frame itself',
      () {
        final frame = syntheticFrame(
          pageLeft: -0.2,
          pageTop: -0.2,
          pageRight: 1.2,
          pageBottom: 1.2,
        );

        expect(DocumentEdgeAlgorithm.detect(frame), isNull);
      },
    );

    test('a page below the minimum area is rejected', () {
      final frame = syntheticFrame(
        pageLeft: 0.45,
        pageTop: 0.45,
        pageRight: 0.58,
        pageBottom: 0.58,
      );

      expect(DocumentEdgeAlgorithm.detect(frame), isNull);
    });

    test('an inconsistent frame yields no quad rather than throwing', () {
      final frame = syntheticFrame(width: 64, height: 48);
      final broken = CameraFrame(
        bytes: frame.bytes,
        width: 640,
        height: 480,
        bytesPerRow: 640,
        format: CameraFrameFormat.luma8,
      );

      expect(DocumentEdgeAlgorithm.detect(broken), isNull);
    });
  });

  group('DocumentEdgeAlgorithm · frame layout', () {
    test('row padding does not shear the result', () {
      final tight = DocumentEdgeAlgorithm.detect(syntheticFrame())!;
      final padded = DocumentEdgeAlgorithm.detect(
        syntheticFrame(rowPadding: 32),
      )!;

      expect(padded, tight);
    });

    test('a BGRA frame gives the same quad as the luma one', () {
      final luma = DocumentEdgeAlgorithm.detect(syntheticFrame())!;
      final bgra = DocumentEdgeAlgorithm.detect(
        syntheticFrame(format: CameraFrameFormat.bgra8888),
      )!;

      expect(bgra.boundingRect.left, closeTo(luma.boundingRect.left, 0.02));
      expect(bgra.boundingRect.right, closeTo(luma.boundingRect.right, 0.02));
      expect(bgra.boundingRect.top, closeTo(luma.boundingRect.top, 0.02));
      expect(bgra.boundingRect.bottom, closeTo(luma.boundingRect.bottom, 0.02));
    });

    test('the same frame twice gives the identical quad', () {
      final frame = syntheticFrame(rotationDegrees: 12, noise: 5);

      expect(
        DocumentEdgeAlgorithm.detect(frame),
        DocumentEdgeAlgorithm.detect(frame),
      );
    });
  });

  group('DocumentEdgeAlgorithm · tuning', () {
    test('raising the minimum area turns a found page into no page', () {
      final frame = syntheticFrame();

      expect(DocumentEdgeAlgorithm.detect(frame), isNotNull);
      expect(
        DocumentEdgeAlgorithm.detect(
          frame,
          const DetectorTuning(minAreaFraction: 0.9),
        ),
        isNull,
      );
    });

    test('raising the edge floor above the page contrast finds nothing', () {
      final frame = syntheticFrame();

      expect(
        DocumentEdgeAlgorithm.detect(
          frame,
          const DetectorTuning(minEdgeMagnitude: 2000),
        ),
        isNull,
      );
    });

    test('a larger downscale target still finds the same page', () {
      final frame = syntheticFrame();

      final quad = DocumentEdgeAlgorithm.detect(
        frame,
        const DetectorTuning(targetWidth: 320),
      );

      expect(quad, isNotNull);
      expect(quad!.boundingRect.left, closeTo(0.2, 0.05));
    });
  });
}
