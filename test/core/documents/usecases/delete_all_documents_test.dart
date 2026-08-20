import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/documents/usecases/delete_all_documents.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

// F11-T11: settings' «حذف كل المستندات».
void main() {
  late FakeDocumentsRepository repository;
  late DeleteAllDocuments useCase;

  setUp(() {
    repository = FakeDocumentsRepository();
    useCase = DeleteAllDocuments(repository);
  });
  tearDown(() => repository.dispose());

  test('delegates to the repository', () async {
    final result = await useCase();

    expect(result.isOk, isTrue);
    expect(repository.deleteAllCalled, isTrue);
  });

  test('surfaces a repository failure', () async {
    repository.deleteAllOutcome = const Err(LocalDatabaseFailure());

    final result = await useCase();

    expect(result, const Err<void, AppFailure>(LocalDatabaseFailure()));
  });
}
