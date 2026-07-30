/// Outcome of one analysis run — API_CONTRACT §30.4.
enum AnalysisStatus {
  /// Full analysis completed; show every section normally.
  success,

  /// Completed, but some fields are uncertain or missing. The result screen
  /// shows the `missingFields` banner alongside the normal sections.
  partial,

  /// The document type isn't supported, or the text was too garbled to read.
  ///
  /// The repository turns this into an `UnsupportedDocumentFailure` so the
  /// result screen can offer the OCR-only fallback. It is **not** counted
  /// against the daily limit.
  unsupported,
}
