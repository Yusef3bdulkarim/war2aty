import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../papers_repository.dart';
import '../saved_paper.dart';

final class WatchPaper {
  const WatchPaper(this._repository);

  final PapersRepository _repository;

  Stream<Result<SavedPaper?, AppFailure>> call(String id) =>
      _repository.watchPaper(id);
}
