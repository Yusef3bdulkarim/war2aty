import '../../../../core/error/app_failure.dart';
import '../../../../core/result/result.dart';

abstract interface class LegacyDocumentFilesPurge {
  Future<Result<void, AppFailure>> call();
}
