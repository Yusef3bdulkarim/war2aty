import 'action_item_dto.dart';
import 'amount_item_dto.dart';
import 'date_item_dto.dart';
import 'document_type_dto.dart';
import 'key_info_item_dto.dart';
import 'summary_dto.dart';
import 'warning_item_dto.dart';

/// Wire representation of the analyze-document success body (API_CONTRACT §30).
///
/// Enum-typed fields stay as raw strings here; widening them into domain enums
/// (and rejecting unknown values) is the mapper's job (F05-T06/T07).
final class AnalysisResponseDto {
  const AnalysisResponseDto({
    required this.schemaVersion,
    required this.sessionId,
    required this.status,
    required this.documentType,
    required this.summary,
    this.keyInformation = const [],
    this.dates = const [],
    this.amounts = const [],
    this.actionsRequired = const [],
    this.requiredDocuments = const [],
    this.instructions = const [],
    this.warnings = const [],
    this.missingFields = const [],
  });

  factory AnalysisResponseDto.fromJson(Map<String, dynamic> json) {
    return AnalysisResponseDto(
      schemaVersion: json['schema_version'] as String,
      sessionId: json['session_id'] as String,
      status: json['status'] as String,
      documentType: DocumentTypeDto.fromJson(
        json['document_type'] as Map<String, dynamic>,
      ),
      summary: SummaryDto.fromJson(json['summary'] as Map<String, dynamic>),
      keyInformation: _objectList(
        json['key_information'],
        KeyInfoItemDto.fromJson,
      ),
      dates: _objectList(json['dates'], DateItemDto.fromJson),
      amounts: _objectList(json['amounts'], AmountItemDto.fromJson),
      actionsRequired: _objectList(
        json['actions_required'],
        ActionItemDto.fromJson,
      ),
      requiredDocuments: _stringList(json['required_documents']),
      instructions: _stringList(json['instructions']),
      warnings: _objectList(json['warnings'], WarningItemDto.fromJson),
      missingFields: _stringList(json['missing_fields']),
    );
  }

  final String schemaVersion;
  final String sessionId;

  /// Raw wire enum — `success` | `partial` | `unsupported` (§30.4).
  final String status;
  final DocumentTypeDto documentType;
  final SummaryDto summary;
  final List<KeyInfoItemDto> keyInformation;
  final List<DateItemDto> dates;
  final List<AmountItemDto> amounts;
  final List<ActionItemDto> actionsRequired;
  final List<String> requiredDocuments;
  final List<String> instructions;
  final List<WarningItemDto> warnings;
  final List<String> missingFields;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'session_id': sessionId,
    'status': status,
    'document_type': documentType.toJson(),
    'summary': summary.toJson(),
    'key_information': keyInformation.map((e) => e.toJson()).toList(),
    'dates': dates.map((e) => e.toJson()).toList(),
    'amounts': amounts.map((e) => e.toJson()).toList(),
    'actions_required': actionsRequired.map((e) => e.toJson()).toList(),
    'required_documents': requiredDocuments,
    'instructions': instructions,
    'warnings': warnings.map((e) => e.toJson()).toList(),
    'missing_fields': missingFields,
  };
}

/// The schema declares `default: []` for every optional array, so an absent or
/// null key is an empty list rather than a parse failure.
List<T> _objectList<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw == null) return const [];
  return (raw as List<dynamic>)
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList();
}

List<String> _stringList(Object? raw) {
  if (raw == null) return const [];
  return (raw as List<dynamic>).map((e) => e as String).toList();
}
