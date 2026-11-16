import '../utils/list_equality.dart';
import 'paper_caution.dart';
import 'paper_contact.dart';
import 'paper_date.dart';
import 'paper_place.dart';
import 'paper_status.dart';
import 'paper_todo.dart';

final class PaperExplanation {
  PaperExplanation({
    required this.title,
    required this.status,
    required List<String> paragraphs,
    required this.todo,
    this.date,
    this.caution,
    this.contact,
    this.place,
  }) : paragraphs = List.unmodifiable(paragraphs);

  final String title;
  final PaperStatus status;
  final List<String> paragraphs;
  final PaperTodo todo;
  final PaperDate? date;
  final PaperCaution? caution;
  final PaperContact? contact;
  final PaperPlace? place;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperExplanation &&
          other.title == title &&
          other.status == status &&
          listEquals(other.paragraphs, paragraphs) &&
          other.todo == todo &&
          other.date == date &&
          other.caution == caution &&
          other.contact == contact &&
          other.place == place;

  @override
  int get hashCode => Object.hash(
    title,
    status,
    Object.hashAll(paragraphs),
    todo,
    date,
    caution,
    contact,
    place,
  );

  @override
  String toString() =>
      'PaperExplanation($status, ${paragraphs.length} paragraphs, '
      'date: ${date != null}, caution: ${caution != null}, '
      'contact: ${contact != null}, place: ${place != null})';
}
