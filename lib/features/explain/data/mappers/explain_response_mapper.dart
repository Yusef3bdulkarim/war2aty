import '../../../../core/papers/paper_caution.dart';
import '../../../../core/papers/paper_contact.dart';
import '../../../../core/papers/paper_date.dart';
import '../../../../core/papers/paper_explanation.dart';
import '../../../../core/papers/paper_place.dart';
import '../../../../core/papers/paper_status.dart';
import '../../../../core/papers/paper_todo.dart';
import '../models/explain_response_dto.dart';

final class ExplainMappingException implements Exception {
  const ExplainMappingException(this.field);

  final String field;

  @override
  String toString() => 'ExplainMappingException($field)';
}

extension ExplainResponseMapper on ExplainResponseDto {
  PaperExplanation toDomain() {
    return PaperExplanation(
      title: paper.title,
      status: _status(status),
      paragraphs: explain,
      todo: PaperTodo(required: todo.required, text: todo.text),
      date: _toPaperDate(date),
      caution: caution == null ? null : PaperCaution(text: caution!.text),
      contact: contact == null
          ? null
          : PaperContact(name: contact!.name, phone: contact!.phone),
      place: place == null ? null : PaperPlace(text: place!.text),
    );
  }
}

PaperDate? _toPaperDate(ExplainDateDto? dto) {
  if (dto == null) return null;
  return PaperDate(
    day: _date(dto.date, 'date.date'),
    time: _time(dto.time, 'date.time'),
    text: dto.text,
  );
}

PaperStatus _status(String raw) =>
    _statuses[raw] ?? (throw const ExplainMappingException('status'));

DateTime _date(String raw, String field) {
  final match = _datePattern.firstMatch(raw);
  if (match == null) throw ExplainMappingException(field);

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw ExplainMappingException(field);
  }
  return parsed;
}

PaperTime? _time(String? raw, String field) {
  if (raw == null) return null;

  final match = _timePattern.firstMatch(raw);
  if (match == null) throw ExplainMappingException(field);

  return PaperTime(
    hour: int.parse(match.group(1)!),
    minute: int.parse(match.group(2)!),
  );
}

final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _timePattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

const _statuses = <String, PaperStatus>{
  'success': PaperStatus.success,
  'partial': PaperStatus.partial,
  'unsupported': PaperStatus.unsupported,
};
