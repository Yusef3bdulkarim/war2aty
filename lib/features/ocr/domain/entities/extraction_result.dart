import 'amount_candidate.dart';
import 'date_candidate.dart';
import 'normalized_ocr_text.dart';
import 'phone_candidate.dart';
import 'reference_candidate.dart';
import 'time_candidate.dart';

/// Aggregates the normalized text and all extracted candidates from one
/// OCR run.
///
/// This is the complete output of the local OCR + extraction pipeline,
/// ready for the review UI (T11/T13) and for F05 to build the analysis
/// request.
final class ExtractionResult {
  const ExtractionResult({
    required this.text,
    this.dates = const [],
    this.times = const [],
    this.amounts = const [],
    this.phones = const [],
    this.references = const [],
  });

  final NormalizedOcrText text;
  final List<DateCandidate> dates;
  final List<TimeCandidate> times;
  final List<AmountCandidate> amounts;
  final List<PhoneCandidate> phones;
  final List<ReferenceCandidate> references;

  /// Whether any candidate across all types is flagged ambiguous.
  bool get hasAmbiguousCandidates =>
      dates.any((c) => c.isAmbiguous) ||
      times.any((c) => c.isAmbiguous) ||
      amounts.any((c) => c.isAmbiguous) ||
      phones.any((c) => c.isAmbiguous) ||
      references.any((c) => c.isAmbiguous);

  /// Total number of candidates across all types.
  int get totalCandidates =>
      dates.length +
      times.length +
      amounts.length +
      phones.length +
      references.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractionResult &&
          other.text == text &&
          _listEquals(other.dates, dates) &&
          _listEquals(other.times, times) &&
          _listEquals(other.amounts, amounts) &&
          _listEquals(other.phones, phones) &&
          _listEquals(other.references, references);

  @override
  int get hashCode => Object.hash(
    text,
    Object.hashAll(dates),
    Object.hashAll(times),
    Object.hashAll(amounts),
    Object.hashAll(phones),
    Object.hashAll(references),
  );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ExtractionResult($totalCandidates candidates, '
      'ambiguous=$hasAmbiguousCandidates)';
}
