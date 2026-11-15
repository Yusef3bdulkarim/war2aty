import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/usecases/delete_all_papers.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePapersRepository repository;
  late DeleteAllPapers deleteAllPapers;

  setUp(() {
    repository = FakePapersRepository();
    deleteAllPapers = DeleteAllPapers(repository);
  });

  test('delegates to the repository', () async {
    final result = await deleteAllPapers();

    expect(result.isOk, isTrue);
    expect(repository.deleteAllCalled, isTrue);
  });

  test('surfaces a repository failure', () async {
    repository.deleteAllOutcome = const Err(LocalDatabaseFailure());

    final result = await deleteAllPapers();

    expect(result, const Err<void, AppFailure>(LocalDatabaseFailure()));
  });
}
