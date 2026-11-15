final class PaperPlace {
  const PaperPlace({required this.text});

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PaperPlace && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'PaperPlace(${text.length} chars)';
}
