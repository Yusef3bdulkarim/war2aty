import '../../error/app_failure.dart';
import '../../result/result.dart';
import '../notification_permission_repository.dart';

/// The way out of a permanent denial: the OS settings page for this app
/// (F11-T09). Same reasoning as `OpenPermissionSettings` (capture flow):
/// once the OS stops showing the permission prompt, nothing the app does can
/// bring it back — Settings is the only remaining path to notifications.
final class OpenNotificationPermissionSettings {
  const OpenNotificationPermissionSettings(this._repository);

  final NotificationPermissionRepository _repository;

  Future<Result<bool, AppFailure>> call() => _repository.openSettings();
}
