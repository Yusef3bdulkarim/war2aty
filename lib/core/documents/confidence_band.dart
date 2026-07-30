/// How sure the analysis is about one piece of information.
///
/// Confidence is **per field**, never per document (privacy rule §7): a
/// high-confidence document can still carry a low-confidence amount, and the UI
/// must say so on that amount alone.
///
/// UI treatment is defined in API_CONTRACT §30.5 and applied in presentation —
/// this enum carries no copy.
enum ConfidenceBand {
  /// Display the value normally.
  high,

  /// Display with a «راجع المعلومة» badge.
  medium,

  /// Display with a «قراءة غير مؤكدة» warning; the value is editable.
  low,
}
