/// What kind of paper a document is.
///
/// Lives in `core/` because several features classify by it: Home's recent
/// strip, the documents list and its filters (F08), and the analysis result
/// (F07). Pure Dart — no Flutter, no storage types.
enum DocumentCategory {
  /// An appointment or booking, including medical ones.
  appointment,

  /// A bill or invoice.
  invoice,

  /// A government paper.
  government,

  /// A school or university paper.
  education,

  /// Anything the analysis could not place in the four above.
  other,
}
