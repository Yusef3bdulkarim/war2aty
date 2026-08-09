import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../notification_permission_repository.dart';
import '../permission_service.dart';

/// Reads notification access before saving a reminder (F09-T09), without
/// prompting. A user who already granted it saves straight through; one who
/// has not is asked via the permission sheet instead.
final class GetNotificationPermission {
  const GetNotificationPermission(this._repository);

  final NotificationPermissionRepository _repository;

  Future<Result<PermissionOutcome, AppFailure>> call() =>
      _repository.currentStatus();
}
