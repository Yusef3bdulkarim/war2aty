final class PaperTodo {
  const PaperTodo({required this.required, required this.text});

  final bool required;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperTodo && other.required == required && other.text == text;

  @override
  int get hashCode => Object.hash(required, text);

  @override
  String toString() => 'PaperTodo(required: $required, ${text.length} chars)';
}
