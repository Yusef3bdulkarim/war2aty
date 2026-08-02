import '../../../../core/documents/document_category.dart';
import '../../../../core/utils/list_equality.dart';
import 'analysis_amount.dart';
import 'analysis_date.dart';
import 'analysis_phone.dart';
import 'analysis_reference.dart';
import 'analysis_status.dart';
import 'analysis_summary.dart';
import 'analysis_warning.dart';
import 'confidence_band.dart';
import 'document_kind.dart';
import 'key_information.dart';
import 'required_action.dart';

/// Everything the analysis understood about one paper.
///
/// The domain counterpart of the analyze-document response (API_CONTRACT §30),
/// and the single input to the result screen. Built by the mapper (F05-T06)
/// after the validator has vetted the payload (F05-T07) — by the time an
/// instance exists, every enum is known and every list is present.
///
/// Pure Dart, no Flutter import.
final class DocumentAnalysis {
  const DocumentAnalysis({
    required this.sessionId,
    required this.status,
    required this.kind,
    required this.title,
    required this.kindConfidence,
    required this.summary,
    this.keyInformation = const [],
    this.dates = const [],
    this.amounts = const [],
    this.phones = const [],
    this.references = const [],
    this.actions = const [],
    this.requiredDocuments = const [],
    this.instructions = const [],
    this.warnings = const [],
    this.missingFields = const [],
  });

  /// Ties the result back to the capture session it came from. A per-run id —
  /// not an identifier for the user or the device.
  final String sessionId;

  final AnalysisStatus status;

  final DocumentKind kind;

  /// Arabic display title the analysis wrote, e.g. «فاتورة كهرباء».
  final String title;

  /// How sure the analysis is about [kind] and [title] — not about the fields
  /// below, which each carry their own band.
  final ConfidenceBand kindConfidence;

  final AnalysisSummary summary;

  final List<KeyInformation> keyInformation;
  final List<AnalysisDate> dates;
  final List<AnalysisAmount> amounts;

  /// New in API_CONTRACT §30 v2 (F13-T17). Empty unless cross-provider
  /// verification ran server-side.
  final List<AnalysisPhone> phones;

  /// New in API_CONTRACT §30 v2 (F13-T17). Empty unless cross-provider
  /// verification ran server-side.
  final List<AnalysisReference> references;

  final List<RequiredAction> actions;

  /// Papers the user has to bring along, e.g. «بطاقة الرقم القومي».
  final List<String> requiredDocuments;

  /// Step-by-step guidance in Arabic.
  final List<String> instructions;

  final List<AnalysisWarning> warnings;

  /// Fields the analysis couldn't resolve. Non-empty only when [status] is
  /// [AnalysisStatus.partial]; drives the «راجع المعلومة» banner.
  final List<String> missingFields;

  /// The coarse category Home's recent strip and the documents filters use.
  DocumentCategory get category => kind.category;

  /// Whether some of this result is uncertain and the user should be told.
  bool get isPartial => status == AnalysisStatus.partial;

  /// Dates the analysis suggests reminding about, in the order it reported
  /// them. Nothing is scheduled until the user reviews these.
  List<AnalysisDate> get reminderCandidates =>
      dates.where((d) => d.isReminderWorthy).toList(growable: false);

  /// Whether any field anywhere in the result is below [ConfidenceBand.high],
  /// or any phone/reference is flagged [AnalysisPhone.needsUserReview] /
  /// [AnalysisReference.needsUserReview] — the parity between the two is
  /// deliberate (F13-T17): `needsUserReview` is phones/references' one and
  /// only trust signal, playing the same role [ConfidenceBand] plays for
  /// dates and amounts (locked decision #5).
  ///
  /// Drives the document-level "راجع المعلومة" hint; individual fields still
  /// show their own band.
  bool get hasUncertainFields =>
      kindConfidence != ConfidenceBand.high ||
      keyInformation.any((i) => i.confidence != ConfidenceBand.high) ||
      dates.any((d) => d.confidence != ConfidenceBand.high) ||
      amounts.any((a) => a.confidence != ConfidenceBand.high) ||
      phones.any((p) => p.needsUserReview) ||
      references.any((r) => r.needsUserReview);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentAnalysis &&
          other.sessionId == sessionId &&
          other.status == status &&
          other.kind == kind &&
          other.title == title &&
          other.kindConfidence == kindConfidence &&
          other.summary == summary &&
          listEquals(other.keyInformation, keyInformation) &&
          listEquals(other.dates, dates) &&
          listEquals(other.amounts, amounts) &&
          listEquals(other.phones, phones) &&
          listEquals(other.references, references) &&
          listEquals(other.actions, actions) &&
          listEquals(other.requiredDocuments, requiredDocuments) &&
          listEquals(other.instructions, instructions) &&
          listEquals(other.warnings, warnings) &&
          listEquals(other.missingFields, missingFields);

  @override
  int get hashCode => Object.hash(
    sessionId,
    status,
    kind,
    title,
    kindConfidence,
    summary,
    Object.hashAll(keyInformation),
    Object.hashAll(dates),
    Object.hashAll(amounts),
    Object.hashAll(phones),
    Object.hashAll(references),
    Object.hashAll(actions),
    Object.hashAll(requiredDocuments),
    Object.hashAll(instructions),
    Object.hashAll(warnings),
    Object.hashAll(missingFields),
  );

  // Contents omitted on purpose — entity toStrings reach logs and error
  // reports, and document contents must never be logged (privacy §7).
  @override
  String toString() =>
      'DocumentAnalysis($kind, $status, ${keyInformation.length} info, '
      '${dates.length} dates, ${amounts.length} amounts, '
      '${phones.length} phones, ${references.length} references)';
}
