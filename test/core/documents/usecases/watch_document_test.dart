import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/saved_document.dart';
import 'package:war2aty/core/documents/usecases/watch_document.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakeDocumentsRepository repository;
  late WatchDocument watchDocument;

  setUp(() {
    repository = FakeDocumentsRepository();
    watchDocument = WatchDocument(repository);
  });
  tearDown(() => repository.dispose());

  test('passes the id straight to the repository', () async {
    await watchDocument('doc-1').first;

    expect(repository.requestedDocumentId, 'doc-1');
  });

  test('carries the document the repository answers with', () async {
    final document = savedDocumentWith();
    repository.emitDocument(document);

    final result = await watchDocument('doc-1').first;

    expect((result as Ok<SavedDocument?, AppFailure>).value, document);
  });

  test('carries a failure straight through', () async {
    repository.emitDocumentFailure();

    final result = await watchDocument('doc-1').first;

    expect(
      result,
      const Err<SavedDocument?, AppFailure>(LocalDatabaseFailure()),
    );
  });
}
