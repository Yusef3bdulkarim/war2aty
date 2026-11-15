final class PaperContact {
  const PaperContact({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperContact && other.name == name && other.phone == phone;

  @override
  int get hashCode => Object.hash(name, phone);

  @override
  String toString() =>
      'PaperContact(${name.length} chars, ${phone.length} digits)';
}
