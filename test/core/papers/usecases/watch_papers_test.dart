import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/saved_paper.dart';
import 'package:war2aty/core/papers/usecases/watch_papers.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePapersRepository repository;
  late WatchPapers watchPapers;

  setUp(() {
    repository = FakePapersRepository();
    watchPapers = WatchPapers(repository);
  });
  tearDown(() => repository.dispose());

  test('emits an empty list when nothing has been saved', () async {
    final result = await watchPapers().first;

    expect((result as Ok<List<SavedPaper>, AppFailure>).value, isEmpty);
  });

  test('carries the papers the repository answers with', () async {
    final paper = savedPaperWith();
    repository.emit([paper]);

    final result = await watchPapers().first;

    expect((result as Ok<List<SavedPaper>, AppFailure>).value, [paper]);
  });

  test('carries a failure straight through', () async {
    repository.emitFailure();

    final result = await watchPapers().first;

    expect(
      result,
      const Err<List<SavedPaper>, AppFailure>(LocalDatabaseFailure()),
    );
  });
}
