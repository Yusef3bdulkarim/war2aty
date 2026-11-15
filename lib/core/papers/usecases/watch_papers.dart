import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../papers_repository.dart';
import '../saved_paper.dart';

final class WatchPapers {
  const WatchPapers(this._repository);

  final PapersRepository _repository;

  Stream<Result<List<SavedPaper>, AppFailure>> call() =>
      _repository.watchPapers();
}
