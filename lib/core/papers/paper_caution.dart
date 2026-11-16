final class PaperCaution {
  const PaperCaution({required this.text});

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PaperCaution && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'PaperCaution(${text.length} chars)';
}
