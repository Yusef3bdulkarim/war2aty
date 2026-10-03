/// The flash setting for the next shot (F24).
///
/// A flash, not a torch: it fires with the shutter and is dark while framing.
enum CameraFlashMode {
  off,

  /// The phone decides from the light at the moment of the shot.
  auto,
  on;

  /// The mode one tap on the flash button moves to: off → auto → on → off.
  CameraFlashMode get next => switch (this) {
    CameraFlashMode.off => CameraFlashMode.auto,
    CameraFlashMode.auto => CameraFlashMode.on,
    CameraFlashMode.on => CameraFlashMode.off,
  };
}
