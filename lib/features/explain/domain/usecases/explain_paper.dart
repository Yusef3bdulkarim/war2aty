import '../../../../core/error/app_failure.dart';
import '../../../../core/papers/explain_outcome.dart';
import '../../../../core/result/result.dart';
import '../../../capture/domain/entities/captured_photo.dart';
import '../repositories/explain_repository.dart';

final class ExplainPaper {
  const ExplainPaper(this._repository);

  final ExplainRepository _repository;

  Future<Result<ExplainOutcome, AppFailure>> call(CapturedPhoto photo) {
    return _repository.explain(photo);
  }
}
