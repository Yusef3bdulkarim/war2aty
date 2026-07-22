/// How the user chose to bring a paper into the app.
///
/// F03 owns the two flows themselves — camera permission and capture, or the
/// system photo picker. This sits in the domain so the route can carry the
/// choice as plain data, without the router knowing anything about cameras.
enum CaptureSource {
  camera,
  gallery;

  /// Reads the value carried in a route's query string.
  ///
  /// Falls back to [camera] rather than throwing: a stale or hand-typed link
  /// should land the user on the primary action, not crash the app.
  static CaptureSource parse(String? value) => CaptureSource.values.firstWhere(
    (source) => source.name == value,
    orElse: () => CaptureSource.camera,
  );
}
