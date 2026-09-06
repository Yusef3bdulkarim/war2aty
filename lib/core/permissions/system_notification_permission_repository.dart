import '../error/app_failure.dart';
import '../result/result.dart';
import 'notification_permission_repository.dart';
import 'permission_service.dart';

/// [NotificationPermissionRepository] on top of the OS permission APIs.
///
/// This is the data boundary: platform channel errors stop here and become a
/// [NotificationPermissionFailure], so no exception ever reaches a use case.
final class SystemNotificationPermissionRepository
    implements NotificationPermissionRepository {
  const SystemNotificationPermissionRepository(this._permissions);

  final PermissionService _permissions;

  @override
  Future<Result<PermissionOutcome, AppFailure>> currentStatus() =>
      _guard(() => _permissions.check(AppPermission.notifications));

  @override
  Future<Result<PermissionOutcome, AppFailure>> request() =>
      _guard(() => _permissions.request(AppPermission.notifications));

  @override
  Future<Result<bool, AppFailure>> openSettings() =>
      _guard(_permissions.openSettings);

  Future<Result<T, AppFailure>> _guard<T>(Future<T> Function() run) async {
    try {
      return Ok(await run());
    } on Object {
      return const Err(NotificationPermissionFailure());
    }
  }
}
