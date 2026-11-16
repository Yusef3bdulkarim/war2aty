import '../../../../core/error/app_failure.dart';
import '../../../../core/papers/explain_outcome.dart';
import '../../../../core/result/result.dart';
import '../../../capture/domain/entities/captured_photo.dart';

abstract interface class ExplainRepository {
  Future<Result<ExplainOutcome, AppFailure>> explain(CapturedPhoto photo);
}
