import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/usecases/delete_paper.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePapersRepository repository;
  late DeletePaper deletePaper;

  setUp(() {
    repository = FakePapersRepository();
    deletePaper = DeletePaper(repository);
  });

  test('delegates to the repository', () async {
    final result = await deletePaper('p1');

    expect(result.isOk, isTrue);
    expect(repository.lastDeletedId, 'p1');
  });

  test('surfaces a repository failure', () async {
    repository.deleteOutcome = const Err(LocalDatabaseFailure());

    final result = await deletePaper('p1');

    expect(result, const Err<void, AppFailure>(LocalDatabaseFailure()));
  });
}
