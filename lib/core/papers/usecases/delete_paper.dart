import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../papers_repository.dart';

final class DeletePaper {
  const DeletePaper(this._repository);

  final PapersRepository _repository;

  Future<Result<void, AppFailure>> call(String id) =>
      _repository.deletePaper(id);
}
