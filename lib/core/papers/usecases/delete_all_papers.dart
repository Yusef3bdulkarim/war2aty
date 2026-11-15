import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../papers_repository.dart';

final class DeleteAllPapers {
  const DeleteAllPapers(this._repository);

  final PapersRepository _repository;

  Future<Result<void, AppFailure>> call() => _repository.deleteAllPapers();
}
