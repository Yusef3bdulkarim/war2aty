import '../entities/phone_candidate.dart';

/// Extracts Egyptian phone number candidates from normalized OCR text.
///
/// Supports:
/// - Mobile: 11 digits starting with 010/011/012/015.
/// - International: +20 or 002 prefix followed by 10 digits.
/// - Whitespace tolerance: strips spaces, dashes, dots between digits before
///   validating (OCR frequently fragments long numbers).
///
/// Pure Dart, no external dependencies.
final class PhoneExtractor {
  const PhoneExtractor();

  List<PhoneCandidate> extract(String text) {
    final candidates = <PhoneCandidate>[];
    final seen = <String>{};

    for (final match in _phonePattern.allMatches(text)) {
      final candidate = _parse(match);
      if (candidate != null && seen.add(candidate.normalizedNumber)) {
        candidates.add(candidate);
      }
    }

    return candidates;
  }

  // Matches digit sequences of 10-15 chars (after stripping separators),
  // optionally preceded by + or 00. Allows spaces/dashes/dots between
  // digit groups.
  static final _phonePattern = RegExp(
    r'(?:\+|00)?'
    r'(?:\d[\s\-\.]*){10,15}',
  );

  static final _validMobilePrefixes = {'010', '011', '012', '015'};

  static PhoneCandidate? _parse(RegExpMatch match) {
    final raw = match.group(0)!;
    final digitsOnly = raw.replaceAll(RegExp(r'[^\d]'), '');

    // International format: +20xxxxxxxxxx or 002xxxxxxxxxx
    if (digitsOnly.startsWith('20') && digitsOnly.length == 12) {
      final local = '0${digitsOnly.substring(2)}';
      if (_isValidEgyptianMobile(local)) {
        return PhoneCandidate(
          rawText: raw.trim(),
          normalizedNumber: local,
          isAmbiguous: raw.contains(RegExp(r'\s')),
        );
      }
    }
    if (digitsOnly.startsWith('002') && digitsOnly.length == 14) {
      final local = '0${digitsOnly.substring(4)}';
      if (_isValidEgyptianMobile(local)) {
        return PhoneCandidate(
          rawText: raw.trim(),
          normalizedNumber: local,
          isAmbiguous: raw.contains(RegExp(r'\s')),
        );
      }
    }

    // Local format: 0xxxxxxxxxx (11 digits)
    if (digitsOnly.length == 11 && _isValidEgyptianMobile(digitsOnly)) {
      return PhoneCandidate(
        rawText: raw.trim(),
        normalizedNumber: digitsOnly,
        isAmbiguous: raw.trim().contains(RegExp(r'\s')),
      );
    }

    return null;
  }

  static bool _isValidEgyptianMobile(String digits) {
    if (digits.length != 11) return false;
    final prefix = digits.substring(0, 3);
    return _validMobilePrefixes.contains(prefix);
  }
}
