import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/papers/paper_caution.dart';
import 'package:war2aty/core/papers/paper_contact.dart';
import 'package:war2aty/core/papers/paper_date.dart';
import 'package:war2aty/core/papers/paper_explanation.dart';
import 'package:war2aty/core/papers/paper_place.dart';
import 'package:war2aty/core/papers/paper_status.dart';
import 'package:war2aty/core/papers/paper_todo.dart';
import 'package:war2aty/core/papers/saved_paper.dart';

void main() {
  const sentence = 'فاتورة الكهربا بتاعتك 285 جنيه، آخر ميعاد 25 نوفمبر';
  const title = 'فاتورة الكهربا';

  final explanation = PaperExplanation(
    title: title,
    status: PaperStatus.success,
    paragraphs: [sentence],
    todo: const PaperTodo(required: true, text: sentence),
    date: PaperDate(day: DateTime(2026, 11, 25), text: sentence),
    caution: const PaperCaution(text: sentence),
    contact: const PaperContact(name: sentence, phone: '0453312244'),
    place: const PaperPlace(text: sentence),
  );

  test('PaperExplanation describes itself by shape, never by content', () {
    final description = explanation.toString();

    expect(description, isNot(contains(sentence)));
    expect(description, isNot(contains(title)));
    expect(description, isNot(contains('285')));
    expect(description, isNot(contains('0453312244')));
  });

  test('PaperTodo describes itself by length, never by text', () {
    const todo = PaperTodo(required: true, text: sentence);

    expect(todo.toString(), isNot(contains(sentence)));
    expect(todo.toString(), contains('${sentence.length}'));
  });

  test('PaperCaution describes itself by length, never by text', () {
    const caution = PaperCaution(text: sentence);

    expect(caution.toString(), isNot(contains(sentence)));
    expect(caution.toString(), contains('${sentence.length}'));
  });

  test('PaperPlace describes itself by length, never by text', () {
    const place = PaperPlace(text: sentence);

    expect(place.toString(), isNot(contains(sentence)));
    expect(place.toString(), contains('${sentence.length}'));
  });

  test('PaperContact describes itself by length, never by name or phone', () {
    const contact = PaperContact(name: sentence, phone: '0453312244');

    expect(contact.toString(), isNot(contains(sentence)));
    expect(contact.toString(), isNot(contains('0453312244')));
  });

  test('PaperDate describes itself by shape, never by text', () {
    final date = PaperDate(day: DateTime(2026, 11, 25), text: sentence);

    expect(date.toString(), isNot(contains(sentence)));
  });

  test('SavedPaper describes itself by bookkeeping, never by content', () {
    final saved = SavedPaper(
      id: 'paper-1',
      explanation: explanation,
      sessionId: 'session-1',
      explainSchemaVersion: '1.0',
      photographedAt: DateTime(2026, 11, 20),
      savedAt: DateTime(2026, 11, 20),
    );

    final description = saved.toString();

    expect(description, isNot(contains(sentence)));
    expect(description, isNot(contains(title)));
  });
}
