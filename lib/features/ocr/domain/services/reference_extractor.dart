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

  // `(?![A-Za-z])` after the keyword alternation stops a short keyword like
  // "Ref"/"Account" from matching as a bare prefix inside a longer word (e.g.
  // "Ref" inside "Reference"), which previously left the rest of that word
  // ("erence") to be captured as the value.
  //
  // The optional `(?:Number|No\.?|ID)` group absorbs the common English
  // "<Keyword> Number:" phrasing ("Account Number:", "Reference Number:") —
  // without it, "Number" itself was captured as the value instead of the
  // number that follows it. Arabic keywords already embed "رقم" (number)
  // in the phrase itself, so this group is a no-op for them.
  //
  // `-` joins `[\s:#]` as a separator character so a directly-attached
  // reference like "REF-9948271" is still captured (previously the hyphen
  // stopped the match before it ever reached the digits).
  static final _referencePattern = RegExp(
    '(?:${_keywords.join('|')})(?![A-Za-z])'
    r'[\s:#\-]*(?:(?:Number|No\.?|ID)[\s:#\-]*)?'
    r'([A-Za-z0-9][\w\-/]*[A-Za-z0-9]|\d{4,})',
    caseSensitive: false,
  );
}
