/// The knobs of the live edge detector, in one injectable place.
///
/// Every threshold the algorithm uses lives here rather than as a literal
/// inside it, so tests can pin exact values and the perf/device passes
/// (F16-T09/T10) can retune without touching the algorithm — and so a retune is
/// a one-line diff that is obvious in review.
final class DetectorTuning {
  const DetectorTuning({
    this.targetWidth = 160,
    this.edgePercentile = 0.92,
    this.minEdgeMagnitude = 32,
    this.minAreaFraction = 0.08,
    this.minComponentPixels = 40,
    this.borderMarginFraction = 0.02,
  });

  /// Frames are sampled down to roughly this width before any pixel work. The
  /// height follows the frame's own aspect, so ~160×120 on a 4:3 feed. Small
  /// enough to be cheap, big enough for a page edge to survive.
  final int targetWidth;

  /// Gradient magnitudes above this percentile count as an edge. A percentile
  /// rather than a fixed level, so the same code copes with a bright desk and
  /// a dim room without a per-scene threshold.
  final double edgePercentile;

  /// The floor the percentile cut may never go below, on the Sobel L1 scale.
  ///
  /// A percentile alone always nominates *something* as an edge, so a flat
  /// frame — a bare desk, a white page on a near-white surface — would hand
  /// its own sensor noise to the rest of the pipeline. This is what makes "no
  /// document here" an outcome the detector can actually reach, and it is the
  /// constant that decides how much page-vs-background contrast is enough.
  final int minEdgeMagnitude;

  /// The smallest share of the frame a quad may cover and still be treated as
  /// a document. Guards against locking onto a stamp, a logo, or a phone-sized
  /// reflection.
  final double minAreaFraction;

  /// Edge components smaller than this are noise or text, not a page outline.
  final int minComponentPixels;

  /// A quad whose corners all sit within this fraction of the frame's border
  /// is the desk or the frame itself, not a page lying on it.
  final double borderMarginFraction;
}
