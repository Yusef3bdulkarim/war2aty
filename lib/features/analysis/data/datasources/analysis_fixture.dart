/// The canned analyze-document responses bundled with the app (F05-T08).
///
/// They back the mock datasource, so the result screen can be built and
/// demoed before Groq is wired up — contract first, integration second. Each
/// value names a file under `assets/fixtures/analysis/`.
enum AnalysisFixture {
  /// Electricity bill — the vertical slice. Full success, deadline + amounts.
  invoice,

  /// Medical appointment. A date that carries a time, and a medical warning.
  appointment,

  /// Tax notice. Required documents and instructions, no amounts.
  government,

  /// Exam result. Inferred key information, an event date.
  exam,

  /// `status: "partial"` — low-confidence fields and a non-empty
  /// `missing_fields`, for the «راجع المعلومة» banner.
  partial,

  /// `status: "unsupported"` — everything empty, for the OCR-only fallback.
  unsupported;

  String get assetPath => 'assets/fixtures/analysis/$name.json';
}
