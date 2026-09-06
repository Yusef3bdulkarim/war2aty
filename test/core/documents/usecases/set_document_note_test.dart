import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/usecases/set_document_note.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeDocumentsRepository repository;
  late SetDocumentNote useCase;

  setUp(() {
    repository = FakeDocumentsRepository();
    useCase = SetDocumentNote(repository);
  });
  tearDown(() => repository.dispose());

  test('delegates to the repository', () async {
    final result = await useCase('doc-1', 'ملاحظة');

    expect(result.isOk, isTrue);
    expect(repository.lastNoteSet, 'ملاحظة');
  });

  test('passes null to delete', () async {
    final result = await useCase('doc-1', null);

    expect(result.isOk, isTrue);
    expect(repository.noteDeleted, isTrue);
  });
}
