/// Which analysis pipeline a capture should take (F13 locked decision #1).
///
/// Decided once, proactively, before processing starts — never re-decided
/// mid-flow. [online] never silently falls back to [offline] on a later
/// failure (F13 locked decision #2/T16); it fails and the user retries.
enum AnalysisRoute {
  /// Rotate → perspective-correct → quality-check → Azure/Google → Groq.
  online,

  /// Tesseract → Dart extractors → Groq only. Genuine no-connectivity path.
  offline,
}
