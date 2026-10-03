/// What the open camera can do, as learned when it was opened (F24).
///
/// The viewfinder offers only what the phone actually has: no flash button on
/// a phone without a flash, no focus on a tap the lens cannot act on.
final class CameraCapabilities {
  const CameraCapabilities({required this.hasFlash, required this.canFocus});

  /// A camera that offers nothing beyond the shutter.
  static const CameraCapabilities none = CameraCapabilities(
    hasFlash: false,
    canFocus: false,
  );

  /// Whether the lens has a flash the shot can fire.
  final bool hasFlash;

  /// Whether the lens can focus on a chosen point of the frame.
  final bool canFocus;

  @override
  bool operator ==(Object other) =>
      other is CameraCapabilities &&
      other.hasFlash == hasFlash &&
      other.canFocus == canFocus;

  @override
  int get hashCode => Object.hash(hasFlash, canFocus);

  @override
  String toString() =>
      'CameraCapabilities(hasFlash: $hasFlash, canFocus: $canFocus)';
}
