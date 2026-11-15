import 'package:flutter_test/flutter_test.dart';
import 'package:war2aty/core/error/app_failure.dart';
import 'package:war2aty/core/papers/saved_paper.dart';
import 'package:war2aty/core/papers/usecases/watch_paper.dart';
import 'package:war2aty/core/result/result.dart';

import '../../../support/fakes.dart';

void main() {
  late FakePapersRepository repository;
  late WatchPaper watchPaper;

  setUp(() {
    repository = FakePapersRepository();
    watchPaper = WatchPaper(repository);
  });
  tearDown(() => repository.dispose());

  test('passes the id straight to the repository', () async {
    await watchPaper('p1').first;

    expect(repository.requestedPaperId, 'p1');
  });

  test('carries the paper the repository answers with', () async {
    final paper = savedPaperWith();
    repository.emitPaper(paper);

    final result = await watchPaper('p1').first;

    expect((result as Ok<SavedPaper?, AppFailure>).value, paper);
  });

  test('carries a failure straight through', () async {
    repository.emitPaperFailure();

    final result = await watchPaper('p1').first;

    expect(result, const Err<SavedPaper?, AppFailure>(LocalDatabaseFailure()));
  });
}
