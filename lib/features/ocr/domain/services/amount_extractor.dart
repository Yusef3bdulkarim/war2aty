import '../entities/amount_candidate.dart';

/// Extracts monetary amount candidates from normalized OCR text.
///
/// Two strategies:
/// 1. **Explicit currency** — a number adjacent to a recognized currency
///    marker (EGP, LE, $, €, USD, EUR). Not ambiguous.
/// 2. **Keyword-adjacent** — a number near Arabic money keywords
///    (إجمالي, المطلوب, القيمة, مبلغ, سعر, رسوم, ضريبة, خصم).
///    Flagged ambiguous.
///
/// Pure Dart, no external dependencies.
final class AmountExtractor {
  const AmountExtractor();

  List<AmountCandidate> extract(String text) {
    final candidates = <AmountCandidate>[];
    final usedRanges = <(int, int)>[];

    for (final match in _explicitCurrencyPattern.allMatches(text)) {
      final candidate = _parseExplicit(match);
      if (candidate != null) {
        candidates.add(candidate);
        usedRanges.add((match.start, match.end));
      }
    }

    for (final match in _keywordPattern.allMatches(text)) {
      if (_overlaps(match, usedRanges)) continue;
      final candidate = _parseKeywordAdjacent(match, text);
      if (candidate != null) candidates.add(candidate);
    }

    return candidates;
  }

  // ---------------------------------------------------------------------------
  // Explicit currency: number + currency marker (or marker + number)
  // ---------------------------------------------------------------------------

  static final _explicitCurrencyPattern = RegExp(
    r'(\d[\d,]*\.?\d*)\s*(EGP|LE|USD|\$|EUR|€)'
    r'|'
    r'(EGP|LE|USD|\$|EUR|€)\s*(\d[\d,]*\.?\d*)',
  );

  static AmountCandidate? _parseExplicit(RegExpMatch match) {
    final raw = match.group(0)!;
    final numberStr = match.group(1) ?? match.group(4);
    final currencyStr = match.group(2) ?? match.group(3);

    if (numberStr == null || currencyStr == null) return null;
    final value = _parseNumber(numberStr);
    if (value == null) return null;

    final currency = _normalizeCurrency(currencyStr);
    return AmountCandidate(rawText: raw, value: value, currency: currency);
  }

  // ---------------------------------------------------------------------------
  // Keyword-adjacent: Arabic money keyword near a number
  // ---------------------------------------------------------------------------

  static const _keywords = [
    'إجمالي',
    'اجمالي',
    'المطلوب',
    'القيمة',
    'المبلغ',
    'مبلغ',
    'سعر',
    'رسوم',
    'ضريبة',
    'خصم',
    'صافي',
    'المستحق',
    'قيمة',
    'تكلفة',
    'ثمن',
  ];

  static final _keywordPattern = RegExp(
    '(?:${_keywords.join('|')})'
    r'[\s:]*'
    r'(\d[\d,]*\.?\d*)',
  );

  static AmountCandidate? _parseKeywordAdjacent(
    RegExpMatch match,
    String text,
  ) {
    final raw = match.group(0)!;
    final numberStr = match.group(1);
    if (numberStr == null) return null;

    final value = _parseNumber(numberStr);
    if (value == null) return null;

    return AmountCandidate(rawText: raw, value: value, isAmbiguous: true);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static double? _parseNumber(String raw) {
    final cleaned = raw.replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  static String _normalizeCurrency(String raw) {
    return switch (raw) {
      'LE' || 'EGP' => 'EGP',
      r'$' || 'USD' => 'USD',
      '€' || 'EUR' => 'EUR',
      _ => raw,
    };
  }

  static bool _overlaps(RegExpMatch match, List<(int, int)> ranges) {
    for (final (start, end) in ranges) {
      if (match.start < end && match.end > start) return true;
    }
    return false;
  }
}
