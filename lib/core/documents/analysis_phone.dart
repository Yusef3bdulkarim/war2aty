final class AnalysisPhone {
  const AnalysisPhone({
    required this.rawValue,
    required this.value,
    required this.needsUserReview,
  });

  final String rawValue;
  final String value;
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

  @override
  String toString() => 'AnalysisPhone(needsUserReview=$needsUserReview)';
}
