/// A single photo the user brought into the app — taken with the camera or
/// picked from the gallery.
///
/// The image stays on the device — this is only the path to a temporary file
/// inside the app's private storage, which later stages crop, quality-check,
/// and finally OCR. No bytes travel with it and nothing here ever leaves the
/// phone (privacy §7).
final class CapturedPhoto {
  const CapturedPhoto(this.path);

  /// Absolute path to the image file (a camera JPEG, or whatever format the
  /// gallery pick was — PNG, HEIC, …).
  final String path;

  @override
  bool operator ==(Object other) =>
      other is CapturedPhoto && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'CapturedPhoto($path)';
}
