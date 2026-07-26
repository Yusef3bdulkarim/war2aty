import '../entities/normalized_ocr_text.dart';
import '../entities/ocr_result.dart';

/// Normalizes raw OCR text for downstream extraction and AI consumption.
///
/// Pure Dart — no external dependencies. Rules (from master plan §19):
/// 1. Arabic-Indic digits (٠-٩) → Western digits (0-9).
/// 2. Extended Arabic-Indic digits (۰-۹) → Western digits (0-9).
/// 3. Collapse runs of whitespace to a single space per line.
/// 4. Trim leading/trailing whitespace per line; drop blank lines.
/// 5. Unify common Arabic currency abbreviations to "EGP".
final class TextNormalizer {
  const TextNormalizer();

  NormalizedOcrText normalize(OcrResult result) {
    final original = result.originalText;
    var cleaned = original;

    cleaned = _replaceArabicIndicDigits(cleaned);
    cleaned = _unifyCurrencySymbols(cleaned);
    cleaned = _collapseWhitespace(cleaned);

    return NormalizedOcrText(originalText: original, cleanedText: cleaned);
  }

  /// ٠١٢٣٤٥٦٧٨٩ → 0123456789 and ۰۱۲۳۴۵۶۷۸۹ → 0123456789.
  static String _replaceArabicIndicDigits(String text) {
    final buffer = StringBuffer();
    for (final codeUnit in text.runes) {
      if (codeUnit >= 0x0660 && codeUnit <= 0x0669) {
        buffer.writeCharCode(codeUnit - 0x0660 + 0x30);
      } else if (codeUnit >= 0x06F0 && codeUnit <= 0x06F9) {
        buffer.writeCharCode(codeUnit - 0x06F0 + 0x30);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static final _currencyPattern = RegExp(r'(?:ج\.م\.?|جنيه\s*مصري|جنيه)');

  /// Unify Egyptian currency abbreviations to "EGP".
  static String _unifyCurrencySymbols(String text) {
    return text.replaceAll(_currencyPattern, 'EGP');
  }

  /// Collapse whitespace: runs of spaces/tabs → single space per line,
  /// trim each line, drop empty lines.
  static String _collapseWhitespace(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final cleaned = <String>[];
    for (final line in lines) {
      final trimmed = line.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
      if (trimmed.isNotEmpty) cleaned.add(trimmed);
    }
    return cleaned.join('\n');
  }
}
