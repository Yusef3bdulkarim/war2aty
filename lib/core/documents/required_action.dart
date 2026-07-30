/// Whether the paper actually says to do this.
enum ActionBasis {
  /// Written on the document.
  explicit,

  /// Worked out by the analysis. The UI marks these so the user knows the
  /// paper didn't say it outright.
  inferred,
}

/// How prominently an action is shown.
enum ActionPriority { high, normal }

/// Something the user has to do about this paper.
final class RequiredAction {
  const RequiredAction({
    required this.description,
    required this.basis,
    required this.priority,
  });

  /// Arabic instruction, e.g. «سدد الفاتورة قبل 15 أبريل 2024.».
  final String description;

  final ActionBasis basis;
  final ActionPriority priority;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequiredAction &&
          other.description == description &&
          other.basis == basis &&
          other.priority == priority;

  @override
  int get hashCode => Object.hash(description, basis, priority);

  @override
  String toString() => 'RequiredAction($basis, $priority)';
}
