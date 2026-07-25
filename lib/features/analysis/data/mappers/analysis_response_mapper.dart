import '../../domain/entities/analysis_amount.dart';
import '../../domain/entities/analysis_date.dart';
import '../../domain/entities/analysis_status.dart';
import '../../domain/entities/analysis_summary.dart';
import '../../domain/entities/analysis_warning.dart';
import '../../domain/entities/confidence_band.dart';
import '../../domain/entities/document_analysis.dart';
import '../../domain/entities/document_kind.dart';
import '../../domain/entities/key_information.dart';
import '../../domain/entities/required_action.dart';
import '../models/analysis_response_dto.dart';

/// Raised when a wire value can't be expressed as a domain value.
///
/// Carries the offending **field name only** — never the value, which is
/// document content (privacy §7). The repository catches it and returns
/// `InvalidAnalysisResponseFailure`; nothing above the data layer sees it.
final class AnalysisMappingException implements Exception {
  const AnalysisMappingException(this.field);

  /// Dotted path of the field that couldn't be mapped, e.g. `dates[0].role`.
  final String field;

  @override
  String toString() => 'AnalysisMappingException($field)';
}

/// DTO → domain for the analyze-document success body.
///
/// ## Unknown wire values
///
/// The Edge Function constrains the model to the schema, so an unrecognised
/// value is a contract violation rather than something the user did. Two
/// responses are possible, and which one applies is deliberate per field:
///
/// * **Fall back** where the contract defines a catch-all (`document_type`,
///   `warnings[].type`), or where one value is strictly more cautious than the
///   others — an unknown confidence becomes [ConfidenceBand.low] and an unknown
///   `source`/`basis` becomes "inferred", so the UI flags the field for review
///   instead of presenting it as fact.
/// * **Throw** where guessing would put words in the document's mouth:
///   `status` drives the whole screen, and `dates[].role` is the only thing
///   that marks a date as a deadline — silently downgrading one to a generic
///   event could cost the user a payment.
extension AnalysisResponseMapper on AnalysisResponseDto {
  DocumentAnalysis toDomain() {
    return DocumentAnalysis(
      sessionId: sessionId,
      status: _status(status),
      kind: _kinds[documentType.type] ?? DocumentKind.other,
      title: documentType.title,
      kindConfidence: _confidence(documentType.confidence),
      summary: AnalysisSummary(
        short: summary.short,
        detailed: summary.detailed,
      ),
      keyInformation: [
        for (final item in keyInformation)
          KeyInformation(
            label: item.label,
            value: item.value,
            confidence: _confidence(item.confidence),
            source: _sources[item.source] ?? InfoSource.inferred,
          ),
      ],
      dates: [
        for (final (index, item) in dates.indexed)
          AnalysisDate(
            label: item.label,
            date: _date(item.date, 'dates[$index].date'),
            time: _time(item.time, 'dates[$index].time'),
            role:
                _roles[item.role] ??
                (throw AnalysisMappingException('dates[$index].role')),
            isReminderWorthy: item.isReminderWorthy,
            confidence: _confidence(item.confidence),
          ),
      ],
      amounts: [
        for (final item in amounts)
          AnalysisAmount(
            label: item.label,
            value: item.value,
            currency: item.currency,
            confidence: _confidence(item.confidence),
          ),
      ],
      actions: [
        for (final item in actionsRequired)
          RequiredAction(
            description: item.description,
            basis: _bases[item.basis] ?? ActionBasis.inferred,
            priority: _priorities[item.priority] ?? ActionPriority.normal,
          ),
      ],
      requiredDocuments: List.of(requiredDocuments),
      instructions: List.of(instructions),
      warnings: [
        for (final item in warnings)
          AnalysisWarning(
            text: item.text,
            kind: _warningKinds[item.type] ?? WarningKind.general,
          ),
      ],
      missingFields: List.of(missingFields),
    );
  }
}

AnalysisStatus _status(String raw) =>
    _statuses[raw] ?? (throw const AnalysisMappingException('status'));

/// Unknown bands read as [ConfidenceBand.low] so the value is shown as a
/// «قراءة غير مؤكدة» rather than as fact.
ConfidenceBand _confidence(String raw) =>
    _confidences[raw] ?? ConfidenceBand.low;

/// Parses `yyyy-MM-dd` into a local-midnight [DateTime].
///
/// Stricter than [DateTime.parse], which silently rolls overflowing values
/// (`2024-13-45` → 2025-02-14) — a wrong deadline is worse than no result.
DateTime _date(String raw, String field) {
  final match = _datePattern.firstMatch(raw);
  if (match == null) throw AnalysisMappingException(field);

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw AnalysisMappingException(field);
  }
  return parsed;
}

/// Parses `HH:mm`. A null [raw] means the paper gave no time — not an error.
AnalysisTime? _time(String? raw, String field) {
  if (raw == null) return null;

  final match = _timePattern.firstMatch(raw);
  if (match == null) throw AnalysisMappingException(field);

  return AnalysisTime(
    hour: int.parse(match.group(1)!),
    minute: int.parse(match.group(2)!),
  );
}

final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _timePattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

const _statuses = <String, AnalysisStatus>{
  'success': AnalysisStatus.success,
  'partial': AnalysisStatus.partial,
  'unsupported': AnalysisStatus.unsupported,
};

const _confidences = <String, ConfidenceBand>{
  'high': ConfidenceBand.high,
  'medium': ConfidenceBand.medium,
  'low': ConfidenceBand.low,
};

const _kinds = <String, DocumentKind>{
  'invoice': DocumentKind.invoice,
  'receipt': DocumentKind.receipt,
  'appointment': DocumentKind.appointment,
  'government': DocumentKind.government,
  'exam': DocumentKind.exam,
  'medical': DocumentKind.medical,
  'legal': DocumentKind.legal,
  'financial': DocumentKind.financial,
  'educational': DocumentKind.educational,
  'other': DocumentKind.other,
};

const _roles = <String, DateRole>{
  'deadline': DateRole.deadline,
  'appointment': DateRole.appointment,
  'issued': DateRole.issued,
  'expiry': DateRole.expiry,
  'event': DateRole.event,
  'period_start': DateRole.periodStart,
  'period_end': DateRole.periodEnd,
};

const _sources = <String, InfoSource>{
  'extracted': InfoSource.extracted,
  'inferred': InfoSource.inferred,
};

const _bases = <String, ActionBasis>{
  'explicit': ActionBasis.explicit,
  'inferred': ActionBasis.inferred,
};

const _priorities = <String, ActionPriority>{
  'high': ActionPriority.high,
  'normal': ActionPriority.normal,
};

const _warningKinds = <String, WarningKind>{
  'medical': WarningKind.medical,
  'legal': WarningKind.legal,
  'government': WarningKind.government,
  'financial': WarningKind.financial,
  'general': WarningKind.general,
};
