final class AnalysisReference {
  const AnalysisReference({
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
      other is AnalysisReference &&
          other.rawValue == rawValue &&
          other.value == value &&
          other.needsUserReview == needsUserReview;

  @override
  int get hashCode => Object.hash(rawValue, value, needsUserReview);

  @override
  String toString() => 'AnalysisReference(needsUserReview=$needsUserReview)';
}
