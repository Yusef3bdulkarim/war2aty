/// A phone number found on the document (API_CONTRACT §30 v2, F13 locked
/// decision #6).
///
/// `verificationStatus` stays backend-only — [needsUserReview] is the only
/// cross-provider signal that reaches the client, and it is what the UI acts
/// on, the same way [ConfidenceBand] drives dates and amounts.
final class AnalysisPhone {
  const AnalysisPhone({
    required this.rawValue,
    required this.value,
    required this.needsUserReview,
  });

  /// The literal text this number was read from.
  final String rawValue;

  /// The normalized number.
  final String value;

  /// Whether the user should double-check this number before trusting it.
  final bool needsUserReview;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisPhone &&
          other.rawValue == rawValue &&
          other.value == value &&
          other.needsUserReview == needsUserReview;

  @override
  int get hashCode => Object.hash(rawValue, value, needsUserReview);

  // rawValue and value both omitted — document content, never logged (§7).
  @override
  String toString() => 'AnalysisPhone(needsUserReview=$needsUserReview)';
}
