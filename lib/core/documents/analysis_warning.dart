/// What kind of caution a warning carries — API_CONTRACT §30.3.
///
/// The kind drives the icon and tone in the UI; the Arabic text travels with
/// the warning itself.
enum WarningKind {
  /// «هذا التقرير لا يغني عن استشارة الطبيب»
  medical,

  /// «استشر محامي قبل اتخاذ أي إجراء قانوني»
  legal,

  /// «تأكد من صحة البيانات من الجهة الرسمية»
  government,

  /// «راجع البنك أو الجهة المالية للتأكيد»
  financial,

  /// Anything the analysis didn't classify.
  general,
}

/// A disclaimer the user must see alongside the result.
final class AnalysisWarning {
  const AnalysisWarning({required this.text, required this.kind});

  /// Arabic warning copy, ready to display.
  final String text;

  final WarningKind kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisWarning && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => 'AnalysisWarning($kind)';
}
