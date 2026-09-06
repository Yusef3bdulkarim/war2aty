import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/entities/camera_frame.dart';
import '../../domain/entities/document_quad.dart';
import '../../domain/entities/unit_point.dart';
import 'detector_tuning.dart';

/// The live document-edge detection pipeline: brightness in, a quad out.
///
/// Pure, synchronous and free of Flutter, plugins and I/O — deliberately kept
/// apart from [DartDocumentEdgeDetector], which only adds the isolate hop and
/// the failure mapping. Tests call this directly, so they need no isolate and
/// have no timing in them, and the isolate strategy can change (F16-T09)
/// without touching a line of tested logic.
///
/// Only good enough to *aim the user* (F16 locked decision #1) — `doclens`
/// still does the real edge-detect/dewarp on the captured file, so nothing
/// downstream depends on these numbers being exact.
final class DocumentEdgeAlgorithm {
  const DocumentEdgeAlgorithm._();

  /// The document's corners in [frame]'s normalised coordinates, or `null`
  /// when there is no document-like shape in it — the ordinary case, not a
  /// failure.
  static DocumentQuad? detect(
    CameraFrame frame, [
    DetectorTuning tuning = const DetectorTuning(),
  ]) {
    if (!frame.isConsistent) return null;

    final gray = _downscale(frame, tuning.targetWidth);
    if (gray == null) return null;

    final blurred = _blur(gray);
    final magnitude = _sobel(blurred);
    final thresholds = _edgeThresholds(magnitude, blurred, tuning);
    final component = _largestEdgeComponent(
      magnitude,
      blurred,
      thresholds,
      tuning,
    );
    if (component == null) return null;

    final hull = _convexHull(component);
    if (hull.length < 4) return null;

    final corners = _reduceToQuad(hull);
    final quad = DocumentQuad.fromPoints([
      for (final p in corners)
        UnitPoint((p.x + 0.5) / blurred.width, (p.y + 0.5) / blurred.height),
    ]);
    if (quad == null) return null;
    if (!quad.isValid(minArea: tuning.minAreaFraction)) return null;

    // A thin wedge — caused by a shadow or binding collapsing one side of the
    // detection — is not a page. Reject it so the guide draws nothing rather
    // than highlighting the wrong region.
    final rect = quad.boundingRect;
    final rectArea = (rect.right - rect.left) * (rect.bottom - rect.top);
    if (rectArea > 0 && quad.area / rectArea < tuning.minRectangularity) {
      return null;
    }

    // A quad hugging every border is the frame itself (or the desk filling the
    // view), not a page lying on something.
    final margin = tuning.borderMarginFraction;
    if (rect.left <= margin &&
        rect.top <= margin &&
        rect.right >= 1 - margin &&
        rect.bottom >= 1 - margin) {
      return null;
    }

    return quad;
  }

  // ── 1 · Downscale ────────────────────────────────────────────────────────
  //
  // Nearest-neighbour sampling, not a box average: averaging would read every
  // one of the sensor's ~1M pixels per frame, while sampling reads only the
  // ~19k it keeps. The blur that follows takes care of the noise that costs
  // us. Honours `bytesPerRow` — a plane's stride is not its width, and reading
  // as if it were is what shears the image.

  static _Gray? _downscale(CameraFrame frame, int targetWidth) {
    final step = math.max(1.0, frame.width / targetWidth);
    final width = (frame.width / step).floor();
    final height = (frame.height / step).floor();
    if (width < 3 || height < 3) return null;

    final isBgra = frame.format == CameraFrameFormat.bgra8888;
    final bytesPerPixel = isBgra ? 4 : 1;
    final pixels = Uint8List(width * height);
    final bytes = frame.bytes;

    for (var y = 0; y < height; y++) {
      final srcRow = (y * step).floor() * frame.bytesPerRow;
      final dstRow = y * width;
      for (var x = 0; x < width; x++) {
        final offset = srcRow + (x * step).floor() * bytesPerPixel;
        if (isBgra) {
          final b = bytes[offset];
          final g = bytes[offset + 1];
          final r = bytes[offset + 2];
          pixels[dstRow + x] = (0.299 * r + 0.587 * g + 0.114 * b).round();
        } else {
          pixels[dstRow + x] = bytes[offset];
        }
      }
    }

    return _Gray(pixels, width, height);
  }

  // ── 2 · Blur ─────────────────────────────────────────────────────────────
  //
  // One 3×3 box blur, run as two 1-D passes. Kills the sensor noise that
  // sampling let through, and softens printed text enough that it stops
  // competing with the page's own outline.

  static _Gray _blur(_Gray source) {
    final width = source.width;
    final height = source.height;
    final horizontal = Uint8List(width * height);
    final result = Uint8List(width * height);

    for (var y = 0; y < height; y++) {
      final row = y * width;
      for (var x = 0; x < width; x++) {
        final left = source.pixels[row + (x == 0 ? 0 : x - 1)];
        final centre = source.pixels[row + x];
        final right = source.pixels[row + (x == width - 1 ? x : x + 1)];
        horizontal[row + x] = (left + centre + right) ~/ 3;
      }
    }

    for (var y = 0; y < height; y++) {
      final row = y * width;
      final above = (y == 0 ? 0 : y - 1) * width;
      final below = (y == height - 1 ? y : y + 1) * width;
      for (var x = 0; x < width; x++) {
        result[row + x] =
            (horizontal[above + x] +
                horizontal[row + x] +
                horizontal[below + x]) ~/
            3;
      }
    }

    return _Gray(result, width, height);
  }

  // ── 3 · Sobel ────────────────────────────────────────────────────────────
  //
  // Gradient magnitude as |gx| + |gy| — the L1 length, not the Euclidean one:
  // the threshold that follows is relative anyway, and this saves a square
  // root per pixel. The one-pixel border is left at zero.

  static Int32List _sobel(_Gray source) {
    final width = source.width;
    final height = source.height;
    final pixels = source.pixels;
    final magnitude = Int32List(width * height);

    for (var y = 1; y < height - 1; y++) {
      final row = y * width;
      final above = row - width;
      final below = row + width;
      for (var x = 1; x < width - 1; x++) {
        final tl = pixels[above + x - 1];
        final tc = pixels[above + x];
        final tr = pixels[above + x + 1];
        final ml = pixels[row + x - 1];
        final mr = pixels[row + x + 1];
        final bl = pixels[below + x - 1];
        final bc = pixels[below + x];
        final br = pixels[below + x + 1];

        final gx = (tr + 2 * mr + br) - (tl + 2 * ml + bl);
        final gy = (bl + 2 * bc + br) - (tl + 2 * tc + tr);
        magnitude[row + x] = gx.abs() + gy.abs();
      }
    }

    return magnitude;
  }

  // ── 4 · Binarise (Canny-style hysteresis) ─────────────────────────────────
  //
  // Two thresholds, not one: the high cut seeds connected components, and the
  // low cut lets them grow through weaker — but still real — edges. This is
  // what prevents a shadow's strong gradient from suppressing weaker page
  // edges on the far side of the frame: those edges sit above the low bar and
  // connect to the page outline through the strong ones.

  static ({int high, int low}) _edgeThresholds(
    Int32List magnitude,
    _Gray shape,
    DetectorTuning tuning,
  ) {
    final histogram = Int32List(256);
    var total = 0;
    for (var y = 1; y < shape.height - 1; y++) {
      final row = y * shape.width;
      for (var x = 1; x < shape.width - 1; x++) {
        final bucket = math.min(255, magnitude[row + x] >> 3);
        histogram[bucket]++;
        total++;
      }
    }
    if (total == 0) {
      return (high: tuning.minEdgeMagnitude, low: tuning.minEdgeMagnitude);
    }

    int percentileFromTop(double percentile) {
      final wanted = ((1 - percentile) * total).round();
      var seen = 0;
      var bucket = 255;
      while (bucket > 0 && seen < wanted) {
        seen += histogram[bucket];
        bucket--;
      }
      return math.max(bucket << 3, tuning.minEdgeMagnitude);
    }

    return (
      high: percentileFromTop(tuning.edgePercentile),
      low: percentileFromTop(tuning.edgeLowPercentile),
    );
  }

  // ── 5 · Largest edge component (hysteresis growth) ───────────────────────
  //
  // Seeds are planted only where the gradient exceeds the HIGH threshold
  // ("definitely an edge"), but each seed's flood-fill grows through any pixel
  // above the LOW threshold ("possibly an edge, if connected"). This is the
  // Canny insight: a shadow line across the page raises the high bar and
  // suppresses far-away page edges under the old single cut, but those edges
  // survive the low bar and connect through the page outline to the strong
  // seed — so the full page contour ends up in one component, with the shadow
  // line as an interior detail the convex hull absorbs harmlessly.
  //
  // Iterative, with an explicit stack — a recursive fill would overflow on a
  // full-frame edge.

  static List<_P>? _largestEdgeComponent(
    Int32List magnitude,
    _Gray shape,
    ({int high, int low}) thresholds,
    DetectorTuning tuning,
  ) {
    final width = shape.width;
    final height = shape.height;
    final visited = Uint8List(width * height);
    final stack = <int>[];
    List<_P>? best;

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final seed = y * width + x;
        if (visited[seed] == 1) continue;
        // Only strong edges may start a component.
        if (magnitude[seed] < thresholds.high) continue;

        final component = <_P>[];
        visited[seed] = 1;
        stack.add(seed);
        while (stack.isNotEmpty) {
          final index = stack.removeLast();
          final px = index % width;
          final py = index ~/ width;
          component.add(_P(px, py));

          for (var dy = -1; dy <= 1; dy++) {
            final ny = py + dy;
            if (ny < 1 || ny > height - 2) continue;
            for (var dx = -1; dx <= 1; dx++) {
              final nx = px + dx;
              if (nx < 1 || nx > width - 2) continue;
              final neighbour = ny * width + nx;
              if (visited[neighbour] == 1) continue;
              // Grow through the LOW threshold — weaker page edges survive.
              if (magnitude[neighbour] < thresholds.low) continue;
              visited[neighbour] = 1;
              stack.add(neighbour);
            }
          }
        }

        if (best == null || component.length > best.length) best = component;
      }
    }

    if (best == null || best.length < tuning.minComponentPixels) return null;
    return best;
  }

  // ── 6 · Convex hull ──────────────────────────────────────────────────────
  //
  // Andrew's monotone chain. Deterministic, O(n log n), and it discards the
  // component's interior — all we want is the outline it traces.

  static List<_P> _convexHull(List<_P> points) {
    final sorted = [...points]
      ..sort((a, b) => a.x == b.x ? a.y.compareTo(b.y) : a.x.compareTo(b.x));

    List<_P> half(Iterable<_P> input) {
      final chain = <_P>[];
      for (final p in input) {
        while (chain.length >= 2 &&
            _cross(chain[chain.length - 2], chain.last, p) <= 0) {
          chain.removeLast();
        }
        chain.add(p);
      }
      chain.removeLast();
      return chain;
    }

    final lower = half(sorted);
    final upper = half(sorted.reversed);
    return [...lower, ...upper];
  }

  static int _cross(_P o, _P a, _P b) =>
      (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

  // ── 7 · Hull → four corners ──────────────────────────────────────────────
  //
  // Drop the hull vertex whose removal costs the least area, over and over,
  // until four remain. No RANSAC and no random seed, so the same frame always
  // gives the same quad.

  static List<_P> _reduceToQuad(List<_P> hull) {
    final corners = [...hull];
    while (corners.length > 4) {
      var cheapest = 0;
      var cheapestLoss = double.infinity;
      for (var i = 0; i < corners.length; i++) {
        final previous = corners[(i - 1 + corners.length) % corners.length];
        final next = corners[(i + 1) % corners.length];
        final loss = _cross(previous, corners[i], next).abs() / 2;
        if (loss < cheapestLoss) {
          cheapestLoss = loss;
          cheapest = i;
        }
      }
      corners.removeAt(cheapest);
    }
    return corners;
  }
}

/// A single-channel brightness image, sized in its own pixels.
final class _Gray {
  const _Gray(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;
}

/// An integer pixel coordinate inside the downscaled image.
final class _P {
  const _P(this.x, this.y);

  final int x;
  final int y;
}
