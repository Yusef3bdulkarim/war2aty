import '../entities/reference_candidate.dart';

/// Extracts reference/account/invoice number candidates from normalized
/// OCR text.
///
/// Strategy: find Arabic keywords (رقم الحساب, رقم الفاتورة, etc.)
/// followed by an alphanumeric sequence of 4+ characters. All candidates
/// are flagged ambiguous — reference formats vary too widely to validate.
///
/// Pure Dart, no external dependencies.
final class ReferenceExtractor {
  const ReferenceExtractor();

  List<ReferenceCandidate> extract(String text) {
    final candidates = <ReferenceCandidate>[];
    final seen = <String>{};

    for (final match in _referencePattern.allMatches(text)) {
      final value = match.group(1)?.trim();
      if (value == null || value.length < 4) continue;
      if (!seen.add(value)) continue;

      candidates.add(
        ReferenceCandidate(rawText: match.group(0)!, value: value),
      );
    }

    return candidates;
  }

  static const _keywords = [
    'رقم الحساب',
    'رقم حساب',
    'رقم الفاتورة',
    'رقم فاتورة',
    'رقم مرجعي',
    'رقم المرجع',
    'رقم الإيصال',
    'رقم الايصال',
    'رقم إيصال',
    'رقم ايصال',
    'رقم الحجز',
    'رقم حجز',
    'رقم العملية',
    'رقم عملية',
    'رقم المعاملة',
    'كود',
    'Ref',
    'REF',
    'Invoice',
    'Account',
    'Booking',
    'Transaction',
  ];

  static final _referencePattern = RegExp(
    '(?:${_keywords.join('|')})'
    r'[\s:#]*'
    r'([A-Za-z0-9][\w\-/]*[A-Za-z0-9]|\d{4,})',
    caseSensitive: false,
  );
}
