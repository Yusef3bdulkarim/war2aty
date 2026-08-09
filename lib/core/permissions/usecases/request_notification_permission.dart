import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../notification_permission_repository.dart';
import '../permission_service.dart';

/// Asks for notifications, after the permission sheet (F09-T09) has told the
/// user why. The reminder is saved either way — declining only means it
/// will not fire an OS notification, not that it fails to save.
final class RequestNotificationPermission {
  const RequestNotificationPermission(this._repository);

  final NotificationPermissionRepository _repository;

  Future<Result<PermissionOutcome, AppFailure>> call() => _repository.request();
}
