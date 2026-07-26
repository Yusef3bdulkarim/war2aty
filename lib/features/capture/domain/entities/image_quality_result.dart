/// How sharp, bright, and high-resolution the captured image is.
///
/// Used both as the per-metric score and the overall verdict. The quality
/// assessment engine scores blur, resolution, and brightness independently,
/// then collapses them into a single [overall] via worst-wins.
enum ImageQuality { good, acceptable, poor }

/// The outcome of assessing a captured photo's suitability for OCR.
///
/// Carries the [overall] verdict (worst of the three metrics) plus the
/// individual scores so the UI can explain *why* the image is poor — e.g.
/// "الصورة غامقة" vs "الصورة مش واضحة".
final class ImageQualityResult {
  const ImageQualityResult({
    required this.overall,
    required this.blur,
    required this.resolution,
    required this.brightness,
  });

  final ImageQuality overall;
  final ImageQuality blur;
  final ImageQuality resolution;
  final ImageQuality brightness;

  @override
  bool operator ==(Object other) =>
      other is ImageQualityResult &&
      other.overall == overall &&
      other.blur == blur &&
      other.resolution == resolution &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(overall, blur, resolution, brightness);

  @override
  String toString() =>
      'ImageQualityResult($overall, blur=$blur, res=$resolution, bright=$brightness)';
}
